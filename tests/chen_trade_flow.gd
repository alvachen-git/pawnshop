extends "res://tests/reckoning_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	for route in ["buy", "reject", "failed"]:
		var s := chen_start()
		var v := s._counter.customers.active(s._day.state)
		check(v.customer_id == "fd_chen", "normal Chen seat")
		# Deliberately make the last event a read of the ticket, reproducing the report.
		if FirstDebt.last(s._day.state, "fd_ticket").is_empty(): check(s.observe_document("fd_ticket").ok, "read ticket during visit")
		var model := s.counter_model()
		check(not model.get("first_debt_relic", false) and not model.get("itemless", false), "one ordinary item during trade")
		check(not model.dialogue.get("preserve_ticket_body", false), "ordinary dialogue uses customer presentation")
		check(model.get("case_dialogue", {}).is_empty(), "no story during trade")
		check(not s.event_command("fd_chen_recognize", "ask").ok, "live pre-trade recognition rejected")
		if route == "buy": check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "normal buy")
		elif route == "reject": check(s.counter_command("reject", v.visit_id).ok, "normal reject")
		else:
			for i in 3:
				if s._counter.customers.active(s._day.state) != v: break
				check(s.counter_command("offer", v.visit_id, "", 1).ok, "normal low quote")
		model = s.counter_model()
		check(model.get("case_dialogue", {}).get("auto_open", false), "post-trade recognition " + route)
		check(not model.get("first_debt_relic", false) and model.get("itemless", false), "no bracelet on counter during recognition")
		check("当铺柜子里的凤镯" in model.case_dialogue.text and not "取出" in model.case_dialogue.text, "recognizes bracelet inside cabinet")
		check(not "瑞字四十七" in model.case_dialogue.text, "no stale ticket in story")
		verify(s, "before recognition " + route)
		var lib := SaveLibrary.new("res://.godot/qa/v29/chen-" + route + ".json")
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/first_debt_reckoning", s._day.state, run_def, 29, catalog), "pre-story disk")
		var before := s.read_state(); lib.fail_write = true
		check(not s.event_command("fd_chen_recognize", "ask").ok and s.read_state() == before, "choice rollback " + route)
		lib.fail_write = false
		check(s.event_command("fd_chen_recognize", "ask").ok, "recognition retry " + route)
		check(s._day.state.game_minutes == before.game_minutes + 5, "only request costs five minutes")
		before = s.read_state()
		check(not s.event_command("fd_chen_recognize", "ask").ok and s.read_state() == before, "no duplicate choice")
		check(s.counter_model().get("case_dialogue", {}).is_empty(), "recognition actor gone after choice " + route)
		verify(s, "recognition " + route)
		var f := FileAccess.open("res://.godot/qa/v29/chen-complete-" + route + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))
	var s := chen_start()
	var v := s._counter.customers.active(s._day.state)
	# The formerly valid pre-trade choice stays replayable, but isn't offered live.
	s.replaying = true
	check(s.event_command("fd_chen_recognize", "ask").ok, "historical v29 command")
	s.replaying = false
	verify(s, "legacy pre-trade save")
	s = chen_start()
	FirstDebt.owned(s._day.state, FirstDebt.PHOENIX).ownership_state = "sold"
	check(s.counter_command("reject", s._counter.customers.active(s._day.state).visit_id).ok, "trade without phoenix")
	check(s.counter_model().get("case_dialogue", {}).is_empty(), "no imaginary bracelet")
	s = chen_start()
	check(s.counter_command("reject", s._counter.customers.active(s._day.state).visit_id).ok, "reject before defer")
	check(s.event_command("fd_chen_recognize", "later").ok, "defer recognition")
	check(not FirstDebt.flag(s._day.state, "fd_chen_requested"), "no phantom invitation")
	check(s.counter_model().get("case_dialogue", {}).is_empty(), "deferred recognition actor gone")
	verify(s, "deferred")
	var deferred_file := FileAccess.open("res://.godot/qa/v29/chen-complete-later.json", FileAccess.WRITE)
	deferred_file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))
	check(FirstDebtConversation.speaker_for(["你把账簿推过去。", "“七夜还没到。”"], 1) == "掌柜", "player speech attribution")
	check(FirstDebtConversation.speaker_for(["陈小满看看凤尾。", "“祖父说过这道旧补。”"], 1) == "陈小满", "Chen speech attribution")
	print("CHEN TRADE FLOW: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func chen_start() -> RunSession:
	var s := load_stage("seller")
	var seller := s._counter.customers.active(s._day.state)
	check(s.counter_command("offer", seller.visit_id, "", 100).ok, "buy from ordinary seller")
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	driver.drain(s); act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s)
	act(s, "finish_sleep"); act(s, "continue_run"); driver.drain(s); act(s, "open_shop"); driver.drain(s)
	for i in 25:
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			if v.customer_id == "fd_chen": break
			check(s.counter_command("reject", v.visit_id).ok, "earlier customer")
		else: check(s.bell_command("wait").ok, "wait for Chen")
	var file := FileAccess.open("res://.godot/qa/v29/chen-uncontacted.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))
	return s
