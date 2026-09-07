extends SceneTree

var passes := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition
var driver = preload("res://tests/integrated_test_driver.gd").new()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else:
		failures += 1; push_error("FAIL " + label)
		if failures >= 3: quit(1)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/integrated_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "integrated catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "integrated_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	for seed_value in 256:
		var rows := VarietyService.plan(run_def, catalog, seed_value)
		check(rows.size() == 42 and rows == VarietyService.plan(run_def, catalog, seed_value), "stable 42 visits")
		check(rows[0].item_id == "intro_silver_hairpin" and rows[12].item_id == "item_weeping_mirror" and rows[16].variant_id == "flawed", "authored story positions")
		check(rows.slice(12, 18).map(func(row: Dictionary) -> int: return row.arrival) == [0, 90, 180, 270, 360, 420], "third night schedule")
		var roles := {}
		for row in rows:
			if row.has("seven_role"): roles[row.seven_role] = row
		check(roles.size() == 7 and roles.pawn.night == 3 and roles.pawn.item_id != "item_weeping_mirror", "ordinary samples survive story slots")
	for route in ["reject", "timeout", "covered", "stop", "pursue", "sell_early", "sell_pursued", "uncovered", "death"]: play(route)
	library_compatibility()
	print("INTEGRATED SEVEN TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func fresh(route: String) -> RunSession:
	return RunSession.new(run_def, 14, SaveManager.new("res://.godot/qa/integrated_seven/runtime/test_%d_" % Time.get_ticks_usec() + route + ".json"), catalog)

func play(route: String) -> void:
	var s := fresh(route)
	for n in range(1, 8):
		driver.open(s)
		driver.work(s, route)
		driver.finish(s, route)
		if s._day.state.phase == &"dead": break
	if route == "death": check(s._day.state.phase == &"dead" and s._day.state.death_archive.size() == 1, "death archive")
	else:
		check(s._day.state.phase == &"run_ended" and s._day.state.summaries.size() == 7 and s._day.state.fee_history.size() == 7, "seven real nights " + route)
		check(s._day.state.pawn_tickets.size() == 1 and s._day.state.pawn_tickets[0].status == "redeemed", "sixth pawn redeemed " + route)
		check(s._day.state.sale_records.filter(func(row: Dictionary) -> bool: return row.buyer_id == PreparationService.BUYER).size() == 2, "two pens sold " + route)
	if route == "stop":
		var codec := SaveCodec.new()
		var tampered := codec.encode(s._day.state, 14).duplicate(true)
		for row in tampered.scenario_history:
			if row.visit_id.ends_with("/n3_visit5") and row.command == "appraise" and row.detail == "observe":
				row.clues.append("flaw")
				break
		check(codec.decode(tampered, run_def, 14, catalog) == null, "reject invented evidence attributed to mirror")
	if route in ["reject", "timeout"]: check("INTRO_FIRST_TRADE_DONE" not in s._day.state.narrative_flags, "later purchases do not fabricate tutorial sale")
	check("INTRO_COMPLETE" in s._day.state.narrative_flags and s.definition.fee_policy.principal == 500, "opening and economy survive " + route)

func library_compatibility() -> void:
	var s := fresh("library")
	var lib := SaveLibrary.new("res://.godot/qa/integrated_seven/runtime/library_%d.json" % Time.get_ticks_usec())
	s._save.library = lib
	check(lib.write_entry("manual/1", s._day.state, run_def, 14, catalog), "manual opening save")
	var model := s.event_model()
	check(s.event_command(model.pending_id, model.buttons[0].detail).ok, "advance opening from manual checkpoint")
	var decoded := lib.read_entry("manual/1")
	check(not decoded.is_empty() and lib.adopt(decoded, s), "restore opening manually")
	check(s._day.state.pending_event_id == "evt_intro_factory_paycut" and s._day.state.cash == 300, "opening restored without duplicated assets")
	var original_file := FileAccess.get_file_as_string(lib.path)
	lib.fail_write = true
	model = s.event_model()
	var before := s.read_state()
	check(not s.event_command(model.pending_id, model.buttons[0].detail).ok and s.read_state() == before and FileAccess.get_file_as_string(lib.path) == original_file, "opening write failure rolls back atomically")
	lib.fail_write = false
	for manifest in ["content_manifest", "opening_manifest", "seven_night_manifest"]:
		var old := JsonContentProvider.new("res://data/" + manifest + ".json").load_catalog().catalog
		var old_run := old.get_definition("runs", old.default_run_id) as RunDefinition
		var old_session := RunSession.new(old_run, old.content_version, SaveManager.new("res://.godot/qa/integrated_seven/runtime/old.json"), old)
		check(lib.write_entry("manual/2", old_session._day.state, old_run, old.content_version, old), "preserve legacy " + manifest)
		var prior: Dictionary = lib._read().entries["manual/2"].duplicate(true)
		decoded = lib.read_entry("manual/2")
		check(not decoded.is_empty() and lib.adopt(decoded, s), "load legacy " + manifest)
		check(s.definition.id == old_run.id, "legacy retains own content")
		s.new_run()
		check(s.definition.id == "integrated_seven" and s._day.state.pending_event_id == "evt_intro_factory_paycut" and s._day.state.cash == 300, "new game returns to launch definition")
		check(prior == lib._read().entries["manual/2"], "new game leaves legacy slot intact")
		if manifest == "content_manifest": check(not old_run.mirror_encounters[0].clue_id.is_empty(), "historical mirror keeps original evidence rule")
	for i in range(1, 7): check(lib.write_entry("manual/%d" % i, s._day.state, run_def, 14, catalog), "all six manual positions accept integrated game")
