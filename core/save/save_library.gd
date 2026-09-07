class_name SaveLibrary
extends RefCounted

# Slots and append-only endings share one atomic publication boundary.
const FORMAT := 1
const DEFAULT_PATH := "user://save_library/library_v1.json"
const MANIFESTS := ["res://data/preparation_manifest.json", "res://data/integrated_manifest.json", "res://data/content_manifest.json", "res://data/four_night_manifest.json", "res://data/seven_night_manifest.json", "res://data/opening_manifest.json", "res://data/legacy/content_v9.json", "res://data/legacy/content_v10_released.json", "res://data/legacy/content_v10.json", "res://data/legacy/content_v10_100_300.json", "res://data/legacy/content_v11.json"]
const LEGACY := {"prepared_seven": "user://prepared_seven/autosave_v15.json", "integrated_seven": "user://integrated_seven/autosave_v14.json", "p0_variety": "user://p0/autosave_v12.json", "ordinary_four": "user://ordinary_four/autosave_v11.json", "ordinary_seven": "user://ordinary_seven/autosave_v13.json", "opening_v01": "user://p0/opening_v01.json", "old_v11": "user://p0/autosave_v11.json", "old_v10": "user://p0/autosave_v10.json", "old_v9": "user://p0/autosave_v9.json"}
const NAMES := {"prepared_seven": "鬼市当铺 · 七夜", "integrated_seven": "鬼市当铺 · 七夜", "p0_variety": "三夜原型", "p0_room": "三夜原型（旧版）", "ordinary_four": "四夜经营", "ordinary_seven": "七夜经营", "opening_v01": "开场剧情"}
var path := DEFAULT_PATH
var error_message := ""
var busy := false
var fail_write := false # Fault injection, never controlled by player save data.
var last_fingerprint := ""
var last_label := "尚未保存"
var _catalogs: Array[ContentCatalog] = []

func _init(location := DEFAULT_PATH) -> void:
	path = location

static func save_reason(state: RunState) -> String:
	if state.phase == &"open": return "营业期间不能保存，请在关铺后保存。"
	if String(state.phase) not in SaveCodec.CHECKPOINTS + SaveTimeline.UNSETTLED: return "当前操作尚未完成，请稍后保存。"
	return ""

static func fingerprint(state: RunState) -> String:
	var data := state.to_read_model()
	data.erase("death_archive")
	data.erase("bankruptcy_archive")
	return JSON.stringify(data).sha256_text()

func dirty(state: RunState) -> bool:
	return fingerprint(state) != last_fingerprint

func _empty() -> Dictionary:
	return {"format": FORMAT, "entries": {}, "death_archive": [], "bankruptcy_archive": []}

func _read() -> Dictionary:
	error_message = ""
	if not FileAccess.file_exists(path): return _empty()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: error_message = "无法读取存档库；原文件已保留。"; return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		error_message = "存档库损坏；未覆盖原文件。"; return {}
	var data: Dictionary = parser.data
	if data.get("format") != FORMAT or not data.get("entries") is Dictionary or not RiskSaveCodec.valid_archive(data.get("death_archive")) or not FeeSaveCodec.valid_archive(data.get("bankruptcy_archive")):
		error_message = "存档库版本或记录无效；未覆盖原文件。"; return {}
	for death in data.death_archive:
		if data.bankruptcy_archive.any(func(row: Dictionary) -> bool: return row.run_token == death.run_token):
			error_message = "同一次尝试出现两种终局。"; return {}
	return data

func _merge_archives(data: Dictionary, state: RunState) -> bool:
	for key in ["death_archive", "bankruptcy_archive"]:
		for row in state.get(key):
			var found := false
			for previous in data[key]:
				if previous.run_token == row.run_token:
					if JSON.stringify(previous) != JSON.stringify(row): error_message = "失败记录冲突；未覆盖存档。"; return false
					found = true
			if not found: data[key].append(row.duplicate(true))
	for death in data.death_archive:
		if data.bankruptcy_archive.any(func(row: Dictionary) -> bool: return row.run_token == death.run_token):
			error_message = "同一次尝试只能记录一种终局。"; return false
	return true

func _publish(data: Dictionary) -> bool:
	if fail_write: error_message = "模拟写盘失败。"; return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		error_message = "无法创建存档目录。"; return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: error_message = "无法写入临时存档。"; return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: error_message = "存档写入失败；原存档保留。"; return false
	var verify := SaveLibrary.new(temporary)
	if verify._read() != JSON.parse_string(JSON.stringify(data)): error_message = "临时存档回读校验失败。"; return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		error_message = "无法替换存档；原存档保留。"; return false
	return true

func write_entry(key: String, state: RunState, run: RunDefinition, version: int, catalog: ContentCatalog) -> bool:
	if busy: error_message = "正在保存，请稍候。"; return false
	error_message = save_reason(state)
	if not error_message.is_empty(): return false
	if not key.begins_with("auto/") and key not in ["manual/1", "manual/2", "manual/3", "manual/4", "manual/5", "manual/6"]:
		error_message = "存档位无效。"; return false
	var codec := SaveCodec.new()
	var payload := codec.encode(state, version)
	if codec.decode(payload, run, version, catalog, true) == null:
		error_message = codec.error_message; return false
	var data := _read()
	if data.is_empty() or not _merge_archives(data, state): return false
	var entry := {"format": FORMAT, "saved_at": Time.get_datetime_string_from_system(), "payload": payload}
	data.entries[key] = entry
	busy = true
	var ok := _publish(data)
	busy = false
	if ok:
		last_fingerprint = fingerprint(state)
		last_label = _position_label(key, state, run)
	return ok

static func _position_label(key: String, state: RunState, run: RunDefinition) -> String:
	var label := "存档位" + key.get_slice("/", 1) if key.begins_with("manual/") else "旧版自动存档" if key.begins_with("legacy/") else "自动存档"
	return "%s · 第%d夜 · %s · %s" % [label, state.current_night_index, TimeController.clock_text(run.opening_minute, state.game_minutes), DayFlowPresenter.PHASE_LABELS.get(String(state.phase), "")]

func decode_entry(entry: Variant, extended := true) -> Dictionary:
	error_message = "存档内容损坏或版本不兼容。"
	if not entry is Dictionary or entry.get("format") != FORMAT or not entry.get("payload") is Dictionary or not entry.get("saved_at") is String: return {}
	var payload: Dictionary = entry.payload
	if _catalogs.is_empty():
		for manifest in MANIFESTS:
			if not FileAccess.file_exists(manifest): continue
			var result := JsonContentProvider.new(manifest).load_catalog()
			if result.is_success(): _catalogs.append(result.catalog)
	for catalog in _catalogs:
		if catalog.content_version != payload.get("content_version"): continue
		var run := catalog.get_definition("runs", payload.get("run_definition_id", "")) as RunDefinition
		if run == null: continue
		var codec := SaveCodec.new()
		var state := codec.decode(payload, run, catalog.content_version, catalog, extended)
		if state != null: error_message = ""; return {"state": state, "run": run, "catalog": catalog}
		error_message = codec.error_message
	return {}

func read_entry(key: String) -> Dictionary:
	var data := _read()
	if data.is_empty(): return {}
	if data.entries.has(key):
		var result := decode_entry(data.entries[key])
		if not result.is_empty(): result.source_key = key
		return result
	if key.begins_with("legacy/"):
		var location: String = LEGACY.get(key.trim_prefix("legacy/"), "")
		if not location.is_empty() and FileAccess.file_exists(location):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(location)) == OK:
				var result := decode_entry({"format": FORMAT, "saved_at": "旧版存档", "payload": parser.data}, false)
				if not result.is_empty(): result.source_key = key
				return result
	error_message = "没有可读取的存档。"
	return {}

func entries() -> Array[Dictionary]:
	var data := _read()
	var rows: Array[Dictionary] = []
	if data.is_empty(): return rows
	for index in range(1, 7):
		var key := "manual/%d" % index
		rows.append(_summary(key, data.entries.get(key)))
	for key in data.entries:
		if String(key).begins_with("auto/"): rows.append(_summary(key, data.entries[key]))
	for run_id in LEGACY:
		if FileAccess.file_exists(LEGACY[run_id]):
			var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY[run_id]))
			rows.append(_summary("legacy/" + run_id, {"format": FORMAT, "saved_at": "旧版存档（原文件保留）", "payload": payload}))
	return rows

func _summary(key: String, entry: Variant) -> Dictionary:
	var row := {"key": key, "empty": entry == null, "run_id": "", "label": "存档位 " + key.get_slice("/", 1) if key.begins_with("manual/") else "自动存档", "detail": "空存档位", "valid": false}
	if entry == null: return row
	var decoded := decode_entry(entry, not key.begins_with("legacy/"))
	if decoded.is_empty(): row.detail = error_message; return row
	var state: RunState = decoded.state
	row.run_id = String(state.run_definition_id)
	row.valid = true
	row.detail = "%s · 第%d夜 · %s\n%s · 现银%d银元\n%s" % [NAMES.get(row.run_id, row.run_id), state.current_night_index, TimeController.clock_text(decoded.run.opening_minute, state.game_minutes), DayFlowPresenter.PHASE_LABELS.get(String(state.phase), ""), state.cash, entry.saved_at]
	if state.phase in [&"dead", &"bankrupt", &"run_ended"]: row.detail += " · 已结束"
	return row

func archive(key: String, run_id: String) -> Array:
	var data := _read()
	if data.is_empty(): return []
	return data[key].filter(func(row: Dictionary) -> bool: return row.run_id == run_id)

func adopt(decoded: Dictionary, session: RunSession) -> bool:
	# Validate first, then prepare a new attempt; source slot is immutable on read.
	var data := _read()
	if data.is_empty(): return false
	var state: RunState = decoded.state
	if not _merge_archives(data, state): return false
	# Loading an old ending imports it atomically before publishing the new session.
	if data != _read() and not _publish(data): return false
	if state.phase not in [&"dead", &"bankrupt", &"run_ended"] and not state.run_token.is_empty(): state.run_token = Crypto.new().generate_random_bytes(16).hex_encode()
	for field in ["death_archive", "bankruptcy_archive"]:
		var records: Array = data[field].filter(func(row: Dictionary) -> bool: return row.run_id == String(state.run_definition_id))
		var target: Array = state.get(field)
		target.assign(records)
	session._switch_content(decoded.run, decoded.catalog.content_version, decoded.catalog)
	session._day.state = state
	session._pawn_choices.clear()
	session._risk_error = ""
	if state.phase == &"pre_open": session._counter.customers.prepare_night(state, decoded.run, decoded.catalog)
	MarketService.sync(state, decoded.run)
	session.message = "已读取存档。"
	last_fingerprint = fingerprint(state)
	last_label = _position_label(decoded.get("source_key", "auto/" + String(state.run_definition_id)), state, decoded.run)
	session.restored.emit()
	session.changed.emit()
	return true
