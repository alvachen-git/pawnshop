extends "res://tests/ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "m4_1600" if "wide" in OS.get_cmdline_user_args() else "m4_1280"
	if "wide" in OS.get_cmdline_user_args(): root.size = Vector2i(1600, 900)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m4_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	_check(_session != null, "M4主场景内容加载")
	if _session == null:
		quit(1)
		return
	_check(_session.read_state().pending_event_id == "shen_opening", "默认出现沈怀川核账说明")
	await _capture("01_shen")
	var before := _session.read_state()
	await _click("库存")
	await _click("营业")
	var open_button := _find_button(_main, "开铺")
	_check(open_button != null and open_button.disabled, "锚点未处理前开铺按钮禁用")
	await _click("铺中记事")
	await create_timer(0.3).timeout
	_check(before == _session.read_state(), "事件阅读、切换面板和现实等待不耗时、不重抽")
	await _click("请他介绍买家")
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("交易")
	var trade := _find_trade(_main)
	trade._pawn_price.value = 27
	await _click("正式报价并活当")
	_check(_session.read_state().cash == 73 and _session.read_state().pawn_tickets.size() == 1, "M4首夜活当占用现金")
	await _finish_m4_night()
	await _capture("02_first_summary")
	await _click("进入下一夜")
	_check(_session.read_state().pending_event_id == "cash_lesson", "第二夜锚点优先")
	var next := _session.read_state()
	await _resolve_events()
	_check("buyer_introduced" in _session.read_state().narrative_flags, "UI选择收到回信并解锁买家")
	await _capture("03_reply")
	await _click("营业")
	await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
	_check(_session.read_state() == next, "实际读档恢复待办和原有选择")
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("账本")
	await _click("收赎金 33 并交还原物")
	_check(_session.read_state().cash == 106, "事件接入后仍可按窗口赎当")
	await _click("鉴定")
	await _click("识货：查看怀表 · 5分钟")
	await _click("辨真：灯下检查机芯走时 · 10分钟")
	await _capture("04_watch_evidence")
	await _click("交易")
	trade._price.value = 80
	await _click("正式报价并收购")
	_check(_session.read_state().cash == 26, "新物品怀表真实成交占款")
	await _click("营业")
	await _click("等待 · 60 分钟")
	await _click("库存")
	await _capture("05_introduced_buyer")
	await _click("怀表 → 商会旧货客：100 · 10分钟")
	_check(_session.read_state().cash == 126 and _session.read_state().sale_records[0].realized_profit == 20, "介绍带来真实出售机会和利润20")
	await _finish_m4_night()
	await _click("进入下一夜")
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("鉴定")
	await _click("识货：查看银簪 · 5分钟")
	await _click("辨真：放大镜查看戳记与磨损 · 10分钟")
	_check(_session.counter_model().appraisal.body.contains("镀银"), "第三夜配置呈现不同物品及假货证据")
	await _capture("06_third_night")
	await _finish_m4_night()
	await _click("结束本轮试玩")
	_check(_session.read_state().phase == "run_ended", "M4连续三夜UI闭环")
	await _click("铺中记事")
	await _capture("07_history")
	var panel := _main.get_node("CounterScreen/Margin/RootLayout/Workspace/SideColumn/PanelStack/EventPanel")
	_check(panel.get_global_rect().end.x <= root.size.x and panel.get_global_rect().end.y <= root.size.y, "事件面板在视口内")
	print("M4 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _resolve_events() -> void:
	for guard in 10:
		var model := _session.event_model()
		if model.pending_id.is_empty(): return
		await _click("铺中记事")
		await _click(model.buttons[0].label)
	_check(false, "事件链在有限步内结束")

func _finish_m4_night() -> void:
	await _click("营业")
	await _click("关门（本夜不可重开）")
	await _resolve_events()
	await _click("营业")
	await _click("等到封铺（消耗全部剩余时间）")
	await _click("结算本夜（占位）并自动保存")

func _find_trade(node: Node) -> TradePanel:
	if node is TradePanel: return node
	for child in node.get_children():
		var found := _find_trade(child)
		if found != null: return found
	return null
