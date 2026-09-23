extends "res://tests/dragon_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	driver.check = check; driver.catalog = catalog
	for choice in ["help", "later"]:
		var s := load_stage("before-fd_search_motive")
		check(s.event_command("fd_search_motive", choice).ok, "choose " + choice)
		absent(s, "same night " + choice)
		next_night(s)
		capture(s, choice + "-preparation")
		check(s.execute("open_shop").ok, "open without invitation")
		driver.drain(s)
		absent(s, "next night uninvited " + choice)
		check(not s.event_command("fd_settle", "later").ok, "no remote settlement")
		capture(s, choice + "-uninvited")
		next_night(s)
		var lib := SaveLibrary.new("res://.godot/qa/chen-invitation/durable-" + choice + ".json")
		lib.register_catalog("res://data/first_debt_dragon_search_manifest.json", catalog)
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/first_debt_dragon_search", s._day.state, run_def, 31, catalog), "base disk")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		lib.fail_write = true
		check(not s.execute("prep_chen_invite").ok and s.read_state() == before and bytes == FileAccess.get_file_as_bytes(lib.path), "invitation disk rollback")
		lib.fail_write = false
		var count := PreparationService.count(s._day.state)
		check(s.execute("prep_chen_invite").ok, "invite retry")
		check(PreparationService.count(s._day.state) == count + 1 and s._day.state.cash == before.cash, "one shared free preparation")
		before = s.read_state()
		check(not s.execute("prep_chen_invite").ok and s.read_state() == before, "duplicate invitation")
		capture(s, choice + "-invited")
		check(s.execute("open_shop").ok, "open invited")
		driver.drain(s)
		idle(s)
		check(FirstDebt.chen_waiting(s._day.state) and s.counter_model().active_id.ends_with("/chen"), "Chen only invited")
		capture(s, choice + "-meeting")
		if choice == "later":
			check(s.event_command("fd_search_motive", "help").ok, "resume deferred promise")
		else:
			check(s.event_command("fd_settle", "later").ok, "defer settlement")
		absent(s, "reply completes " + choice)
		capture(s, choice + "-departed")
		check(not s.event_command("fd_compensation", "offer").ok, "cannot restart departed conversation")
		next_night(s); s.execute("open_shop"); driver.drain(s)
		absent(s, "invitation not recurring " + choice)
	# Completed purchases from the previous build remain readable; current live rules hide Chen.
	for stage in ["bought", "after-fd_settle"]:
		var old := load_stage(stage)
		check(old != null, "old v31 settlement journal compatible")
		if old == null: continue
		absent(old, "legacy loaded " + stage)
	var s := load_stage("bought")
	next_night(s); check(s.execute("prep_chen_invite").ok, "invite after buying dragon")
	capture(s, "return-preparation")
	s.execute("open_shop"); driver.drain(s); idle(s)
	capture(s, "return-meeting")
	check(s.event_command("fd_settle", "return").ok, "return pair during appointment")
	absent(s, "return leaves")
	capture(s, "returned")
	# Boundaries use cloned, already validated state; no claim these are a natural military playthrough.
	s = load_stage("search-ready")
	check(s.execute("prep_visitors").ok and s.execute("prep_tea").ok, "use shared preparations")
	check(not s.execute("prep_chen_invite").ok, "shared count exhausted")
	s = load_stage("search-ready"); s.execute("prep_chen_invite")
	var n := s._day.state.current_night_index
	SocialRules.night(s._day.state).closed = true
	check(DragonSearch.appointment_night(s._day.state, "chen_invite") == n + 1, "military defers same Chen appointment")
	check(not s.execute("prep_chen_invite").ok, "no second preparation during closure")
	print("CHEN INVITATION: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)

func absent(s: RunSession, label: String) -> void:
	check(not FirstDebt.chen_waiting(s._day.state), "no Chen waiting " + label)
	check(not str(s.counter_model().active_id).ends_with("/chen"), "no Chen portrait " + label)

func idle(s: RunSession) -> void:
	for i in 10:
		var v := s._counter.customers.active(s._day.state)
		if v == null: return
		check(s.counter_command("reject", v.visit_id).ok, "finish ordinary guest")
		driver.drain(s)

func next_night(s: RunSession) -> void:
	if s._day.state.phase == &"open": act(s, "close_shop")
	if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
	act(s, "resolve_night"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	driver.drain(s); act(s, "enter_room"); driver.drain(s)
	act(s, "sleep"); driver.drain(s); act(s, "finish_sleep"); act(s, "continue_run")
	if SocialRules.blocked(s._day.state):
		var kind: String = s._day.state.social.pending.kind
		check(s.social_command("decline_supply" if kind == "supply" else "close" if kind == "closure" else "pay").ok, "military resolution")
	driver.drain(s)

func capture(s: RunSession, label: String) -> void:
	var raw := SaveCodec.new().encode(s._day.state, 31)
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	check(codec.decode(raw, run_def, 31, catalog, true) != null, "cold replay " + label + " " + codec.error_message)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/chen-invitation"))
	var f := FileAccess.open("res://.godot/qa/chen-invitation/" + label + ".json", FileAccess.WRITE); f.store_string(JSON.stringify(raw))
