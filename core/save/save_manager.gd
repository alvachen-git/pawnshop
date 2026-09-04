class_name SaveManager
extends RefCounted

var path: String
var catalog: ContentCatalog
var error_message := ""
var _codec := SaveCodec.new()

func _init(save_path := "user://p0/autosave.json") -> void:
	path = save_path

func exists() -> bool:
	return FileAccess.file_exists(path)

func load_state(definition: RunDefinition, content_version: int) -> RunState:
	error_message = ""
	var file := FileAccess.open(path, FileAccess.READ)
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
