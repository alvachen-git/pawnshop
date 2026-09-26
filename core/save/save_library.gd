class_name SaveLibrary
extends RefCounted

# Slots and append-only endings share one atomic publication boundary.
const FORMAT := 1
const DEFAULT_PATH := "user://save_library/library_v1.json"
const MANIFESTS := ["res://data/preopen_recycler_manifest.json", "res://data/qingbang_manifest.json", "res://data/medicine_huaian_v47_manifest.json", "res://data/special_guests_late_v46_manifest.json", "res://data/special_guests_wet_v45_manifest.json", "res://data/special_guests_manifest.json", "res://data/gramophone_release_manifest.json", "res://data/gramophone_manifest.json", "res://data/pawn_interest_manifest.json", "res://data/lu_trade_manifest.json", "res://data/lu_introduction_manifest.json", "res://data/camera_manifest.json", "res://data/porcelain_release_manifest.json", "res://data/porcelain_manifest.json", "res://data/first_debt_recovery_release_manifest.json", "res://data/first_debt_recovery_manifest.json", "res://data/bangle_unified_manifest.json", "res://data/bangle_market_manifest.json", "res://data/pearl_market_manifest.json", "res://data/named_wealthy_manifest.json", "res://data/watch_patterns_manifest.json", "res://data/watch_negotiation_manifest.json", "res://data/watch_market_manifest.json", "res://data/watch_manifest.json", "res://data/tiered_manifest.json", "res://data/wealthy_manifest.json", "res://data/social_relations_manifest.json", "res://data/unified_manifest.json", "res://data/fan_condition_manifest.json", "res://data/fan_bargaining_manifest.json", "res://data/shop_appraisal_manifest.json", "res://data/shop_growth_manifest.json", "res://data/mirror_reunion_manifest.json", "res://data/mirror_ending_manifest.json", "res://data/aqi_investigation_manifest.json", "res://data/aqi_manifest.json", "res://data/mirror_investigation_manifest.json", "res://data/mirror_living_manifest.json", "res://data/life_lamp_manifest.json", "res://data/goods_expertise_manifest.json", "res://data/night_market_manifest.json", "res://data/pawn_chance_manifest.json", "res://data/complete_seven_manifest.json", "res://data/market_familiar_manifest.json", "res://data/market_seven_manifest.json", "res://data/familiar_early_manifest.json", "res://data/familiar_manifest.json", "res://data/mirror_chapter_manifest.json", "res://data/preparation_manifest.json", "res://data/integrated_manifest.json", "res://data/content_manifest.json", "res://data/four_night_manifest.json", "res://data/seven_night_manifest.json", "res://data/opening_manifest.json", "res://data/legacy/content_v9.json", "res://data/legacy/content_v10_released.json", "res://data/legacy/content_v10.json", "res://data/legacy/content_v10_100_300.json", "res://data/legacy/content_v11.json", "res://data/mirror_dream_call_manifest.json", "res://data/mirror_dream_manifest.json", "res://data/aqi_reunion_manifest.json", "res://data/aqi_companion_manifest.json", "res://data/first_debt_unified_manifest.json", "res://data/first_debt_dragon_search_manifest.json", "res://data/first_debt_reckoning_manifest.json", "res://data/first_debt_manifest.json"]
const LEGACY := {"preopen_recycler":"user://preopen_recycler/autosave_v47.json", "qingbang_release":"user://qingbang_release/autosave_v48.json","gramophone_release":"user://gramophone_release/autosave_v46.json", "gramophone_unified":"user://gramophone_unified/autosave_v44.json", "pawn_interest_unified":"user://pawn_interest_unified/autosave_v45.json", "lu_trade_unified":"user://lu_trade_unified/autosave_v44.json", "camera_unified":"user://camera_unified/autosave_v43.json", "porcelain_release":"user://porcelain_release/autosave_v42.json", "porcelain_unified":"user://porcelain_unified/autosave_v41.json", "first_debt_recovery_release": "user://first_debt_recovery_release/autosave_v41.json", "first_debt_recovery": "user://first_debt_recovery/autosave_v40.json", "bangle_market_ten": "user://bangle_market_ten/autosave_v39.json", "pearl_market_ten": "user://pearl_market_ten/autosave_v38.json", "named_wealthy_ten": "user://named_wealthy_ten/autosave_v37.json", "watch_patterns_ten": "user://watch_patterns_ten/autosave_v36.json", "watch_negotiation_ten": "user://watch_negotiation_ten/autosave_v35.json", "watch_market_ten": "user://watch_market_ten/autosave_v34.json", "watch_ten": "user://watch_ten/autosave_v33.json", "precision_ten": "user://precision_ten/autosave_v32.json", "wealthy_ten": "user://wealthy_ten/autosave_v31.json", "social_relations_ten": "user://social_relations_ten/autosave_v27.json", "unified_ten": "user://unified_ten/autosave_v30.json", "mirror_dream_call_ten": "user://mirror_dream_call_ten/autosave_v29.json", "mirror_dream_ten": "user://mirror_dream_ten/autosave_v28.json", "aqi_reunion_ten": "user://aqi_reunion_ten/autosave_v27.json", "aqi_companion_ten": "user://aqi_companion_ten/autosave_v25.json", "shop_growth_ten": "user://shop_growth_ten/autosave_v25.json", "mirror_reunion_ten": "user://mirror_reunion_ten/autosave_v26.json", "mirror_ending_ten": "user://mirror_ending_ten/autosave_v25.json", "aqi_investigation_ten": "user://aqi_investigation_ten/autosave_v24.json", "aqi_seven": "user://aqi_seven/autosave_v22.json", "mirror_investigation_ten": "user://mirror_investigation_ten/autosave_v23.json", "mirror_living_seven": "user://mirror_living_seven/autosave_v22.json", "life_lamp_seven": "user://life_lamp_seven/autosave_v22.json", "goods_expertise_seven": "user://goods_expertise_seven/autosave_v21.json", "night_market": "user://night_market/autosave_v21.json", "complete_seven": "user://complete_seven/autosave_v19.json", "pawn_chance_seven": "user://pawn_chance_seven/autosave_v20.json", "market_familiar": "user://market_familiar/autosave_v19.json", "market_seven": "user://market_seven/autosave_v17.json", "familiar_early": "user://familiar_early/autosave_v18.json", "familiar_seven": "user://familiar_seven/autosave_v17.json", "mirror_chapter": "user://mirror_chapter/autosave_v16.json", "prepared_seven": "user://prepared_seven/autosave_v15.json", "integrated_seven": "user://integrated_seven/autosave_v14.json", "p0_variety": "user://p0/autosave_v12.json", "ordinary_four": "user://ordinary_four/autosave_v11.json", "ordinary_seven": "user://ordinary_seven/autosave_v13.json", "opening_v01": "user://p0/opening_v01.json", "old_v11": "user://p0/autosave_v11.json", "old_v10": "user://p0/autosave_v10.json", "old_v9": "user://p0/autosave_v9.json", "fan_condition_ten": "user://fan_condition_ten/autosave_v29.json", "fan_bargaining_ten": "user://fan_bargaining_ten/autosave_v28.json", "shop_appraisal_ten": "user://shop_appraisal_ten/autosave_v27.json", "first_debt_unified": "user://first_debt_unified/autosave_v39.json", "first_debt_dragon_search": "user://first_debt_dragon_search/autosave_v31.json", "first_debt_reckoning": "user://first_debt_reckoning/autosave_v29.json", "first_debt_open": "user://first_debt_open/autosave_v28.json", "bangle_unified": "user://bangle_unified/autosave_v40.json"}
const NAMES := {"preopen_recycler":"鬼市当铺 · 开铺前卖货", "qingbang_release":"鬼市当铺 · 青帮街面往来", "gramophone_release":"鬼市当铺 · 留声与当约", "gramophone_unified":"鬼市当铺 · 留声验货", "pawn_interest_unified":"鬼市当铺 · 活当息费", "lu_trade_unified":"鬼市当铺 · 陆掌眼往来", "camera_unified":"鬼市当铺 · 洋镜掌眼", "porcelain_release":"鬼市当铺", "porcelain_unified":"鬼市当铺 · 青花断代", "first_debt_recovery_release": "鬼市当铺", "first_debt_recovery": "鬼市当铺", "bangle_market_ten": "鬼市当铺 · 火下验金", "pearl_market_ten": "鬼市当铺 · 灯下验珠", "named_wealthy_ten": "鬼市当铺 · 富客往来", "watch_patterns_ten": "鬼市当铺 · 机芯掌眼", "watch_negotiation_ten": "鬼市当铺 · 掌眼与谈价", "watch_market_ten": "鬼市当铺 · 识表与议价", "watch_ten": "鬼市当铺 · 灯下验表", "precision_ten": "鬼市当铺 · 掌眼与精鉴", "wealthy_ten": "鬼市当铺 · 十夜经营", "social_relations_ten": "鬼市当铺 · 街面往来", "unified_ten": "鬼市当铺 · 十夜经营", "mirror_dream_call_ten": "鬼市当铺 · 夜半来声", "mirror_dream_ten": "鬼市当铺 · 镜中托梦", "aqi_reunion_ten": "鬼市当铺 · 柜边与镜中旧事", "aqi_companion_ten": "鬼市当铺 · 柜边旧事", "shop_growth_ten": "鬼市当铺 · 当铺成长十夜", "mirror_reunion_ten": "鬼市当铺 · 镜中重逢", "mirror_ending_ten": "鬼市当铺 · 镜前旧事", "aqi_investigation_ten": "鬼市当铺 · 接铺与旧事", "aqi_seven": "鬼市当铺 · 接铺", "mirror_investigation_ten": "鬼市当铺 · 十夜旧事", "mirror_living_seven": "鬼市当铺 · 镜照生死", "life_lamp_seven": "鬼市当铺 · 命灯", "goods_expertise_seven": "鬼市当铺 · 识货与成双", "night_market": "鬼市当铺 · 夜客", "complete_seven": "鬼市当铺 · 七夜经营整合版", "pawn_chance_seven": "鬼市当铺 · 当期与生计", "market_familiar": "鬼市当铺 · 生意与故人", "market_seven": "鬼市当铺 · 生意与旧事", "familiar_early": "鬼市当铺 · 熟客新约", "familiar_seven": "鬼市当铺 · 熟客往来", "mirror_chapter": "鬼市当铺 · 镜中旧事", "prepared_seven": "七夜 · 开铺准备", "integrated_seven": "鬼市当铺 · 七夜", "p0_variety": "三夜原型", "p0_room": "三夜原型（旧版）", "ordinary_four": "四夜经营", "ordinary_seven": "七夜经营", "opening_v01": "开场剧情", "fan_condition_ten": "鬼市当铺 · 品相与掌眼", "fan_bargaining_ten": "鬼市当铺 · 识扇与议价", "shop_appraisal_ten": "鬼市当铺 · 识扇与旧铺", "first_debt_unified": "鬼市当铺", "first_debt_dragon_search": "龙镯追查", "first_debt_reckoning": "鬼市当铺 · 有据难赎", "first_debt_open": "鬼市当铺 · 早绝的金镯", "bangle_unified": "鬼市当铺 · 金镯与旧债"}
var path := DEFAULT_PATH
var error_message := ""
var busy := false
var fail_write := false # Fault injection, never controlled by player save data.
var last_fingerprint := ""
var last_label := "尚未保存"
var _catalogs: Dictionary = {}
var _manifest_versions: Dictionary = {}
var _summary_cache: Dictionary = {}

func _init(location := DEFAULT_PATH) -> void:
	path = location

func register_catalog(manifest: String, catalog: ContentCatalog) -> void:
	# The bootstrap catalog has already passed schema and domain validation.
	if manifest not in MANIFESTS: return
	_catalogs[manifest] = catalog
	_manifest_versions[manifest] = catalog.content_version

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
	error_message = "" if key.begins_with("auto/") and state.personal_risk_enabled and state.phase == &"open" else save_reason(state)
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
	for manifest in MANIFESTS:
		if not _manifest_versions.has(manifest):
			var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest)) if FileAccess.file_exists(manifest) else null
			_manifest_versions[manifest] = metadata.get("content_version", -1) if metadata is Dictionary else -1
		if _manifest_versions[manifest] != payload.get("content_version"): continue
		if not _catalogs.has(manifest):
			var result := JsonContentProvider.new(manifest).load_catalog()
			if not result.is_success(): continue
			_catalogs[manifest] = result.catalog
		var catalog: ContentCatalog = _catalogs[manifest]
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
	# Cache display-only results by full content, never by slot name or timestamp.
	# read_entry and write_entry still validate the current payload in full.
	var cache_key := JSON.stringify(entry).sha256_text() + ("/legacy" if key.begins_with("legacy/") else "/extended")
	if _summary_cache.has(cache_key):
		var cached: Dictionary = _summary_cache[cache_key]
		row.merge(cached.row, true)
		error_message = cached.error
		return row
	var decoded := decode_entry(entry, not key.begins_with("legacy/"))
	if decoded.is_empty():
		row.detail = error_message
	else:
		var state: RunState = decoded.state
		row.run_id = String(state.run_definition_id)
		row.valid = true
		row.detail = "%s · 第%d夜 · %s\n%s · 现银%d银元\n%s" % [NAMES.get(row.run_id, row.run_id), state.current_night_index, TimeController.clock_text(decoded.run.opening_minute, state.game_minutes), DayFlowPresenter.PHASE_LABELS.get(String(state.phase), ""), state.cash, entry.saved_at]
		if state.phase in [&"dead", &"bankrupt", &"run_ended"]: row.detail += " · 已结束"
	if _summary_cache.size() >= 64: _summary_cache.erase(_summary_cache.keys()[0])
	_summary_cache[cache_key] = {"row": {"run_id": row.run_id, "valid": row.valid, "detail": row.detail}, "error": error_message}
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
	session._pawn_choices = state.pending_pawn_choices.duplicate(true)
	if state.ghost_version == 1: state.ghost_origin.run_token = state.run_token
	session._risk_error = ""
	if state.phase == &"pre_open": session._counter.customers.prepare_night(state, decoded.run, decoded.catalog)
	MarketService.sync(state, decoded.run)
	session.message = "已读取存档。"
	last_fingerprint = fingerprint(state)
	last_label = _position_label(decoded.get("source_key", "auto/" + String(state.run_definition_id)), state, decoded.run)
	session.restored.emit()
	session.changed.emit()
	return true
