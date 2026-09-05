class_name SaveManager
extends RefCounted

var path: String
var catalog: ContentCatalog
var legacy_archive_path := ""
var prior_version_path := ""
var import_checkpoint_path := ""
var error_message := ""
var _codec := SaveCodec.new()

func _init(save_path := "user://p0/autosave_v7.json") -> void:
	path = save_path

func exists() -> bool:
	return FileAccess.file_exists(path) or (not import_checkpoint_path.is_empty() and FileAccess.file_exists(import_checkpoint_path))

func load_state(definition: RunDefinition, content_version: int) -> RunState:
	error_message = ""
	var source := path if FileAccess.file_exists(path) or import_checkpoint_path.is_empty() else import_checkpoint_path
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		error_message = "没有可读取的夜末存档（%s）。" % error_string(FileAccess.get_open_error())
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error_message = "存档JSON损坏；原文件已保留。"
		return null
	var state := _codec.decode(parser.data, definition, content_version, catalog)
	error_message = _codec.error_message
	return state

func save_state(state: RunState, definition: RunDefinition, content_version: int) -> bool:
	error_message = ""
	var archive := read_archive()
	if not error_message.is_empty(): return false
	for record in archive:
		var found := false
		for existing in state.death_archive:
			if existing.run_token == record.run_token:
				if existing != record:
					error_message = "绝当录记录冲突；旧文件已保留。"
					return false
				found = true
		if not found: state.death_archive.append(record)
	var bankruptcies := read_bankruptcy_archive()
	if not error_message.is_empty(): return false
	for record in bankruptcies:
		var found := false
		for existing in state.bankruptcy_archive:
			if existing.run_token == record.run_token:
				if existing != record:
					error_message = "破铺录记录冲突；旧文件已保留。"
					return false
				found = true
		if not found: state.bankruptcy_archive.append(record)
	var payload := _codec.encode(state, content_version)
	if _codec.decode(payload, definition, content_version, catalog) == null:
		error_message = _codec.error_message
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var ancestor := absolute.get_base_dir()
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor) or ancestor == ancestor.get_base_dir():
			error_message = "存档目录不可用：路径中存在普通文件或无效根目录。"
			return false
		ancestor = ancestor.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		error_message = "无法创建存档目录：%s" % error_string(directory_error)
		return false
	# Same-directory temporary file; the old checkpoint is never deleted first.
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error_message = "无法写入临时存档：%s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error_message = "存档写入失败：%s" % error_string(write_error)
		return false
	# Re-read and validate before publishing a checkpoint.
	var verify := SaveManager.new(temporary)
	verify.catalog = catalog
	if verify.load_state(definition, content_version) == null:
		error_message = "临时存档校验失败：" + verify.error_message
		return false
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		error_message = "存档替换失败：%s；旧存档保留。" % error_string(rename_error)
		return false
	return true

func read_archive() -> Array[Dictionary]:
	error_message = ""
	var archive := _read_records(path, "death_archive", RiskSaveCodec.valid_archive)
	if not error_message.is_empty(): return archive
	if not legacy_archive_path.is_empty():
		var legacy := _read_records(legacy_archive_path, "death_archive", RiskSaveCodec.valid_archive)
		for row in legacy:
			var found := false
			for existing in archive:
				if existing.run_token == row.run_token:
					found = true
					if existing != row: error_message = "旧绝当录与新账册冲突；原文件已保留。"
			if not found: archive.append(row)
	if not prior_version_path.is_empty(): _merge_records(archive, _read_records(prior_version_path, "death_archive", RiskSaveCodec.valid_archive))
	return archive

func read_bankruptcy_archive() -> Array[Dictionary]:
	# Do not erase a legacy-archive read error during initialization.
	var records := _read_records(path, "bankruptcy_archive", FeeSaveCodec.valid_archive)
	if not legacy_archive_path.is_empty(): _merge_records(records, _read_records(legacy_archive_path, "bankruptcy_archive", FeeSaveCodec.valid_archive))
	if not prior_version_path.is_empty(): _merge_records(records, _read_records(prior_version_path, "bankruptcy_archive", FeeSaveCodec.valid_archive))
	return records

func _merge_records(records: Array[Dictionary], incoming: Array[Dictionary]) -> void:
	for row in incoming:
		var found := false
		for existing in records:
			if existing.run_token == row.run_token:
				found = true
				if existing != row: error_message = "历史账册记录冲突；原文件已保留。"
		if not found: records.append(row)

func _read_records(source: String, key: String, validator: Callable) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(source): return records
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		error_message = "无法读取旧账册；未覆盖原文件。"
		return records
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		error_message = "旧存档损坏；无法安全保留账册，未覆盖旧文件。"
		return records
	var rows: Variant = parser.data.get(key, [])
	if not validator.call(rows):
		error_message = "历史账册损坏；未覆盖旧文件。"
		return records
	for row in rows:
		var copy: Dictionary = row.duplicate(true)
		for field in copy:
			if copy[field] is float: copy[field] = int(copy[field])
		records.append(copy)
	return records
