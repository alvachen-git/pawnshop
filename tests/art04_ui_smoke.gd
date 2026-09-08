extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("ART04 UI TIMEOUT"); quit(1))
	_capture_prefix = "art04_1600" if "wide" in OS.get_cmdline_user_args() else "art04_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/art04_autosave_%d.json" % Time.get_ticks_usec()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "正式入口加载成功")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/art04_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	for step in 12: await narrative_choice()
	await narrative_choice("accounts")
	await narrative_choice("ledger")
	await narrative_choice("ready")
	await _click("营业")
	await _click("开铺")
	await narrative_choice()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._close_drawer()
	await _frames()
	var view := screen.get_node("CounterView") as CounterView
	_check(view._portrait.texture.resource_path.ends_with("neighbor.png"), "妇人使用独立妇人立绘")
	_check(view._item_image.texture.resource_path.ends_with("hairpin_front.png"), "正式首客显示银簪")
	await _clean_capture("01_opening")
	var before := _session.read_state()
	_check(not view.has_node("CounterActions"), "桌面不再重复展示三个动作")
	for entry in [["对话", &"dialogue"], ["鉴定", &"appraisal"], ["交易", &"trade"]]:
		await _click(entry[0])
		_check(screen.get_node("%ScreenFlowCoordinator").get_active_panel_id() == entry[1], "原情境入口打开正确功能：" + entry[0])
		_check(screen.get_node("%Drawer").visible, "真实鼠标打开抽屉")
		await _click("收起 · Esc")
	_check(before == _session.read_state(), "查看对话、鉴定、报价不耗时或泄露线索")
	var room: CounterStage = view.get_node("Room")
	var anchors := [view._portrait.get_global_rect(), view._item_image.get_global_rect(), room.get_global_rect()]
	var original_texture: Texture2D = room.get_node("PaintedRoom").texture
	for mode in 3:
		await _click("菜单")
		await _click_button(screen.get_node("%PreviewSelector"))
		_check(screen.atmosphere_presenter.current_mode == mode, "预览选择器切换三态")
		_check(anchors == [view._portrait.get_global_rect(), view._item_image.get_global_rect(), room.get_global_rect()], "三态人物物品场景锚点连续")
		_check(room.get_node("PaintedRoom").texture == original_texture, "三态共用原画")
		_check(before == _session.read_state(), "三态预览不更改玩法和存档状态")
		await _clean_capture(["02_normal", "03_late", "04_ghost"][mode])
	await _click("菜单")
	await _click_button(screen.get_node("%PreviewSelector"))
	_check(screen.atmosphere_presenter.preview_mode == -1, "回到随游戏的真实氛围")
	await _click("交易")
	_find_trade(_main)._price.value = _session.counter_model().trade.asking_price
	await _click("正式报价并收购")
	await receipts()
	if narrative.visible: await narrative_choice()
	screen._close_drawer()
	await _frames()
	_check(not view._portrait.visible and not view._item_image.visible, "成交移除人物与银簪")
	_check(not view.get_hotspot(&"customer").visible and not view.get_hotspot(&"item").visible, "空柜台没有顾客或物品的情境入口")
	await _clean_capture("05_empty")
	for name in ["InventoryButton", "LedgerButton"]:
		await _click_button(view.get_node(name))
		_check(screen.get_node("%Drawer").visible, "次级纸签可操作")
		await _clean_capture(name)
		await _click("收起 · Esc")
	for name in ["ShopStatusView", "MenuButton", "CashStatus", "DebtStatus"]:
		_check(Rect2(Vector2.ZERO, screen.size).grow(0.1).encloses(screen.get_node("%" + name).get_global_rect()), "持续信息没有溢出：" + name)
	_main.queue_free()
	await process_frame
	# The accepted visual reference has a man with a bowl. Use the existing
	# art fixture for that comparison; the production opening above uses a woman.
	if "wide" in OS.get_cmdline_user_args(): root.size = Vector2i(1672, 941)
	_main = load("res://scenes/art02_review.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("收起 · Esc")
	await _clean_capture("06_reference_comparison")
	print("ART04 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _clean_capture(label: String) -> void:
	root.gui_release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1250, 650)
	root.push_input(motion, true)
	await _frames()
	await _capture(label)
