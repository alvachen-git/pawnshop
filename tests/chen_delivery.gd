extends "res://tests/reckoning_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var s := load_stage("before-fd_family")
	check("原当票" in s.counter_model().visual.introduction and not "旧纸" in s.counter_model().visual.introduction, "arrival names original ticket")
	var lib := SaveLibrary.new("res://.godot/qa/v29/chen-delivery.json")
	var store := SaveManager.new(); store.catalog = catalog; store.library = lib; s._save = store
	check(lib.write_entry("auto/first_debt_reckoning", s._day.state, run_def, 29, catalog), "initial delivery save")
	var before := s.read_state(); lib.fail_write = true
	check(not s.event_command("fd_family", "read").ok and s.read_state() == before, "delivery rollback retains visitor")
	check(s.counter_model().visual.customer_id == "fd_chen", "still present after failed save")
	lib.fail_write = false
	check(s.event_command("fd_family", "read").ok, "delivery retry")
	check(s._day.state.game_minutes == before.game_minutes + 5, "only existing five minutes")
	check(not FirstDebt.chen_waiting(s._day.state) and s.counter_model().get("case_dialogue", {}).is_empty(), "delivery ends visit")
	before = s.read_state()
	check(not s.event_command("fd_family", "read").ok and s.read_state() == before, "duplicate delivery rejected")
	var restored := lib.read_entry("auto/first_debt_reckoning")
	check(not restored.is_empty() and not FirstDebt.chen_waiting(restored.state), "saved delivery stays departed")
	var file := FileAccess.open("res://.godot/qa/v29/chen-delivered.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))
	check(s.old_shop_model().documents.any(func(d: Dictionary) -> bool: return d.id == "fd_customer_ticket" and not d.read), "ticket copy available without prior reading")
	check(s.observe_document("fd_customer_ticket").ok, "can investigate after she leaves")
	check(s.counter_model().get("case_dialogue", {}).is_empty(), "reading cannot respawn Chen")
	check(not s.event_command("fd_truth", "tell").ok, "cannot talk to departed visitor")
	# Old v29 transcripts could proceed on the delivery day; they still replay.
	s.replaying = true
	check(s.event_command("fd_truth", "tell").ok, "legacy same-day discussion retained")
	s.replaying = false
	verify(s, "legacy same-day evidence")
	# Resume the actual new delivery checkpoint and progress through a real night.
	s._day.state = restored.state
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	driver.drain(s); act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s)
	act(s, "finish_sleep"); act(s, "continue_run"); driver.drain(s); act(s, "open_shop"); driver.drain(s)
	check(FirstDebt.chen_waiting(s._day.state), "returns next night")
	for i in 20:
		var visitor := s._counter.customers.active(s._day.state)
		if visitor == null: break
		check(s.counter_command("reject", visitor.visit_id).ok, "ordinary guests retain priority")
	check(s.observe_document("fd_customer_ticket").ok, "read original for resumed discussion")
	check(s.event_command("fd_truth", "tell").ok, "investigation continues next night")
	verify(s, "resumed after delivery")
	print("CHEN DELIVERY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
