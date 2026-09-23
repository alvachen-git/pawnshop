extends "res://tests/reckoning_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	for route in ["buy", "reject", "failed", "reject_later"]:
		var s := load_stage("chen-uncontacted")
		var chen := s._counter.customers.active(s._day.state)
		# Real timed actions, no forged queue/time. By 19:20 another guest waits.
		while s._day.state.game_minutes < 80: check(s.execute("short_task").ok, "time before trade")
		check(s._day.state.visits.any(func(v: CustomerVisit) -> bool: return v.status == "waiting"), "queued guest reproduces bug")
		var queue := s._day.state.visits.map(func(v: CustomerVisit) -> String: return v.visit_id)
		if route == "buy": check(s.counter_command("offer", chen.visit_id, "", chen.trade.asking_price).ok, "buy")
		elif route.begins_with("reject"): check(s.counter_command("reject", chen.visit_id).ok, "reject")
		else:
			for i in 3: check(s.counter_command("offer", chen.visit_id, "", 1).ok, "low quote")
		var next := s._counter.customers.active(s._day.state)
		check(next != null and next.customer_id != "fd_chen", "normal queue retained internally")
		check(s.counter_model().get("case_dialogue", {}).get("auto_open", false), "Chen immediately continues " + route)
		check(s.counter_model().visual.customer_id == "fd_chen", "no intermediate new portrait " + route)
		check(not s.bell_model().enabled, "bell cannot dismiss hidden next guest")
		var before := s.read_state()
		check(not s.counter_command("reject", next.visit_id).ok and s.read_state() == before, "hidden guest cannot be traded")
		verify(s, "handoff checkpoint " + route)
		var file := FileAccess.open("res://.godot/qa/v29/chen-handoff-" + route + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))
		var choice := "later" if route == "reject_later" else "ask"
		var library := SaveLibrary.new("res://.godot/qa/v29/handoff-durable-" + route + ".json")
		var store := SaveManager.new(); store.library = library; store.catalog = catalog; s._save = store
		check(library.write_entry("auto/first_debt_reckoning", s._day.state, run_def, 29, catalog), "handoff disk save")
		before = s.read_state(); library.fail_write = true
		check(not s.event_command("fd_chen_recognize", choice).ok and s.read_state() == before, "failed save retains Chen and next guest")
		library.fail_write = false
		check(s.event_command("fd_chen_recognize", choice).ok, "recognition before new customer " + route)
		check(s._counter.customers.active(s._day.state).visit_id == next.visit_id, "same guest resumes")
		check(s._day.state.visits.map(func(v: CustomerVisit) -> String: return v.visit_id) == queue, "no deleted or extra visits")
		check(s.counter_command("reject", next.visit_id).ok, "next guest can leave after story")
		check(not s.counter_model().get("case_dialogue", {}).get("auto_open", false), "Chen does not reappear after next guest")
		verify(s, "resolved handoff " + route)
	# Historical saves produced by the previous bug must still replay exactly.
	var legacy := load_stage("chen-uncontacted")
	legacy.replaying = true
	while legacy._day.state.game_minutes < 80: legacy.execute("short_task")
	legacy.counter_command("reject", legacy._counter.customers.active(legacy._day.state).visit_id)
	legacy.counter_command("reject", legacy._counter.customers.active(legacy._day.state).visit_id)
	check(legacy.event_command("fd_chen_recognize", "ask").ok, "old delayed recognition accepted only in replay")
	legacy.replaying = false
	verify(legacy, "old delayed recognition")
	print("CHEN HANDOFF: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
