extends "res://tests/dragon_routes.gd"
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._initial_cash = 2000
	driver.check = check; driver.catalog = catalog
	var store := GhostReplayStore.new(); store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var s := RunSession.new(run_def, 31, store, catalog)
	s.replaying = true # Record legal actions without the live per-action snapshot overhead.
	var start := Time.get_ticks_msec()
	for n in range(1, 101):
		calm(s); act(s, "open_shop"); calm(s)
		check(s._day.state.visits.size() == 6, "six visitors on night%d" % n)
		for step in 130:
			if s._day.state.game_minutes >= 480: break
			var v := s._counter.customers.active(s._day.state)
			if v != null: check(s.counter_command("reject", v.visit_id).ok, "refuse")
			else: act(s, "short_task")
			calm(s)
		act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night"); calm(s)
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		calm(s); act(s, "enter_room"); calm(s)
		act(s, "sleep"); calm(s); act(s, "finish_sleep")
		if n < 100: act(s, "continue_run")
		if failures: break
	print("GENERATED100_MS=", Time.get_ticks_msec() - start, " ACTIONS=", s._day.state.action_journal.size())
	check(s._day.state.action_journal.size() > 4096, "more than4096")
	check(s._day.state.fee_history.size() == 100 and s._day.state.fee_history.all(func(r: Dictionary) -> bool: return r.interest == 5 and r.overhead == 5), "100 normal daily fees, no night21 principal")
	InvestigationSaveCodec.clear_cache()
	start = Time.get_ticks_msec(); verify(s, "100 nights cold")
	print("COLD_REPLAY100_MS=", Time.get_ticks_msec() - start)
	s.replaying = false
	check(s.execute("finish_trial").ok, "voluntary ending")
	check(s._day.state.phase == &"run_ended" and not s.can_execute("continue_run"), "trial remains ended")
	verify(s, "ended100")
	print("DRAGON LONG: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
