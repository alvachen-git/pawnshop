extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/integrated_manifest.json").load_catalog()
	check(loaded.is_success(), "bell catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "integrated_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	var s := fresh("bell")
	var before := s.read_state()
	check(not s.bell_model().enabled and not s.bell_command("wait").ok and s.read_state() == before, "bell cannot bypass opening")
	driver.open(s)
	var visit := s._counter.customers.active(s._day.state)
	var id := visit.visit_id
	var start := s._day.state.game_minutes
	check(s.bell_model().mode == "dismiss", "occupied counter requires hold")
	check(not s.bell_command("wait").ok and start == s._day.state.game_minutes, "no fast forward through active visitor")
	check(s.bell_command("dismiss", id).ok and visit.status == "rejected" and s._day.state.game_minutes == start + 5, "dismiss uses normal five minute reject")
	before = s.read_state()
	check(not s.bell_command("dismiss", id).ok and s.read_state() == before, "stale hold cannot dismiss following visitor")
	var next := s._day.state.visits[1]
	check(s.bell_command("wait").ok and s._day.state.game_minutes == next.arrival and next.status == "active", "wait stops exactly at next arrival")
	for i in 6:
		visit = s._counter.customers.active(s._day.state)
		if visit != null: check(s.bell_command("dismiss", visit.visit_id).ok, "dismiss next")
		if s.bell_model().enabled: check(s.bell_command("wait").ok, "next customer")
	before = s.read_state()
	check(not s.bell_model().enabled and not s.bell_command("wait").ok and s.read_state() == before, "no visitors does not skip night")
	driver.finish(s, "covered")
	check(s._day.state.current_night_index == 2, "bell timing survives checkpoint replay")
	# A pending event in the middle of a gap stops the clock before the next visitor.
	var event := catalog.get_definition("events", "evt_intro_first_customer") as EventDefinition
	var old_window := event._window_start
	event._window_start = 10
	var blocked := fresh("event_gap")
	driver.open(blocked)
	visit = blocked._counter.customers.active(blocked._day.state)
	check(blocked.bell_command("dismiss", visit.visit_id).ok, "leave first visitor before delayed event")
	check(blocked.bell_command("wait").ok and blocked._day.state.game_minutes == 10 and not blocked._day.state.pending_event_id.is_empty(), "wait stops on intervening story")
	before = blocked.read_state()
	check(not blocked.bell_command("wait").ok and blocked.read_state() == before, "pending story blocks bell")
	event._window_start = old_window
	var mirror := fresh("mirror_bell")
	for n in 2: driver.open(mirror); driver.finish(mirror, "covered")
	driver.open(mirror)
	visit = mirror._counter.customers.active(mirror._day.state)
	check(mirror.counter_command("offer", visit.visit_id, "", visit.trade.asking_price).ok, "buy mirror for bell guard")
	for n in 8:
		visit = mirror._counter.customers.active(mirror._day.state)
		if visit != null and visit.visit_id.ends_with("/n3_visit5"): break
		if visit != null: mirror.bell_command("dismiss", visit.visit_id)
		else: mirror.bell_command("wait")
	check(mirror.mirror_command("midnight_old_ticket", "peek").ok, "pending mirror choice")
	before = mirror.read_state()
	check(not mirror.bell_command("dismiss", mirror.counter_model().active_id).ok and mirror.read_state() == before, "bell cannot bypass mirror choice")
	print("BELL TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
