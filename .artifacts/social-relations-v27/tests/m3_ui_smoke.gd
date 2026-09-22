extends "res://tests/ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "m3"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m3_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	await _click("开铺")
	await _click("鉴定")
	for label in ["识货：观察器型 · 5分钟", "辨真：放大镜查看底足 · 10分钟", "辨真：侧光检查釉面 · 10分钟"]: await _click(label)
	await _click("交易")
	await _click_trade_intent("pressure", "repair")
	var trade := _find_trade(_main)
	trade._price.value = 18
	await _click("正式报价并收购")
	await _click("库存")
	await _capture("01_buyers")
	var before := _session.read_state()
	await create_timer(0.5).timeout
	_check(_session.read_state() == before, "查看买家与现实等待免费")
	await _sell_first()
	_check(_session.read_state().cash == 94, "UI出售给真实买家，回收12并实现亏损6")
	await _click("交易")
	trade._pawn_price.value = 20
	await _click("正式报价并活当")
	_check(_session.read_state().cash == 74 and _session.read_state().pawn_tickets.size() == 1, "UI活当放款生成当票")
	await _click("营业")
	await _click("等待 · 60 分钟")
	await _click("交易")
	trade._pawn_price.value = 27
	await _click("正式报价并活当")
	_check(_session.read_state().cash == 47 and _session.read_state().pawn_tickets.size() == 2, "不同当约可同时在当")
	await _click("库存")
	_check(_session.counter_model().inventory.buttons.is_empty(), "在当和已售物品不生成出售按钮")
	await _capture("02_pledged")
	await _click("账本")
	await _capture("03_tickets")
	await _finish_night()
	_check(_session.read_state().summaries[0].pawn_principal == 47, "日结汇总在当本金")
	await _capture("04_summary")
	await _click("进入下一夜")
	await _click("开铺")
	await _click("账本")
	await _click("到柜台接待原当户")
	await _click("验票收赎，交还原物")
	_check(_session.read_state().cash == 80 and _session.read_state().pawn_tickets[1].status == "redeemed", "UI次夜收取赎金并交还原物")
	await _capture("05_redeemed")
	await _click("营业")
	await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
	_check(_session.read_state().cash == 47 and _session.read_state().phase == "pre_open" and _session.read_state().pawn_tickets[1].status == "active", "UI读档恢复本金和当票，不重复赎金")
	await _click("开铺")
	await _click("账本")
	await _click("到柜台接待原当户")
	await _click("验票收赎，交还原物")
	await _finish_night()
	_check(_session.read_state().pawn_tickets[0].status == "defaulted", "未返店当户的当票到期绝当")
	await _click("进入下一夜")
	await _click("开铺")
	await _click("库存")
	await _capture("06_defaulted_stock")
	await _sell_first()
	_check(_session.read_state().sale_records.size() == 2, "UI可出售绝当后的现货")
	await _finish_night()
	await _click("结束本轮试玩")
	_check(_session.read_state().phase == "run_ended", "M3收货出售活当赎回绝当三夜UI闭环")
	await _capture("07_complete")
	print("M3 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _finish_night() -> void:
	await _click("营业")
	await _click("关门（本夜不可重开）")
	await _click("等到封铺（消耗全部剩余时间）")
	var due := _session.pawn_disposal_model()
	for index in due.size():
		await _click_button(_main.find_child("NightResolutionView", true, false)._disposals.get_child(index).find_children("*", "Button", true, false)[0])
	await _click("核妥当票，合上账册" if not due.is_empty() else "结算本夜（占位）并自动保存")

func _sell_first() -> void:
	for entry in _session.counter_model().inventory.buttons:
		if entry.enabled:
			await _click(entry.label)
			return
	_check(false, "有可成交买家按钮")

func _find_trade(node: Node) -> TradePanel:
	if node is TradePanel: return node
	for child in node.get_children():
		var found := _find_trade(child)
		if found != null: return found
	return null
