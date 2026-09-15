extends "res://tests/run_mirror_chapter.gd"

const OUT := "res://.godot/qa/aqi"
var route_name := ""

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/aqi_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "aqi catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "aqi_seven")
	run_def._randomize_seed = false
	driver.check = check; driver.catalog = catalog
	DirAccess.make_dir_recursive_absolute(OUT + "/process")
	if "process-read" in OS.get_cmdline_user_args():
		var files := DirAccess.get_files_at(OUT + "/process")
		check(files.size() >= 50, "stage snapshots exist")
		for filename in files:
			var data = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/process/" + filename))
			var codec := SaveCodec.new()
			var recovered := codec.decode(data, run_def, 22, catalog, true)
			check(recovered != null, "cross process " + filename + ": " + codec.error_message)
			if recovered != null and recovered.phase == &"shop_resolution" and recovered.risk_pending.is_empty() and not recovered.pending_event_id.is_empty():
				var resumed := RunSession.new(run_def, 22, SaveManager.new(OUT + "/process-resume.json"), catalog)
				resumed._day.state = recovered
				var model := resumed.event_model()
				check(resumed.event_command(model.pending_id, model.buttons[0].detail).ok, "continue choice in new process " + filename)
				check(codec.decode(codec.encode(resumed._day.state, 22), run_def, 22, catalog) != null, "continued state is durable " + filename)
		print("AQI PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1); return
	for route in ["help", "name", "decline", "paper", "missed", "reject", "sold", "shop_death", "shop_retreat", "sleep_death"]:
		route_name = route
		run_def._seed = {"help": 42, "name": 1, "decline": 123, "paper": 8}.get(route, 42)
		if route == "sleep_death":
			for seed_value in 64:
				var sample := RunState.create(run_def); sample.run_seed = seed_value
				if OpeningPreparation.plan(sample, run_def, catalog).any(func(row: Dictionary) -> bool: return row.night == 3 and row.get("night_policy") == "wet_cloth"):
					run_def._seed = seed_value; break
		play_aqi(route)
		if failures > 0: break
	legacy_content()
	content_validation()
	print("AQI TESTS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)

func fresh(route: String) -> RunSession:
	return RunSession.new(run_def, catalog.content_version, SaveManager.new(OUT + "/runtime/%d_%s.json" % [Time.get_ticks_usec(), route]), catalog)

func snapshot(s: RunSession, stage: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 22)
	check(codec.decode(data, run_def, 22, catalog, true) != null, "restore " + stage + ": " + codec.error_message)
	var f := FileAccess.open(OUT + "/process/%s-%d-%s.json" % [route_name, s._day.state.current_night_index, stage], FileAccess.WRITE)
	f.store_string(JSON.stringify(data)); f.close()

func play_aqi(route: String) -> void:
	var s := fresh(route)
	for n in range(1, 8):
		driver.open(s)
		if route == "sleep_death" and n == 3:
			var found := false
			for guard in 120:
				var v := s._counter.customers.active(s._day.state)
				if v != null:
					if v.night_policy == "wet_cloth":
						check(s.counter_command("question", v.visit_id, "origin").ok, "third night taboo creates actual sleep risk")
						if v.status == "active": s.counter_command("reject", v.visit_id)
						found = true; break
					s.counter_command("reject", v.visit_id)
				else: driver.action(s, "short_task")
			check(found, "real wet-cloth guest reached")
		elif route in ["reject", "sold", "shop_death", "shop_retreat"]:
			driver.work(s, "sell_early" if route == "sold" else ("reject" if route == "reject" else "covered"))
		else:
			# Early closure is an authorized normal route, without any mirror investigation.
			var v := s._counter.customers.active(s._day.state)
			if n == 1 and v != null: check(s.counter_command("reject", v.visit_id).ok, "decline tutorial purchase")
			driver.drain(s)
		if n == 7 and route in ["shop_death", "shop_retreat"]:
			for item in s._day.state.inventory_instances:
				if item.definition_id == "item_weeping_mirror" and item.ownership_state == "owned": check(s.risk_command("uncover", item.instance_id).ok, "uncover seventh night")
		if s._day.state.phase == &"open": driver.action(s, "close_shop")
		driver.action(s, "wait_until_seal")
		driver.action(s, "resolve_night")
		snapshot(s, "seal")
		if not s._day.state.risk_pending.is_empty():
			check(s.event_model().presentation.is_empty(), "risk takes visual precedence")
			check(not s.event_command("aq_arrival", "inspect").ok, "cannot choose through risk")
			check(s.risk_command("defy" if route == "shop_death" and n == 7 else "retreat", s._day.state.risk_pending).ok, "risk resolution with queued story")
			snapshot(s, "risk_resolved")
			if s._day.state.phase == &"dead":
				check("aq_met" not in s._day.state.narrative_flags and s._day.state.pending_event_id.is_empty(), "shop death ends story")
				return
		if n == 7:
			check(s._day.state.pending_event_id == "aq_arrival", "guaranteed seventh night arrival " + route)
			check(not s.execute("enter_room").ok, "no upstairs shortcut")
			if route == "paper": atomic_event_failure(s)
			var financial := FinancialSummary.build(s._day.state)
			var cash := s._day.state.cash
			var items := s._day.state.inventory_instances.size()
			for guard in 15:
				var m := s.event_model()
				if m.pending_id.is_empty(): break
				var choice: String = m.buttons[0].detail
				if m.pending_id == "aq_arrival" and route in ["name", "decline"]: choice = "name"
				if m.pending_id == "aq_name" and route == "decline": choice = "decline"
				if m.pending_id == "aq_repaired":
					check(m.buttons.any(func(b: Dictionary) -> bool: return b.detail == "paper") == (route == "paper"), "only discovered paper offers question")
					choice = "paper" if route == "paper" else "bye"
				if m.pending_id == "aq_drawer" and route == "decline": choice = "skip"
				check(s.event_command(m.pending_id, choice).ok, "chapter " + m.pending_id + "/" + choice)
				var count := s._day.state.event_history.size()
				check(not s.event_command(m.pending_id, choice).ok and count == s._day.state.event_history.size(), "duplicate choice ignored")
				snapshot(s, m.pending_id)
			check("aq_chapter_done" in s._day.state.narrative_flags, "chapter resolved")
			check(("aq_helped" in s._day.state.narrative_flags) == (route != "decline"), "help record")
			check(("aq_paper_asked" in s._day.state.narrative_flags) == (route == "paper"), "question record")
			check(financial == FinancialSummary.build(s._day.state) and cash == s._day.state.cash and items == s._day.state.inventory_instances.size(), "story has no economy or inventory effects")
		driver.action(s, "enter_room"); driver.drain(s)
		snapshot(s, "room")
		for id in ["aq_coat", "aq_paper"]:
			check(s.room_observation_model(id).available == (n >= (2 if id == "aq_coat" else 5)), "clue opening " + id)
			if n < (2 if id == "aq_coat" else 5): check(not s.observe_room(id).ok, "no early observation")
		if route == "paper" and n in [2, 5]:
			var id := "aq_coat" if n == 2 else "aq_paper"
			atomic_observation_failure(s, id)
			var minutes := s._day.state.game_minutes
			var cash := s._day.state.cash
			check(s.observe_room(id).ok, "first discovery")
			var count := s._day.state.event_history.size()
			check(s.observe_room(id).ok and count == s._day.state.event_history.size(), "free reread no duplicate")
			check(minutes == s._day.state.game_minutes and cash == s._day.state.cash, "observation free")
			driver.resume(s); snapshot(s, "observed")
		if n == 7:
			check(s.room_observation_model("aq_floorplan").available == (route != "decline"), "floorplan reread only when taken")
			tampering(s)
		driver.action(s, "sleep"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "sleep risk")
		driver.action(s, "finish_sleep")
		if route == "sleep_death" and n == 7:
			check(s._day.state.phase == &"dead" and "aq_met" in s._day.state.narrative_flags and s._day.state.pending_event_id.is_empty(), "existing lamp risk kills after Aqi")
			snapshot(s, "sleep_death")
			return
		driver.action(s, "continue_run")
		snapshot(s, "next")
	check(s._day.state.phase == &"run_ended" and s._day.state.current_night_index == 7 and s._day.state.summaries.size() == 7, "ends at seven nights")
	if route != "paper": check("aq_coat_seen" not in s._day.state.narrative_flags and "aq_paper_seen" not in s._day.state.narrative_flags, "all clues missable")

func atomic_observation_failure(s: RunSession, id: String) -> void:
	var lib := SaveLibrary.new(OUT + "/fault_%d.json" % Time.get_ticks_usec())
	var before := s.read_state()
	s._save.library = lib; lib.fail_write = true
	check(not s.observe_room(id).ok and before == s.read_state(), "observation save failure rolls back")
	s._save.library = null

func atomic_event_failure(s: RunSession) -> void:
	var lib := SaveLibrary.new(OUT + "/fault_event.json")
	var before := s.read_state()
	s._save.library = lib; lib.fail_write = true
	check(not s.event_command("aq_arrival", "inspect").ok and before == s.read_state(), "event save failure rolls back")
	s._save.library = null

func tampering(s: RunSession) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 22)
	var forged := data.duplicate(true)
	if "aq_coat_seen" in forged.narrative_flags: forged.narrative_flags.erase("aq_coat_seen")
	else: forged.narrative_flags.append("aq_coat_seen")
	check(codec.decode(forged, run_def, 22, catalog) == null, "reject fabricated known flags")
	forged = data.duplicate(true)
	forged.event_history = forged.event_history.filter(func(row: Dictionary) -> bool: return not row.event_id.begins_with("aq_"))
	forged.narrative_flags = forged.narrative_flags.filter(func(flag: String) -> bool: return not flag.begins_with("aq_"))
	check(codec.decode(forged, run_def, 22, catalog) == null, "reject upstairs without chapter even with matching flags")

func legacy_content() -> void:
	for manifest in ["res://data/night_market_manifest.json", "res://data/pawn_chance_manifest.json", "res://data/integrated_manifest.json"]:
		var loaded := JsonContentProvider.new(manifest).load_catalog()
		check(loaded.is_success(), "legacy catalog " + manifest)
		if not loaded.is_success(): continue
		var old_run := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
		var old := RunSession.new(old_run, loaded.catalog.content_version, SaveManager.new(OUT + "/old.json"), loaded.catalog)
		check(old.room_observation_model("aq_coat").is_empty() and "aq_arrival" not in old_run.event_ids, "old run has no new story")
		var codec := SaveCodec.new()
		check(codec.decode(codec.encode(old._day.state, loaded.catalog.content_version), old_run, loaded.catalog.content_version, loaded.catalog) != null, "legacy checkpoint")

func content_validation() -> void:
	var event := catalog.get_definition("events", "aq_arrival") as EventDefinition
	var minutes: int = event.choices[0].minutes
	event.choices[0]._minutes = 5
	check(not EventDomainValidator.validate(catalog).is_empty(), "shop story cannot consume time")
	event.choices[0]._minutes = minutes
	event._phase = "day_summary"
	check(not EventDomainValidator.validate(catalog).is_empty(), "invalid narrative phase rejected")
	event._phase = "shop_resolution"
	check(EventDomainValidator.validate(catalog).is_empty(), "valid shop phase content accepted")
