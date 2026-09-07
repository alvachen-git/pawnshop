extends "res://tests/m6_ui_smoke.gd"
func _run() -> void:
	_capture_prefix = "waiting_1600" if "wide" in OS.get_cmdline_user_args() else "waiting_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/seven_night.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	_session.new_run()
	var driver := SevenTestDriver.new()
	driver.check = _check
	driver.open(_session)
	var first := _session._counter.customers.active(_session._day.state)
	_session.counter_command("reject", first.visit_id)
	driver.finish(_session)
	driver.open(_session)
	for i in 21: driver.action(_session, "short_task")
	var current := _session._counter.customers.active(_session._day.state)
	_check(current.person.name == "周绍安" and current.expires_at == 175, "seed42 actual customer and deadline match screenshot")
	var waiting: CustomerVisit = _session._day.state.visits[1]
	_check(waiting.person.name == "沈文清" and waiting.status == "waiting" and waiting.expires_at == 135, "actual waiting hawker leaves earlier")
	await _click("交易")
	for i in 6: driver.action(_session, "short_task")
	await _frames()
	var page := _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	_check(page.visible and page._title.text == "等候客人离场", "waiting expiry is not a failed negotiation")
	_check(page._item.text.contains("沈文清") and not page._item.text.contains("周绍安"), "notice identifies the departed visitor")
	_check(page._note.text.contains("还没轮到柜台") and page._detail.text.contains("柜台仍在接待：周绍安"), "queue role and ongoing customer explicit")
	_check(page._primary.text == "继续当前接待", "button does not imply a different customer")
	_check(current.status == "active" and waiting.status == "timed_out", "current negotiation never ended")
	_check(_session.counter_model().queue.contains("沈文清") and _session.counter_model().queue.contains("20:15"), "counter result has departed visitor and time")
	_check(not _session.counter_model().queue.contains("周绍安"), "does not attribute departure to current visitor")
	await create_timer(0.25).timeout
	await _capture("01_waiting_notice")
	var before := _session.read_state()
	await _click_button(page._primary)
	_check(before == _session.read_state() and _session.counter_model().active_id == current.visit_id, "dismissal preserves original reception and game time")
	_check(_main.get_node("CounterScreen/ScreenFlowCoordinator").get_active_panel_id() == &"trade" and _main.get_node("CounterScreen/%Drawer").visible, "waiting notice returns to ongoing trade panel")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	await _capture("02_current_continues")
	# Cause the actual current customer to exhaust negotiation rounds through legal quotes.
	# Rejection below the asking price may consume patience first; either is a departure.
	for guard in 3:
		if current.status != "active": break
		_session.counter_command("offer", current.visit_id, "", 1)
	await _frames()
	_check(page.visible and page._title.text == "未能成交" and page._item.text.contains("周绍安"), "real current failure identifies Zhou")
	_check(current.status in ["patience_exhausted", "rounds_exhausted"], "current visitor really leaves after failed negotiation")
	await _click_button(page._primary)
	_check(_session.counter_model().active_id != current.visit_id, "departed customer cannot reappear on dismissal")
	var view := _main.get_node("CounterScreen/CounterView") as CounterView
	_check(not view.get_hotspot(&"customer").visible, "empty counter after actual departure")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("WAITING DEPARTURE UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
