extends "res://tests/m6_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "seven_1600" if "wide" in OS.get_cmdline_user_args() else "seven_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/seven_night.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "seven scene launches")
	if _session == null: quit(1); return
	var driver := SevenTestDriver.new()
	driver.check = _check
	await _frames()
	await _capture("01_opening")
	await _click("开铺")
	var v := _session._counter.customers.active(_session._day.state)
	await _click("对话")
	_check(_session.counter_model().dialogue.body.contains(v.voice.introduction), "situation shown in dialogue")
	await _capture("02_situation")
	await _click("交易")
	_find_trade(_main)._price.value = v.trade.asking_price
	await _click("正式报价并收购")
	await _capture("03_receipt")
	await _click("收好凭据")
	driver.finish(_session)
	for n in 2: driver.open(_session); driver.finish(_session)
	await _click("营业")
	var panel := _main.find_child("DayFlowPanel", true, false) as DayFlowPanel
	await _scroll_to(panel._buttons.prep_investigate)
	await _capture("04_preparation")
	await _click("调查收货消息 · 准备1次")
	_check(panel._description.text.contains("剩余1次"), "preparation count refresh")
	await _click("打听今晚来客 · 准备1次")
	_check(panel._buttons.prep_contact.disabled, "third preparation disabled")
	await _click("查看已知消息 · 不耗次数")
	await _capture("05_known_news")
	await _click("营业")
	await _click("结束准备")
	await _click("开铺")
	driver.work(_session); driver.finish(_session)
	await _click("营业")
	await _click("联系收货人 · 准备1次")
	await _click("结束准备")
	await _click("开铺")
	driver.work(_session); driver.finish(_session)
	driver.open(_session)
	for guard in 40:
		var active := _session._counter.customers.active(_session._day.state)
		if active != null: _session.counter_command("reject", active.visit_id)
		elif _session._day.state.game_minutes >= 60: break
		else: driver.action(_session, "short_task")
	await _click("库存")
	await _click("卖货")
	await _click("选择买家 · 外埠文房收货人")
	await _click("选中全部可售货物")
	var inventory := _main.find_child("InventoryPanel", true, false) as InventoryPanel
	await _scroll_to(inventory._sale_view._submit)
	_check(inventory._sale_view._selected.size() >= 2 and not inventory._sale_view._submit.disabled, "two eligible pens selected")
	await _capture("06_appointment")
	await _click("完成交易 · 20分钟")
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	_check(receipt.visible and receipt._item.text.contains("交货"), "batch success page")
	await _capture("07_batch_receipt")
	await _click("收好凭据")
	driver.finish(_session)
	driver.open(_session)
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]: driver.action(_session, action)
	await _frames()
	await _capture("08_room")
	driver.action(_session, "sleep"); driver.action(_session, "finish_sleep")
	await _click("夜间结算")
	await _capture("08_seventh_summary")
	_check(_session._day.state.current_night_index == 7, "seventh night summary reached")
	print("SEVEN UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _scroll_to(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await _frames()
