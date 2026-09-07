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
	var page := _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	_check(page.visible and page._note.text.contains("耐心耗尽"), "patience loss has explicit feedback")
	_check(not page._amount.visible and not page._cash.visible and not page._secondary.visible, "no false transaction/payment controls")
	_check(root.gui_get_focus_owner() == page._primary, "focus goes to acknowledgment")
	_check(page._paper.get_global_rect().end.y <= root.size.y and page._paper.global_position.y >= 0, "paper fits viewport")
	var before := _session.read_state()
	await create_timer(0.3).timeout
	_check(before == _session.read_state(), "reading consumes no game time")
	await _capture("01_patience")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	await _frames()
	_check(not page.visible and before == _session.read_state(), "escape dismisses without mutation")
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
	_check(page.visible and page._note.text.contains("议价轮次"), "rounds loss feedback")
	await _click_button(page._primary)
	helper.wait_to(_session, 360)
	await _frames()
	if page.visible: await _click_button(page._primary)
	v = helper.active(_session)
	helper.wait_to(_session, v.expires_at)
	await _frames()
	_check(page.visible and page._note.text.contains("等候期限"), "timeout feedback")
	await create_timer(0.25).timeout
	await _capture("02_timeout")
	await _click_button(page._primary)
	_check(not page.visible, "mouse acknowledgment works")
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
	_check(receipt.visible and not page.visible, "successful receipt has priority over waiting timeout")
	before = _session.read_state()
	await _click_button(receipt._primary)
	_check(page.visible and page._note.text.contains("等候期限"), "waiting departure follows receipt")
	await _click_button(page._primary)
	_check(before == _session.read_state(), "both acknowledgments leave cash and history unchanged")
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
	page = _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	_check(page.visible and page._note.text.contains("议价轮次"), "seven-night scene shows departures")
	await create_timer(0.25).timeout
	await _capture("03_seven")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("DEPARTURE UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
