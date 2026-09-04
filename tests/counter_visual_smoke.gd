extends "res://tests/m4_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "counter_1600" if "wide" in OS.get_cmdline_user_args() else "counter_1280"
	if "wide" in OS.get_cmdline_user_args(): root.size = Vector2i(1600, 900)
	# Inherits the production UI, with stable content while gameplay work continues.
	_main = load("res://scenes/counter_review.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	if _session == null:
		print(_main.get_node("CounterScreen/%ContentStatus").text)
		_check(false, "主场景内容必须成功加载")
		quit(1)
		return
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("收起 · Esc")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var room := screen.get_node("CounterView/Room") as CounterStage
	var selector := screen.get_node("%PreviewSelector") as Button
	var before := _session.read_state()
	var original_bounds := room.get_global_rect()
	var original_id := room.get_instance_id()
	for mode in 3:
		await _select_preview(selector)
		_check(screen.atmosphere_presenter.current_mode == mode, "真实预览控件切换三态")
		_check(room.get_instance_id() == original_id and room.get_global_rect() == original_bounds, "三态保持同一场景与锚点")
		_check(_session.read_state() == before, "美术预览不改玩法、时间、现金或历史")
		_check(not screen.get_node("%Drawer").visible, "预览收起抽屉，可看完整柜台")
		await _capture(["01_normal", "02_late", "03_ghost"][mode])
	# Restore runtime-driven lighting through the same selector.
	await _select_preview(selector)
	_check(screen.atmosphere_presenter.preview_mode == -1, "可退出预览并恢复游戏氛围")
	await _click("交易")
	await _capture("04_trade_drawer")
	_check(screen.get_node("%ShopStatusView").get_global_rect().position.y > screen.get_node("%Drawer").get_global_rect().end.y, "抽屉不遮挡底部数字")
	await _click("账本")
	await _capture("05_ledger_drawer")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(not screen.get_node("%Drawer").visible, "Esc可收起功能抽屉")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await _frames()
		var viewport_rect := Rect2(Vector2.ZERO, screen.size)
		for name in ["ShopStatusView", "ClockStatus", "CashStatus", "RiskStatus", "PhaseStatus", "DayButton", "TradeButton", "MoreButton", "ItemText", "CustomerText"]:
			var control := screen.get_node("%" + name) as Control
			if not viewport_rect.grow(0.1).encloses(control.get_global_rect()): print(name, ": ", control.get_global_rect(), " viewport ", viewport_rect)
			_check(viewport_rect.grow(0.1).encloses(control.get_global_rect()), "缩放后控件不溢出：%s/%s" % [dimensions, name])
		if dimensions.x >= 1920: await _capture("layout_%d" % dimensions.x)
	# Run-time changes must leave preview and use the existing game clock.
	await _click("营业")
	await _click("关门（本夜不可重开）")
	_check(screen.atmosphere_presenter.current_mode == 1, "实际关门进入深夜氛围")
	_check(not room.smoke_wrong, "没有风险证据时不伪造香烟异常")
	print("COUNTER VISUAL SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _select_preview(selector: Button) -> void:
	await _click("更多")
	await _click_button(selector)
	await _frames()
