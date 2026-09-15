extends "res://tests/run_aqi.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/aqi_investigation_manifest.json").load_catalog()
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	var codec := SaveCodec.new()
	var total := 0
	for filename in DirAccess.get_files_at("res://.godot/qa/v24"):
		if not filename.begins_with("aq-") or not filename.ends_with(".json"): continue
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v24/" + filename))
		InvestigationSaveCodec.clear_cache()
		var state := codec.decode(raw, run_def, 24, catalog, true)
		check(state != null, "cold process replay " + filename + ": " + codec.error_message)
		if state == null: continue
		total += 1
		var store := GhostReplayStore.new(); store.origin = raw.ghost_origin
		var s := RunSession.new(run_def, 24, store, catalog)
		s._day.state = state
		if state.phase == &"shop_resolution":
			var model := s.event_model()
			check(s.event_command(model.pending_id, model.buttons[0].detail).ok, "continue restored segment")
			check(codec.decode(codec.encode(s._day.state, 24), run_def, 24, catalog, true) != null, "next segment replays")
		var forged: Dictionary = raw.duplicate(true); forged.content_version = 23
		check(codec.decode(forged, run_def, 24, catalog, true) == null, "version tamper rejected")
		check(codec.decode(raw, run_def, 23, catalog, true) == null, "caller version mismatch rejected")
	check(total >= 40, "all authored branches have process snapshots")
	print("AQI V24 PROCESS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
