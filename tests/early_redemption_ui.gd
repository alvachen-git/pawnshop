extends "res://tests/familiar_ui_smoke.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(1))
	_capture_prefix = "early_1600" if "wide" in OS.get_cmdline_user_args() else "early_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	for decision in ["early_redeem", "defer_redeem"]:
		_main = load("res://scenes/start.tscn").instantiate()
		_main.get_node("Bootstrap").save_path = "res://.godot/qa/early/ui_auto.json"
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		_session._save.library.path = "user://tests/early_ui/%d.json" % Time.get_ticks_usec()
		_main.title_menu.configure(true, false)
		driver.check = _check; driver.catalog = _session._counter.catalog
		await _frames(); await _click_button(_main.title_menu.buttons[0])
		var plan := FamiliarStories.plan(_session.definition, driver.catalog, 508)
		var story := FamiliarStories.story_for({"familiar_plan": plan}, "seamstress")
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/early/allow_%d_pre_open.json" % story.follow_night))
		var codec := SaveCodec.new()
		var state := codec.decode(data, _session.definition, 18, driver.catalog, true)
		_check(state != null, "real pre-return fixture")
		var lib := _session._save.library
		_check(lib.write_entry("manual/1", state, _session.definition, 18, driver.catalog), "manual save")
		_check(lib.adopt(lib.read_entry("manual/1"), _session), "load through shared manager")
		driver.drain(_session); driver.action(_session, "open_shop"); driver.drain(_session)
		var current: CustomerVisit
		for step in 160:
			current = _session._counter.customers.active(_session._day.state)
			if EarlyRedemption.is_visit(current): break
			if current != null: _session.counter_command("reject", current.visit_id)
			else: driver.action(_session, "short_task")
			driver.drain(_session)
		_check(EarlyRedemption.is_visit(current), "funded guest brings original ticket")
		await receipts()
		await _click_button(_main.get_node("CounterScreen/CounterView").get_hotspot(&"customer"))
		await _click("商议提前取赎")
		var panel := _find_trade(_main)
		_check(not panel._price.is_visible_in_tree() and not panel._pawn_price.is_visible_in_tree(), "no sale or loan form")
		await _capture(decision + "_request")
		await _click("验票收赎，交还银簪 · 10分钟" if decision == "early_redeem" else "仍按票上的日子来 · 不耗时")
		await _frames(); await _capture(decision + "_result")
		var ticket := EarlyRedemption.ticket_for(_session._day.state)
		_check(ticket.status == ("redeemed" if decision == "early_redeem" else "active"), "matching result")
		await receipts()
		_main.queue_free(); await process_frame
	print("EARLY UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
