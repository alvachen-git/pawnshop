extends "res://tests/dragon_durability.gd"
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	var s := load_stage("lu")
	var st := s._day.state
	check(not s.event_command("fd_dragon", "buy").ok and not s.event_command("fd_lu", "ask").ok, "v31 old shortcut absent")
	check(s.event_command("fd_dragon_quote", "fair").ok, "quote first visit")
	check(s.event_command("fd_dragon_deal", "later").ok and not DragonSearch.waiting(st), "defer departs")
	st.phase = &"pre_open"; st.current_night_index += 1; st.game_minutes = 0; st.social.reputation = -1
	check(s.execute("prep_dragon_invite").ok, "next night rebook")
	st.phase = &"open"; st.game_minutes = 60; st.visits.clear()
	check(s.event_command("fd_dragon_quote", "dear").ok and DragonSearch.price(st) == 200, "new appointment repriced")
	s = load_stage("invited"); st = s._day.state
	var count := PreparationService.count(st)
	var n := st.current_night_index
	SocialRules.night(st).closed = true
	check(DragonSearch.appointment_night(st) == n + 1, "closure defers appointment")
	check(not s.execute("prep_dragon_invite").ok and PreparationService.count(st) == count, "closure does not charge again")
	st.current_night_index += 1; st.game_minutes = 60; st.phase = &"open"; st.visits.clear()
	check(DragonSearch.waiting(st), "next business day arrives free")
	st.risk_pending = "test"
	check(not DragonSearch.ready(s._day, s._counter), "crisis before appointment")
	st.risk_pending = ""; st.phase = &"dead"
	check(not DragonSearch.waiting(st) and not s.event_command("fd_dragon_quote", "fair").ok, "death stops meeting")
	s = load_stage("search-sent"); st = s._day.state
	st.phase = &"shop_resolution"; st.game_minutes = 540; st.pending_event_id = ""; st.risk_pending = "test"
	s._events.poll(st, run_def)
	check(st.pending_event_id.is_empty(), "letter waits crisis")
	st.risk_pending = ""; s._events.poll(st, run_def)
	check(st.pending_event_id == "ds_search_message", "letter after crisis")
	st.phase = &"dead"; s._events.poll(st, run_def)
	check(st.pending_event_id.is_empty(), "death cancels letter")
	s = load_stage("search-ready"); st = s._day.state
	st.phase = &"shop_resolution"; st.game_minutes = 540; st.pending_event_id = ""
	s._events.poll(st, run_def)
	check(st.pending_event_id.is_empty(), "no unsent letter")
	for reputation in [-100, -50, -20, 0, 20, 50, 100]:
		s = load_stage("search-ready"); st = s._day.state
		st.current_night_index = 11; st.social.reputation = reputation; st.social.nights.clear(); st.visit_history.clear(); st.inventory_instances.clear(); st.narrative_flags.clear(); st.event_history.clear()
		var rows := OpeningPreparation.plan(st, run_def, catalog).filter(func(r: Dictionary) -> bool: return r.night == 11)
		check(rows.any(func(r: Dictionary) -> bool: return r.customer_id == "fd_seller"), "seller preserved rep%d" % reputation)
		check(rows.size() == 6 + ReputationService.adjustment(reputation), "normal rep count%d" % reputation)
		st.current_night_index = 12; st.social.nights.clear()
		rows = OpeningPreparation.plan(st, run_def, catalog).filter(func(r: Dictionary) -> bool: return r.night == 12)
		check(rows.any(func(r: Dictionary) -> bool: return r.customer_id == "fd_chen"), "Chen preserved rep%d" % reputation)
	# Belonging cannot be inferred from appearance alone.
	s = load_stage("before-fd_truth"); st = s._day.state
	for f in ["fd_ticket_read", "fd_receipt_read", "fd_mark_read", "fd_customer_ticket_read"]:
		st.narrative_flags.erase(f)
		check(not s.event_command("fd_truth", "tell").ok, "missing evidence " + f)
		st.narrative_flags.append(f)
	# Historical content still carries the independent 180 quote.
	for path in ["res://data/first_debt_manifest.json", "res://data/first_debt_reckoning_manifest.json"]:
		var c := JsonContentProvider.new(path).load_catalog().catalog
		check((c.get_definition("events", "fd_dragon") as EventDefinition).choices[0].label.contains("180"), "legacy price remains180")
	print("DRAGON EDGES: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
