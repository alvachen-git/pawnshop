extends "res://tests/watch_appraisal.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	var library := SaveLibrary.new("res://.godot/qa/watch-storage/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/watch_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,33,catalog),"v33 disk write "+library.error_message)
	var result := library.read_entry("manual/1")
	check(not result.is_empty() and result.catalog.content_version == 33,"v33 disk resolves new manifest")
	if not result.is_empty(): check(GhostSaveCodec.same(result.state.to_read_model(),s.read_state()),"v33 disk exact snapshot")
	var old := JsonContentProvider.new("res://data/tiered_manifest.json").load_catalog()
	var old_run := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
	var store := CountingStore.new(); store.origin = {"seed":609,"run_token":"0123456789abcdef0123456789abcdef"}
	var old_session := RunSession.new(old_run,32,store,old.catalog)
	driver.catalog = old.catalog; driver.drain(old_session)
	library.register_catalog("res://data/tiered_manifest.json",old.catalog)
	check(library.write_entry("manual/2",old_session._day.state,old_run,32,old.catalog),"v32 disk write "+library.error_message)
	result = library.read_entry("manual/2")
	check(not result.is_empty() and result.catalog.content_version == 32,"v32 saved manifest preserved")
	if not result.is_empty():
		check(library.adopt(result,s),"load old slot from new session")
		check(s.content_version == 32 and not s.definition.variety.has("watch_appraisal_version"),"old slot no new appraisal rules")
		s.new_run(); check(s.content_version == 33 and s.definition.id == "watch_ten","new game returns to v33")
	print("WATCH STORAGE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
