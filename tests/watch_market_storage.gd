extends "res://tests/watch_economy.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	MarketService.sync(s._day.state,run_def)
	var baseline := s.read_state(); var prep := PreparationService.count(s._day.state)
	(s._save as CountingStore).fail = true
	check(not s.growth_command("learn_knowledge","luxury_watch").ok and baseline == s.read_state(),"guide learning failed disk rollback")
	(s._save as CountingStore).fail = false
	check(s.growth_command("learn_knowledge","luxury_watch").ok,"guide learning real transaction")
	check(PreparationService.count(s._day.state) == prep+1 and s._day.state.cash == baseline.cash,"one preparation free silver")
	check(not s.growth_command("learn_knowledge","luxury_watch").ok and PreparationService.count(s._day.state) == prep+1,"repeat learning never charged")
	var library := SaveLibrary.new("res://.godot/qa/watch34-storage/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/watch_market_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,34,catalog),"v34 disk write "+library.error_message)
	var result := library.read_entry("manual/1")
	check(not result.is_empty() and result.catalog.content_version == 34,"v34 disk resolves new manifest")
	if not result.is_empty(): check(GhostSaveCodec.same(result.state.to_read_model(),s.read_state()),"v34 disk exact snapshot")
	var old := JsonContentProvider.new("res://data/watch_manifest.json").load_catalog()
	var old_run := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
	var store := CountingStore.new(); store.origin = {"seed":609,"run_token":"0123456789abcdef0123456789abcdef"}
	var old_session := RunSession.new(old_run,33,store,old.catalog)
	driver.catalog = old.catalog; driver.drain(old_session)
	library.register_catalog("res://data/watch_manifest.json",old.catalog)
	check(library.write_entry("manual/2",old_session._day.state,old_run,33,old.catalog),"v33 disk write "+library.error_message)
	result = library.read_entry("manual/2")
	check(not result.is_empty() and result.catalog.content_version == 33,"v33 saved manifest preserved")
	if not result.is_empty():
		check(library.adopt(result,s),"load old slot from new session")
		check(s.content_version == 33 and not s.definition.variety.has("watch_economy_version"),"old slot no new appraisal rules")
		s.new_run(); check(s.content_version == 34 and s.definition.id == "watch_market_ten","new game returns to v34")
	print("WATCH STORAGE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
