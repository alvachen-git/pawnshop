extends "res://tests/watch_negotiation.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	var library := SaveLibrary.new("res://.godot/qa/watch35-storage/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/watch_negotiation_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,35,catalog),"v35 isolated disk write "+library.error_message)
	var result := library.read_entry("manual/1")
	check(not result.is_empty() and result.catalog.content_version == 35,"v35 saved manifest")
	if not result.is_empty(): check(GhostSaveCodec.same(result.state.to_read_model(),s.read_state()),"disk exact snapshot")
	for manifest in ["res://data/watch_market_manifest.json","res://data/watch_manifest.json","res://data/tiered_manifest.json","res://data/wealthy_manifest.json"]:
		var old := JsonContentProvider.new(manifest).load_catalog()
		var old_run := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
		var store := CountingStore.new(); store.origin = {"seed":609,"run_token":"0123456789abcdef0123456789abcdef"}
		var old_session := RunSession.new(old_run,old.catalog.content_version,store,old.catalog)
		driver.catalog = old.catalog; driver.drain(old_session)
		library.register_catalog(manifest,old.catalog)
		check(library.write_entry("manual/2",old_session._day.state,old_run,old.catalog.content_version,old.catalog),"old disk write")
		result = library.read_entry("manual/2")
		check(not result.is_empty() and result.catalog.content_version == old.catalog.content_version,"frozen old manifest")
		if not result.is_empty():
			check(library.adopt(result,s),"load old slot from new session")
			check(not WatchNegotiation.enabled(s.definition),"no new claim rules for old save")
			s.new_run(); check(s.content_version == 35 and s.definition.id == "watch_negotiation_ten","new game returns to v35")
	print("WATCH NEGOTIATION STORAGE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
