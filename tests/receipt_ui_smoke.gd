extends "res://tests/m6_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "feedback_1600" if "wide" in OS.get_cmdline_user_args() else "feedback_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	await _boot("res://data/legacy/content_v9.json")
	var helper := RoomTests.new()
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	_session._day.state.run_seed = helper.seed_for("n1_visit1", "repaired")
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var receipt := screen._receipt
	var feedback := screen._feedback
	var messages: Array = []
	var operations: Array = []
	_session.transaction_completed.connect(func(model: Dictionary) -> void: messages.append(model))
	_session.operation_completed.connect(func(model: Dictionary) -> void: operations.append(model))
	var id: String = _session.counter_model().active_id
	_session.counter_command("appraise", id, "light")
	_session.counter_command("pressure", id, "repair")
	await _click("交易")
	var trade := _find_trade(_main)
	trade._price.value = 1
	await _click("正式报价并收购")
	_check(not feedback.visible and not receipt.visible and messages.is_empty() and _session.read_state().cash == 100, "拒价不盖章也不扣款")
	trade._price.value = 23
	await _click("正式报价并收购")
	_check(not feedback.visible and not receipt.visible and feedback.record.kind == "acquisition", "普通收购无闪现弹窗")
	_check(screen._counter_view._active_id != id and not screen._counter_view.feedback_held, "成交后立即恢复接待")
	_check(messages.size() == 1 and feedback.record.before == 100 and feedback.record.after == 77, "演出使用真实入账结果")
	_check(screen._status_view.get_node("%CashStatus").text.contains("77"), "状态栏立即显示真实现金")
	_check(not str(operations).contains("reserve_price") and not str(operations).contains("selected_variant") and not str(operations).contains("true_value"), "操作快照不泄露底价或隐藏品相")
	var before := _session.read_state()
	await _raw_click(screen._counter_view.get_hotspot(&"customer"))
	_check(not screen._counter_view._customer_context.visible and before == _session.read_state(), "快速点击不穿透、不重复成交")
	_session.counter_command("offer", id, "", 23)
	_check(not feedback.visible and messages.size() == 1 and before == _session.read_state(), "无效重复报价不再记账")
	await create_timer(0.50).timeout
	_check(screen._recent.before == 100 and screen._recent.after == 77, "结果保留真实现金快照")
	_check(screen._status_view.get_node("%CashStatus").text.contains("77"), "等待后状态栏仍与真实现金一致")
	await _capture("01_purchase_feedback")
	await create_timer(0.27).timeout
	_check(not feedback.visible and not receipt.visible and before == _session.read_state(), "无延迟弹窗，不另计时间行动")
	_check(screen._recent_bar.visible, "结束后保留可收起的小条目")
	await _click_button(screen._recent_button)
	_check(receipt.visible and receipt._cash.text.contains("100 → 77"), "主动点击最近条目复查凭据")
	await create_timer(0.2).timeout
	await _capture("02_purchase_review")
	await _click_button(receipt._secondary)
	_check(not receipt.visible and before == _session.read_state() and screen._flow.get_active_panel_id() == &"inventory", "复查后查看库存只导航")
	var sale_label := ""
	for row in _session.counter_model().inventory.buttons:
		if row.detail == "buyer_recycler": sale_label = row.label
	await _click(sale_label)
	_check(not feedback.visible and feedback.record.kind == "sale" and screen._recent_bar.visible, "单件出售直接保留记录")
	await _settle_feedback()
	await _click_button(screen._recent_button)
	_check(receipt.visible and receipt._detail.text.contains("已实现盈亏"), "出售凭据显示已实现盈亏")
	await _click_button(receipt._primary)
	_session.new_run()
	helper.open(_session)
	await _click("交易")
	trade._pawn_price.value = 30
	await _click("正式报价并活当")
	_check(not feedback.visible and feedback.record.kind == "pawn_loan" and feedback.record.due_night > 0, "活当记录明确到期夜次")
	await create_timer(0.50).timeout
	_check(screen._recent_button.text.contains("留铺保管") and screen._recent_button.text.contains("到期"), "活当回复下方显示真实条款")
	await _capture("03_pawn_feedback")
	await _settle_feedback()
	await _click_button(screen._recent_button)
	_check(receipt._detail.text.contains("赎金") and receipt._note.text.contains("在当"), "活当复查保留赎金与权属")
	await _click_button(receipt._secondary)
	_check((_main.find_child("LedgerPanel", true, false) as LedgerPanel)._selected == 2, "查看当票直接打开当票页")
	_session.new_run()
	helper.open(_session)
	_session.counter_command("offer", _session.counter_model().active_id, "", 72)
	_check(screen._recent_bar.visible, "取消测试先建立真实成交记录")
	_session.new_run()
	await create_timer(0.85).timeout
	_check(not feedback.visible and not receipt.visible and screen._recent.is_empty() and not screen._counter_view.feedback_held, "新局取消旧演出与回调")
	helper.third(_session)
	await _settle_feedback()
	_check(_session.risk_model().held_ids.size() == 1 and screen._flow.get_active_panel_id() == &"risk" and screen.get_node("%Drawer").visible, "铜镜成交后继续显示必要规矩")
	_check(not screen._recent_bar.visible, "交易条目不遮挡必要危机")
	await _capture("04_mirror_followup")
	await _batch_history()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("RECEIPT UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
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
	var original: Dictionary = screen._feedback.record.duplicate(true)
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
