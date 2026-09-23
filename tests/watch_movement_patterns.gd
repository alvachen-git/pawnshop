extends "res://tests/watch_negotiation.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_patterns_manifest.json").load_catalog()
	check(loaded.is_success(),"v36 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,36,store,catalog)

func run() -> void:
	if not setup(): quit(1); return
	for pattern in WatchMovementPatterns.KINDS:
		for damage in ["intact","minor","major"]:
			for operation in ["stable","positional","stopping"]:
				var s := fixture35("flawed",damage,operation); var v: CustomerVisit = s._day.state.visits[0]; var id := v.item.instance_id
				v.item.goods.watch_value.pattern = pattern
				var actual: int = v.item.goods.watch_value.actual
				var picture := WatchArt.movement(v.item)
				check(picture != null and picture.get_width() == picture.get_height(),"square usable sprite "+pattern)
				check(s.fan_command("luxury_begin",id,"2").ok and command(s,id,{"op":"open"}).ok,"open mechanism")
				check(WatchAppraisal.observations(s._day.state,v.item).is_empty(),"no details before actual inspection")
				for i in 2:
					var point := WatchAppraisal.spot(v.item,i)
					check(command(s,id,{"op":"inspect","point":[point.x,point.y]}).ok,"real hotspot")
					check(WatchAppraisal.row(s._day.state,id).spots.size() == i+1,"separate observation areas")
				var clues := WatchAppraisal.observations(s._day.state,v.item)
				if pattern == "lettering": check(clues[0].contains("PHILIPPEE") and not clues[1].contains("宽垫圈"),"engraving-specific clues")
				if pattern == "gears": check(clues[0].contains("大齿轮") and clues[1].contains("小齿轮"),"gear-specific clues")
				check(say(s,{"identity":"imitation"}).ok,"pattern proof still uses v35 negotiation")
				check(v.item.goods.watch_value.actual == actual,"visual pattern cannot alter value")
				var saved := RunSnapshot.copy(s._day.state)
				check(WatchMovementPatterns.kind(saved.visits[0].item) == pattern and WatchAppraisal.observations(saved,saved.visits[0].item) == clues,"saved pattern and matching observations stable")
	for variant in ["sound","mended"]:
		var s := fixture35(variant); var item: ItemInstance = s._day.state.visits[0].item
		check(not item.goods.watch_value.has("pattern") and WatchArt.movement(item) is AtlasTexture,"genuine and replacement remain original assets")
	var s := fixture35("flawed"); var item: ItemInstance = s._day.state.visits[0].item
	var counts := {"standard":0,"lettering":0,"gears":0}
	for seed_value in 3000:
		s._day.state.run_seed = seed_value; WatchMovementPatterns.attach(s._day.state,item)
		counts[WatchMovementPatterns.kind(item)] += 1
		if seed_value < 10:
			var saved := item.goods.duplicate(true); WatchMovementPatterns.attach(s._day.state,item); check(saved == item.goods,"fixed independent pattern key")
	for pattern in counts: check(absf(counts[pattern]/3000.0-1.0/3.0) < .04,"pattern distribution")
	var old := JsonContentProvider.new("res://data/watch_negotiation_manifest.json").load_catalog()
	var old_run := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
	check(not WatchMovementPatterns.enabled(old_run),"v35 frozen")
	var existing := ItemInstance.new(); existing.selected_variant_id = "flawed"
	check(WatchMovementPatterns.kind(existing) == "standard" and WatchArt.movement(existing) is AtlasTexture,"old item fallback preserves original image")
	# Real disk slot and cold replay of the new catalog, then v35 adoption.
	s = second_night(); InvestigationSaveCodec.clear_cache()
	var library := SaveLibrary.new("res://.godot/qa/watch36-library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/watch_patterns_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,36,catalog),"new slot writes")
	var read := library.read_entry("manual/1")
	check(not read.is_empty() and read.catalog.content_version == 36,"new slot resolves")
	if not read.is_empty(): check(GhostSaveCodec.same(s.read_state(),read.state.to_read_model()),"new slot exact replay")
	var store := CountingStore.new(); store.origin = {"seed":609,"run_token":"0123456789abcdef0123456789abcdef"}
	var old_session := RunSession.new(old_run,35,store,old.catalog); driver.catalog = old.catalog; driver.drain(old_session)
	library.register_catalog("res://data/watch_negotiation_manifest.json",old.catalog)
	check(library.write_entry("manual/2",old_session._day.state,old_run,35,old.catalog),"old slot writes")
	read = library.read_entry("manual/2")
	check(not read.is_empty() and library.adopt(read,s) and not WatchMovementPatterns.enabled(s.definition),"old slot uses original patterns")
	s.new_run(); check(s.content_version == 36,"new game returns to v36")
	print("WATCH PATTERNS: %d passes, %d failures; %s" % [passes,failures,counts])
	quit(0 if failures == 0 else 1)
