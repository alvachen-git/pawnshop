extends "res://tests/pawn_interest.gd"

func manifest_path() -> String:
	return "res://data/preopen_recycler_manifest.json"

func run() -> void:
	if not setup(): quit(1); return
	for label in ["preopen", "sold", "no-points", "no-points-stock"]:
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/recycler/" + label + ".json"))
		InvestigationSaveCodec.clear_cache()
		var decoded := SaveLibrary.new().decode_entry({"format": SaveLibrary.FORMAT, "saved_at": "qa", "payload": payload})
		check(not decoded.is_empty(), "cold process library restore " + label)
		if decoded.is_empty(): continue
		var state: RunState = decoded.state
		check(state.run_definition_id == "preopen_recycler" and decoded.catalog.content_version == 47, "independent run identity")
		check(PreparationService.action_points(state, run_def) == {"preopen":2, "sold":1, "no-points":0, "no-points-stock":0}[label], "AP rebuilt from transaction history")
	for pair in [["res://data/lu_trade_manifest.json", "res://scenes/lu_v44.tscn"], ["res://data/pawn_interest_manifest.json", "res://scenes/start_pawn_v45.tscn"], ["res://data/gramophone_release_manifest.json", "res://scenes/start_gramophone_v46.tscn"], [manifest_path(), "res://scenes/start_recycler_v47.tscn"]]:
		var loaded := JsonContentProvider.new(pair[0]).load_catalog()
		check(loaded.is_success() and ResourceLoader.exists(pair[1]), "compatible named entry " + pair[1])
		if not loaded.is_success(): continue
		var r: RunDefinition = loaded.catalog.get_definition("runs", loaded.catalog.default_run_id)
		var store := CountingStore.new(); store.origin = {"seed":42, "run_token":"0123456789abcdef0123456789abcdef"}
		var session := RunSession.new(r, loaded.catalog.content_version, store, loaded.catalog)
		var payload := SaveCodec.new().encode(session._day.state, loaded.catalog.content_version)
		InvestigationSaveCodec.clear_cache()
		check(not SaveLibrary.new().decode_entry({"format":SaveLibrary.FORMAT, "saved_at":"qa", "payload":payload}).is_empty(), "historical save library decode " + String(r.id))
		if r.id != run_def.id: check(SaveCodec.new().decode(payload, run_def, 47, catalog, true) == null, "v47 rejects old save without migrating")
	print("RECYCLER RELOAD: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
