extends "res://tests/m6_ui_smoke.gd"

var helper := MarketTests.new()

func _run() -> void:
	_capture_prefix = "market_1600" if "wide" in OS.get_cmdline_user_args() else "market_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	_session._day.state.run_seed = 1
	_session._day.state.ordinary_selections.clear()
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	await _frames()
	await _click("库存")
	await _click("卖货")
	await _click("选择买家 · 杂货回收商")
	var panel := _main.find_child("InventoryPanel", true, false) as InventoryPanel
	_check(panel._sale_view._submit.disabled and panel._sale_view._total.text.contains("店里还有客人"), "店里有客时可以查看，但不能提交")
	await _capture("01_guest_blocked")
	# Make three real purchases, through the existing counter; no inventory injection.
	for minute in [0, 90, 210]:
		helper.wait_to(_session, minute)
		var visit := helper.active(_session)
		await _click("交易")
		var trade := _find_trade(_main)
		trade._price.value = visit.trade.reserve_price
		await _click("正式报价并收购")
	await _click("库存")
	await _click("卖货")
	await _click("选择买家 · 杂货回收商")
	await _click("选中全部可售货物")
	_check(panel._sale_view._selected.size() == 3 and not panel._sale_view._submit.disabled, "真实货物可批量勾选且超过旧额度")
	var total := 0
	for item in _session._day.state.inventory_instances:
		total += _session._commerce.quote(item, helper.catalog.get_definition("buyers", "buyer_recycler"))
	_check(panel._sale_view._total.text.contains("收入%d" % total) and panel._sale_view._total.text.contains("往返20分钟"), "选货显示总收入及往返时间")
	# Position the total and action in the visible drawer before screenshot.
	await _scroll_to(panel._sale_view._submit)
	await _capture("02_batch_selection")
	var before := _session.read_state()
	await _click("完成交易 · 20分钟")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	_check(not screen._feedback.visible and screen._feedback.record.item.contains("交货3件"), "整批保留一次结果，无交货弹窗")
	await _settle_feedback()
	await _click_button(screen._recent_button)
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	_check(receipt.visible and receipt._item.text.contains("交货3件") and receipt._amount.text.contains(str(total)), "一张汇总凭据反馈整批")
	_check(_session.read_state().cash == before.cash + total and _session.read_state().game_minutes == before.game_minutes + 20, "实际批量出售货款耗时正确")
	await create_timer(0.2).timeout
	_check(_main.get_node("CounterScreen").get_global_rect().encloses(receipt._paper.get_global_rect()), "凭据适配视口")
	_check(receipt._paper.get_global_rect().encloses(receipt._primary.get_global_rect()), "凭据确认按钮始终在画面内")
	await _capture("03_batch_receipt")
	await _click("收好凭据")
	await _click("库存")
	await _click("卖货")
	await _click("更换买家")
	await _click("选择买家 · 陆掌眼")
	await _scroll_to(panel._sale_view._submit)
	await _capture("04_lu_demand")
	await _click("取消选货")
	_check(panel._sale_view._selected.is_empty(), "取消清空选货")
	var current_notice: String = _main.get_node("CounterScreen/MarketNotice").text
	var last_change: Dictionary = MarketService.plan(_session.definition, 1)[1]
	if _session._day.state.game_minutes < last_change.minute:
		helper.wait_to(_session, int(last_change.minute))
		_check(_main.get_node("CounterScreen/MarketNotice").text != current_notice, "口信自动更新无需确认")
	await _click("库存")
	await _click("卖货")
	await _click("查看往来口信")
	await _capture("05_market_history")
	_check(helper.finish(_session), "UI操作后的真实存档可写")
	helper.resume(_session, "UI批量出货恢复")
	await _lu_sale_preview()
	print("MARKET UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _lu_sale_preview() -> void:
	_session.new_run()
	_session._day.state.run_seed = 7
	_session._day.state.ordinary_selections.clear()
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	for guard in 100:
		helper.events(_session)
		var visit := helper.active(_session)
		if visit != null:
			var item: ItemDefinition = helper.catalog.get_definition("items", visit.item.definition_id)
			if item.item_type == "normal":
				for step in item.appraisal_actions: helper.action(_session, "appraise", step.id)
				for clue in visit.item.revealed_clue_ids:
					if item.find_clue(clue).leverage > 0 and _session._counter.reason(_session._day, "pressure", visit.visit_id, clue).is_empty(): helper.action(_session, "pressure", clue)
				var offer := _session._counter.appraisal.valuation(visit.item, item).x
				if visit.status == "active" and _session.read_state().cash >= offer: helper.action(_session, "offer", "", offer)
			if visit.status == "active": helper.action(_session, "reject")
		for buyer in _session.counter_model().inventory.sales.buyers:
			if buyer.id != "buyer_lu" or not buyer.reason.is_empty(): continue
			var available: Array = buyer.stock.filter(func(row: Dictionary) -> bool: return row.reason.is_empty())
			if available.is_empty(): continue
			await _frames()
			await _click("库存")
			await _click("卖货")
			await _click("选择买家 · 陆掌眼")
			await _click("选中全部可售货物")
			var panel := _main.find_child("InventoryPanel", true, false) as InventoryPanel
			await _scroll_to(panel._sale_view._submit)
			await _capture("06_lu_quote")
			var before: int = _session.read_state().cash
			await _click("完成交易 · 20分钟")
			_check(_session.read_state().sale_records.back().buyer_id == "buyer_lu" and _session.read_state().cash > before, "陆掌眼真实询价成交")
			await create_timer(0.2).timeout
			await _capture("07_lu_receipt")
			return
		if _session._day.state.game_minutes >= 515: break
		_session.execute("short_task")
	_check(false, "经营样本应出现陆掌眼可售现货")

func _scroll_to(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await _frames()
