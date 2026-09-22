extends "res://tests/bargaining_ui_smoke.gd"
func _run() -> void:
	_capture_prefix = "departure_1600" if "wide" in OS.get_cmdline_user_args() else "departure_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v9.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	var helper := BargainingTests.new()
	helper.setup(_check)
	helper.open(_session)
	var v := helper.active(_session)
	# Controlled patience boundary; the action itself is a real mouse click.
	v.customer_id = "customer_scholar"
	v.trade.patience = 2
	_session.changed.emit()
	await _click("交易")
	await _click_button(_command_button("belittle", ""))
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var page := screen._feedback
	_check(not page.visible and screen._recent_bar.visible and page.record.note.contains("耐心耗尽"), "patience loss has persistent feedback")
	_check(page.record.kind == "departure" and page.record.amount == 0 and not screen._receipt.visible, "no false transaction/payment controls")
	_check(screen.get_global_rect().encloses(screen._recent_bar.get_global_rect()), "reply fits viewport")
	var before := _session.read_state()
	await create_timer(0.3).timeout
	_check(before == _session.read_state(), "reading consumes no game time")
	await _capture("01_patience")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	await _frames()
	_check(not page.visible and screen._recent_bar.visible and before == _session.read_state(), "escape needs no result acknowledgment")
	await _settle_feedback()
	_check(not page.visible and before == _session.read_state(), "departure finishes without acknowledgment or game time")
	_session.changed.emit()
	await _frames()
	_check(not page.visible, "same history never repeats")
	helper.wait_to(_session, 100)
	await _frames()
	v = helper.active(_session)
	v.trade.rounds_left = 1
	v.trade.patience = 10
	_session.changed.emit()
	await _click("交易")
	await _click_button(_command_button("belittle", ""))
	await _frames()
	_check(not page.visible and screen._recent_button.get_meta("reply_style") == "refused", "rounds loss uses refusal reply")
	await _settle_feedback()
	helper.wait_to(_session, 360)
	await _frames()
	await _settle_feedback()
	v = helper.active(_session)
	helper.wait_to(_session, v.expires_at)
	await _frames()
	_check(not page.visible and screen._recent_button.get_meta("reply_style") == "timed_out", "timeout reply")
	await create_timer(0.25).timeout
	await _capture("02_timeout")
	await _settle_feedback()
	_check(not page.visible, "timeout needs no extra acknowledgment")
	# A successful purchase and another waiting customer's expiry in one action:
	# the receipt is shown first, then the departure, with no additional posting.
	_session.new_run()
	helper.open(_session)
	v = helper.active(_session)
	var waiting: CustomerVisit = _session._day.state.visits[1]
	waiting.status = "waiting"
	waiting.expires_at = 5
	_session.changed.emit()
	_session.counter_command("offer", v.visit_id, "", v.trade.asking_price)
	await _frames()
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	_check(not receipt.visible and not page.visible and page.record.kind == "acquisition", "successful reply has priority over waiting timeout")
	before = _session.read_state()
	await _settle_feedback()
	_check(not page.visible and screen._recent.note.contains("等候期限"), "waiting departure becomes a notification after receipt")
	_check(before == _session.read_state(), "feedback leaves cash and history unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	_main.free()
	_main = load("res://scenes/seven_night.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + "_seven.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var driver := SevenTestDriver.new()
	driver.check = _check
	driver.open(_session)
	v = _session._counter.customers.active(_session._day.state)
	v.trade.rounds_left = 1
	v.trade.patience = 10
	_session.changed.emit()
	await _click("交易")
	await _click_button(_command_button("belittle", ""))
	await _frames()
	page = _main.find_child("TradeFeedback", true, false) as TradeFeedbackView
	_check(not page.visible and page.record.note.contains("议价轮次"), "seven-night departures do not flash")
	await create_timer(0.25).timeout
	await _capture("03_seven")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("DEPARTURE UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
