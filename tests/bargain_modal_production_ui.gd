extends "res://tests/bargaining_ui_smoke.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("BARGAIN MODAL TIMEOUT"); quit(1))
	_capture_prefix = "bargain_silk_1600" if "wide" in OS.get_cmdline_user_args() else "bargain_silk_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library = SaveLibrary.new("res://.godot/qa/" + _capture_prefix + "_%d.json" % Time.get_ticks_usec())
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false
	var selected_seed := -1
	for seed_value in 128:
		for row in VarietyService.plan(_session.definition, _session._counter.catalog, seed_value):
			if row.night == 1 and row.item_id == "item_silk_panel" and row.customer_id == "customer_seamstress":
				selected_seed = seed_value
				break
		if selected_seed >= 0: break
	_check(selected_seed >= 0, "找到首夜绣坊女携花鸟绣片的可复现种子")
	if selected_seed < 0: quit(1); return
	_session.definition._seed = selected_seed
	var driver = preload("res://tests/integrated_test_driver.gd").new()
	driver.check = _check
	driver.catalog = _session._counter.catalog
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	_check(NightMarketPlan.enabled(_session.definition), "通过默认开始界面进入当前夜市七夜内容")
	var found := false
	for step in 100:
		driver.drain(_session)
		var visit := _session._counter.customers.active(_session._day.state)
		if visit != null:
			if visit.item.definition_id == "item_silk_panel" and visit.customer_id == "customer_seamstress":
				found = true
				break
			_session.counter_command("reject", visit.visit_id)
		else:
			driver.action(_session, "short_task")
	_check(found, "自然接客流程找到花鸟绣片")
	if not found: quit(1); return
	await _settle_feedback()
	await _click("鉴定")
	var visit := _session._counter.customers.active(_session._day.state)
	var item: ItemDefinition = driver.catalog.get_definition("items", visit.item.definition_id)
	for action in item.appraisal_actions:
		for entry in _session.counter_model().appraisal.buttons:
			if entry.command == "appraise" and entry.detail == action.id and entry.enabled:
				await _click(entry.label)
				break
	await _click("交易")
	var panel := _find_trade(_main)
	panel._price.value = 61
	await _capture("01_trade")
	var before := _session.read_state()
	await _click_button(panel._bargain_toggle)
	_check(_fully_visible(panel._bargain_popup.paper) and _fully_visible(panel._bargain_popup.close_button), "绣片弹层与返回入口完整可见")
	_check(_no_system_parameters(panel), "当前正式内容的弹层也不泄露隐藏参数")
	_check(panel._bargain_popup.context.text.contains("花鸟绣片"), "弹层明确当前物品和公开价格")
	await _capture("02_modal")
	for direction in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		await _modal_key(direction)
		_check(panel._bargain_popup.is_ancestor_of(root.gui_get_focus_owner()), "方向键焦点不逃出弹层")
	await _modal_key(KEY_ESCAPE)
	_check(panel._price.value == 61 and panel._mode == "offer" and _session.read_state() == before, "取消弹层保留手填报价且不消耗时间")
	await _click_button(panel._bargain_toggle)
	# A resize while open must refit the sheet, without resetting its choices.
	var original_size := root.size
	root.size = Vector2i(1100, 660)
	await _frames()
	_check(_fully_visible(panel._bargain_popup.paper), "弹层打开时缩放窗口仍在视口内")
	root.size = original_size
	await _frames()
	_check(_fully_visible(panel._bargain_popup.paper), "恢复窗口尺寸后弹层重新居中")
	_main.get_node("CounterScreen/%Drawer").hide()
	await _frames()
	_check(not panel._bargain_popup.visible, "父交易页关闭不会留下孤立遮罩")
	await _click("交易")
	await _click_button(panel._bargain_toggle)
	var button := _command_button("belittle", "")
	await _click_button(button)
	_check(not panel._bargain_popup.visible, "选择说辞后关闭弹层并返回交易")
	await _frames()
	await _capture("03_result")
	print("BARGAIN MODAL PRODUCTION: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
