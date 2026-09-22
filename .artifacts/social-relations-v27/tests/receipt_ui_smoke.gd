extends "res://tests/m6_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "receipt_1600" if "wide" in OS.get_cmdline_user_args() else "receipt_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v9.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	var helper := RoomTests.new()
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	_session._day.state.run_seed = helper.seed_for("n1_visit1", "repaired")
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	var messages: Array = []
	_session.transaction_completed.connect(func(model: Dictionary) -> void: messages.append(model))
	var id: String = _session.counter_model().active_id
	_session.counter_command("appraise", id, "light")
	_session.counter_command("pressure", id, "repair")
	await _click("交易")
	var trade := _find_trade(_main)
	trade._price.value = 1
	await _click("正式报价并收购")
	_check(not receipt.visible and messages.is_empty() and _session.read_state().cash == 100, "拒价不是成功，不弹凭据、不扣款")
	trade._price.value = 23
	await _click("正式报价并收购")
	_check(receipt.visible and receipt._title.text == "收购成交", "真实收购显示独立成功页")
	_check(receipt._item.text == "青花小碗" and receipt._amount.text.contains("23") and receipt._cash.text.contains("100 → 77"), "凭据显示本笔货物与实际现金变化")
	_check(not _main.get_node("CounterScreen/%Drawer").visible, "成功页不叠着空交易表单")
	_check(messages.size() == 1 and not str(messages[0]).contains("true_value") and not str(messages[0]).contains("selected_variant"), "凭据不暴露真值与隐藏品相")
	var before := _session.read_state()
	await create_timer(0.25).timeout
	_check(_session.read_state() == before and receipt.visible, "凭据不自动消失，也不推进时间")
	await _capture("01_purchase")
	_check(receipt._paper.get_global_rect().encloses(receipt._primary.get_global_rect()) and receipt._paper.get_global_rect().encloses(receipt._cash.get_global_rect()), "关键金额与按钮在纸页内")
	_check(_main.get_node("CounterScreen").get_global_rect().encloses(receipt._paper.get_global_rect()), "成功页未越出视口")
	_session.counter_command("offer", id, "", 23)
	_check(messages.size() == 1 and before == _session.read_state(), "重复旧报价不扣款或再发凭据")
	await _click_button(receipt._secondary)
	_check(not receipt.visible and _session.read_state() == before, "查看库存只导航，不重复交易")
	_check(_main.get_node("CounterScreen/ScreenFlowCoordinator").get_active_panel_id() == &"inventory", "成交页直达库存")
	var sale_label := ""
	for row in _session.counter_model().inventory.buttons:
		if row.detail == "buyer_recycler": sale_label = row.label
	await _click(sale_label)
	_check(receipt.visible and receipt._title.text == "出售成交" and receipt._amount.text.begins_with("实收"), "真实出售显示收款凭据")
	_check(receipt._detail.text.contains("已实现盈亏"), "出售才展示真实实现盈亏")
	await create_timer(0.2).timeout
	await _capture("02_sale")
	before = _session.read_state()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(not receipt.visible and _session.read_state() == before, "Esc收好凭据不改变钱货")
	_session.new_run()
	helper.open(_session)
	await _click("交易")
	trade._pawn_price.value = 30
	await _click("正式报价并活当")
	_check(receipt.visible and receipt._title.text == "活当办妥", "活当有独立放款凭据")
	_check(receipt._detail.text.contains("到期") and receipt._detail.text.contains("赎金") and receipt._note.text.contains("在当"), "活当说清去向、期限和赎金")
	await create_timer(0.2).timeout
	await _capture("03_pawn")
	before = _session.read_state()
	await _click_button(receipt._secondary)
	_check(_main.find_child("LedgerPanel", true, false)._selected == 2 and _session.read_state() == before, "查看当票直接打开当票页并且免费")
	# A receipt must not cover a required mirror warning after it is dismissed.
	_session.new_run()
	helper.third(_session)
	await _frames()
	_check(receipt.visible and receipt._item.text == "泣血铜镜", "铜镜收购仍先反馈交易")
	await _click_button(receipt._primary)
	# The direct multi-night helper also left known customers at closing.
	# Acknowledge those notices; their dismissal must restore the risk panel.
	var departure := _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	for guard in 10:
		if not departure.visible: break
		await _click_button(departure._primary)
	_check(not receipt.visible and _session.risk_model().held_ids.size() == 1, "确认铜镜凭据不修改风险持有状态")
	_check(_main.get_node("CounterScreen/ScreenFlowCoordinator").get_active_panel_id() == &"risk" and _main.get_node("CounterScreen/%Drawer").visible, "铜镜成交反馈后继续显示存放规矩")
	_session.new_run()
	_check(not receipt.visible, "新局不残留旧凭据")
	await _batch_history()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("RECEIPT UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _boot(manifest: String) -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = manifest
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()

func _raw_click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		root.push_input(event, true)
	await _frames()

func _batch_history() -> void:
	_main.free()
	await _boot("res://data/content_manifest.json")
	var helper := MarketTests.new()
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	helper.open(_session)
	# Inventory-only fixture; real commands generate both batches and ledgers.
	_session._day.state.visits.clear()
	_session._day.state.game_minutes = 70
	var a := helper.stock(_session)
	var b := helper.stock(_session)
	for item in [a, b]: item.provenance = {"truth": "none", "status": "unchecked", "investigated": false, "evidence": []}
	_session.changed.emit()
	_check(_session.sell_batch("buyer_recycler", [a.instance_id, b.instance_id]).ok, "首批真实卖给杂货回收商")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var original: Dictionary = screen._recent.duplicate(true)
	_check(original.item.contains("交货2件"), "批量出售只展示一次汇总")
	await _settle_feedback()
	var c := helper.stock(_session)
	c.provenance = {"truth": "none", "status": "unchecked", "investigated": false, "evidence": []}
	_session._day.state.visits.clear()
	_session.changed.emit()
	_check(_session.sell_batch("buyer_collector", [c.instance_id]).ok, "后批真实卖给不同买家")
	await _settle_feedback()
	_check(_session.receipt_for(original.id) == original, "后续买家和流水不能污染原批次凭据")
	var before := _session.read_state()
	await _click("账本")
	var ledger := _main.find_child("LedgerPanel", true, false) as LedgerPanel
	await _click("流水")
	var found: Button
	for button in ledger.find_children("*", "Button", true, false):
		if button.get_meta("receipt_id", "") == original.id: found = button; break
	_check(found != null, "账本提供原批次实际复查入口")
	if found != null: await _click_button(found)
	_check(screen._receipt.visible and screen._receipt._item.text.contains("杂货回收商") and screen._receipt._cash.text.contains("%d → %d" % [original.before, original.after]), "从账本复查原批次买家和现金快照")
	_check(screen.get_global_rect().encloses(screen._receipt._paper.get_global_rect()), "复查纸页完整适配视口")
	await create_timer(0.2).timeout
	await _capture("05_batch_history")
	await _click_button(screen._receipt._primary)
	_check(before == _session.read_state() and screen._flow.get_active_panel_id() == &"ledger", "收好旧凭据返回账本，不推进时间或重放资金")
	_session.changed.emit()
	await _frames()
	_check(not screen._feedback.visible, "重复刷新不重播交易")
