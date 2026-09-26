extends "res://tests/pawn_interest.gd"
func manifest_path() -> String:
	return "res://data/silver_market_manifest.json"
func run() -> void:
	if not setup(): quit(1); return
	for label in ["intro-0", "intro-1", "intro-2", "unlocked", "sold", "next-day"]:
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/silver/" + label + ".json"))
		InvestigationSaveCodec.clear_cache()
		var decoded := SaveLibrary.new().decode_entry({"format": SaveLibrary.FORMAT, "saved_at": "qa", "payload": payload})
		check(not decoded.is_empty(), "cold library " + label)
		if decoded.is_empty(): continue
		check(decoded.state.run_definition_id == "silver_market" and decoded.catalog.content_version == 48, "isolated identity")
		check(SilverPolicy.unlocked(decoded.state) == (label in ["unlocked", "sold", "next-day"]), "restored unlock")
		check(SilverPolicy.rate(decoded.state) == SilverPolicy.market(int(payload.run_seed), int(payload.current_night_index)).percent, "restored daily market")
	for path in ["res://data/preopen_recycler_manifest.json", "res://data/gramophone_release_manifest.json", "res://data/pawn_interest_manifest.json", "res://data/lu_trade_manifest.json"]:
		var loaded := JsonContentProvider.new(path).load_catalog(); check(loaded.is_success(), "legacy catalog")
		var run: RunDefinition = loaded.catalog.get_definition("runs", loaded.catalog.default_run_id)
		var store := CountingStore.new(); store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
		var old := RunSession.new(run, loaded.catalog.content_version, store, loaded.catalog)
		var payload := SaveCodec.new().encode(old._day.state, loaded.catalog.content_version)
		check(not SaveLibrary.new().decode_entry({"format":1,"saved_at":"qa","payload":payload}).is_empty(), "legacy library load")
		check(SaveCodec.new().decode(payload, run_def, 48, catalog, true) == null, "old save never migrated")
	print("SILVER RELOAD: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
