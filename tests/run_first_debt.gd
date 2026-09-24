extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._initial_cash = 2000 # Funded branch fixture; not the shipped economy.
	driver.check = check; driver.catalog = catalog
	var store := GhostReplayStore.new()
	store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var s := RunSession.new(run_def, 28, store, catalog)
	for n in range(1, 20):
		driver.drain(s)
		act(s, "open_shop"); driver.drain(s)
		for step in 100:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.customer_id == "fd_seller":
					fd(s, "fd_receipt", "read"); fd(s, "fd_mark", "read")
					check(s.counter_command("offer", v.visit_id, "", 100).ok, "buy phoenix100")
				elif v.customer_id == "fd_chen" and n == 12:
					fd(s, "fd_chen_recognize", "ask")
					check(s.counter_command("reject", v.visit_id).ok, "chen trade ends")
				else: s.counter_command("reject", v.visit_id)
				driver.drain(s)
			else:
				if n == 11 and FirstDebt.last(s._day.state, "fd_lu").is_empty(): fd(s, "fd_lu", "ask")
				if n == 13 and not FirstDebt.flag(s._day.state, "fd_family_read"):
					fd(s, "fd_family", "read"); fd(s, "fd_ticket", "read")
					fd(s, "fd_dragon", "buy"); fd(s, "fd_truth", "tell"); fd(s, "fd_settle", "return")
					check(FirstDebt.owned(s._day.state, FirstDebt.PHOENIX) == null, "actual return")
					s.counter_model()
					verify(s, "return")
				if not s.bell_model().enabled: break
				s.bell_command("wait")
		if s._day.state.phase == &"open": act(s, "close_shop")
		if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
		act(s, "resolve_night"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		driver.drain(s)
		act(s, "enter_room"); driver.drain(s)
		act(s, "sleep"); driver.drain(s)
		act(s, "finish_sleep")
		if n in [10, 18]: verify(s, "night%d" % n)
		act(s, "continue_run")
		check(s._day.state.current_night_index == n + 1, "continue %d" % n)
		if failures: break
	print("FIRST DEBT: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func act(s: RunSession, cmd: String) -> void:
	var r := s.execute(cmd); check(r.ok, cmd + " " + r.message)

func fd(s: RunSession, id: String, option: String) -> void:
	var r := s.observe_document(id) if id in FirstDebt.DOCUMENTS else s.event_command(id, option)
	check(r.ok, id + " " + r.message)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 28)
	var restored := codec.decode(data, run_def, 28, catalog, true)
	check(restored != null, "replay " + label + " " + codec.error_message)
