extends SceneTree

var failures := 0
var assertions := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("FAIL " + label)

func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/market_seven_manifest.json").load_catalog()
	check(loaded.is_success(), "cross-process catalog")
	var run: RunDefinition = loaded.catalog.get_definition("runs", "market_seven")
	var codec := SaveCodec.new()
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/market_seven/cross_process.json"))
	var state := codec.decode(payload, run, 17, loaded.catalog)
	check(state != null, "restore complete chapter: " + codec.error_message)
	if state != null:
		check(state.phase == &"run_ended" and "wm_seek" in state.narrative_flags and state.mirror_history.size() == 2 and state.market_history.size() == 8, "chapter and all demand messages restored")
	var library := SaveLibrary.new("res://.godot/qa/market_seven/library.json")
	check(not library.read_entry("manual/1").is_empty(), "manual opening restored in independent process")
	if "ui" in OS.get_cmdline_user_args():
		var folder := "res://.godot/qa/market_seven/"
		var latest := ""
		for file in DirAccess.get_files_at(folder):
			if file.begins_with("ui_") and file.ends_with(".json") and (latest.is_empty() or FileAccess.get_modified_time(folder + file) >= FileAccess.get_modified_time(latest)):
				latest = folder + file
		check(not latest.is_empty(), "real UI produced an archive library")
		if not latest.is_empty():
			var entry := SaveLibrary.new(latest).read_entry("auto/market_familiar")
			check(not entry.is_empty(), "real default automatic slot restored in another process")
			if not entry.is_empty():
				check(entry.state.market_history.size() >= 4 and entry.state.sale_records.any(func(row: Dictionary) -> bool: return row.buyer_id == "buyer_lu"), "automatic slot retains Lu sale and cross-night demand")
	if "economy" in OS.get_cmdline_user_args():
		payload = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/market_seven/economy_checkpoint.json"))
		state = codec.decode(payload, run, 17, loaded.catalog)
		check(state != null, "real market sales restore: " + codec.error_message)
		if state != null:
			check(state.sale_records.any(func(row: Dictionary) -> bool: return row.buyer_id == "buyer_lu"), "persisted real Lu sale")
			var tampered: Dictionary = payload.duplicate(true)
			tampered.sale_batches[0].market_id = "future"
			check(codec.decode(tampered, run, 17, loaded.catalog) == null, "reject tampered departure market")
			tampered = payload.duplicate(true); tampered.market_history.pop_back()
			check(codec.decode(tampered, run, 17, loaded.catalog) == null, "reject incomplete demand history")
		library = SaveLibrary.new("res://.godot/qa/market_seven/economy_library.json")
		check(not library.read_entry("manual/1").is_empty(), "manual sales restored in independent process")
	print("MARKET SEVEN PROCESS TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
