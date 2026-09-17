extends "res://tests/ui_smoke.gd"

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save = GhostReplayStore.new()
	var state := _session._day.state
	state.current_night_index = 3
	state.phase = &"open"
	state.pending_event_id = ""
	var mirror := ItemInstance.new()
	mirror.instance_id = "hud-preview-mirror"
	mirror.definition_id = "item_weeping_mirror"
	mirror.selected_variant_id = _session._counter.catalog.get_definition("items", mirror.definition_id).possible_variants[0].id
	mirror.acquired_night = 3
	state.inventory_instances.append(mirror)
	_session.changed.emit()
	for command in ["close_shop", "wait_until_seal", "resolve_night"]:
		_check(_session.execute(command).ok, command)
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen.get_node("CounterView") as CounterView
	var status := screen.get_node("%ShopStatusView") as ShopStatusView
	var menu := screen.get_node("%MenuButton") as Button
	if screen.get_node("%Drawer").visible: await _click_button(screen.get_node("%CloseDrawerButton"))
	_check(not screen.get_node("%ShopTitle").visible, "铺号文字隐藏")
	_check(not screen.get_node("%PhaseStatus").visible, "铺面状态不占底栏")
	_check(view.get_node("PawnShopSign").texture.get_image().detect_alpha() != Image.ALPHA_NONE, "悬牌素材有真实透明通道")
	_check(view.get_hotspot(&"shop").get_global_rect().size.x < 128, "悬牌为小号入口")
	var before := _session.read_state()
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _frames()
		_capture_prefix = "shop_hud_%d" % dimensions.x
		root.gui_release_focus()
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(600, dimensions.y - 20)
		root.push_input(motion)
		await _frames()
		await _capture("01_counter")
		_check(status.get_global_rect().encloses(menu.get_global_rect()), "菜单在底栏内")
		_check(menu.size == Vector2(48, 48), "菜单保持48像素点击区域")
		_check_fields(screen, menu)
		await _click_button(menu)
		_check(screen.get_node("%SessionMenu").visible, "底栏菜单真实鼠标点击可用")
		await _capture("02_menu")
		await _key(KEY_ESCAPE)
		_check(not screen.get_node("%SessionMenu").visible and menu.has_focus(), "Esc关闭菜单并恢复焦点")
		await _click_button(view.get_hotspot(&"shop"))
		_check(screen.get_node("%Drawer").visible and screen.get_node("%ScreenFlowCoordinator").get_active_panel_id() == &"day", "小悬牌打开营业安排")
		await _click_button(screen.get_node("%CloseDrawerButton"))
		view.get_hotspot(&"shop").grab_focus()
		await _key(KEY_ENTER)
		_check(screen.get_node("%Drawer").visible, "悬牌支持键盘确认")
		await _click_button(screen.get_node("%CloseDrawerButton"))
		_check(before == _session.read_state(), "查看菜单与营业安排不改时间或存档状态")
		var large := before.duplicate(true)
		large.cash = 123456
		large.fee_arrears = [{"amount": 99999}]
		status.render_snapshot(large, _session.definition, true, true)
		await _frames()
		_check(screen.get_node("%CashStatus").text == "123456 大洋", "现金动态值完整显示")
		_check(screen.get_node("%DebtStatus").text.contains("短款 99999"), "短款动态值完整显示")
		_check_fields(screen, menu)
		status.render_snapshot(before, _session.definition, true, true)
		await _frames()
	print("SHOP HUD UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _check_fields(screen: Control, menu: Button) -> void:
	var previous_end := 0.0
	for field in ["ClockStatus", "NightStatus", "CashStatus", "DebtStatus", "TicketStatus", "RiskStatus"]:
		var label: Label = screen.get_node("%" + field)
		var bounds := label.get_global_rect()
		_check(not label.text.contains("\n"), "底栏单行：" + field)
		_check(bounds.position.x > previous_end and bounds.end.x < menu.get_global_rect().position.x, "栏位不重叠、不侵入菜单：" + field)
		_check(not label.accessibility_name.is_empty(), "保留状态可访问名称：" + field)
		previous_end = bounds.end.x

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event)
		await _frames()
