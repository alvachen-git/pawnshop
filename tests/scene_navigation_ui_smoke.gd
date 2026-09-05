extends "res://tests/ui_smoke.gd"


func _run() -> void:
	var wide := "wide" in OS.get_cmdline_user_args()
	_capture_prefix = "scene_navigation_1600" if wide else "scene_navigation_1280"
	root.size = Vector2i(1600, 900) if wide else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m3_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var counter_view := screen.get_node("CounterView") as CounterView
	var flow := screen.get_node("ScreenFlowCoordinator") as ScreenFlowCoordinator
	_check(screen.get_node_or_null("Navigation") == null, "旧整排导航已移除")
	_check(screen.get_node("%MenuButton").text == "菜单", "右下角入口命名为菜单")
	_check(screen.get_node("SessionMenu/MenuMargin/MenuColumn/RunSectionLabel").text == "本局" and screen.get_node("SessionMenu/MenuMargin/MenuColumn/ShopSectionLabel").text == "铺务", "菜单按本局与铺务分组")
	_check(screen.get_node("%LoadRunButton").disabled, "没有夜末存档时读档不可用")
	_check(not counter_view.get_hotspot(&"customer").visible and not counter_view.get_hotspot(&"item").visible, "无客无货时隐藏情境热点")

	var before := _session.read_state()
	await _click("库存")
	_check(flow.get_active_panel_id() == &"inventory", "点击左侧库存柜打开库存")
	await _click("账本")
	_check(flow.get_active_panel_id() == &"ledger", "点击桌面账本打开账本")
	await _click("营业")
	_check(flow.get_active_panel_id() == &"day", "点击铺面招牌打开营业")
	await _click("菜单")
	_check(screen.get_node("%SessionMenu").visible, "右下角菜单向上展开")
	_check(_session.read_state() == before, "场景导航与菜单查看不修改运行状态")
	await _capture("01_grouped_menu")
	_push_escape()
	await _frames()
	_check(not screen.get_node("%SessionMenu").visible, "Esc优先关闭菜单")

	await _click("营业")
	await _click("开铺")
	_check(counter_view.get_hotspot(&"customer").visible and counter_view.get_hotspot(&"item").visible, "客人与货物到场后显示可点击热点")
	var room := screen.get_node("CounterView/Room") as CounterStage
	var portrait := screen.get_node("CounterView/CustomerPortrait") as TextureRect
	var item_image := screen.get_node("CounterView/CounterItemImage") as TextureRect
	_check((room.has_customer or portrait.texture != null) and (room.has_item or item_image.texture != null), "正式图片与占位客货共用同一热点")
	before = _session.read_state()
	await _click_button(counter_view.get_hotspot(&"customer"))
	_check(counter_view.get_node("CustomerContext").visible, "点击客人显示对话与交易")
	_check(not counter_view.get_node("ItemContext").visible and not screen.get_node("%Drawer").visible, "客人情境入口独占且让出柜台画面")
	_check(_find_button(_main, "对话") != null and _find_button(_main, "交易") != null, "客人情境入口内容正确")
	await _capture("02_customer_context")
	await _click_button(counter_view.get_hotspot(&"item"))
	_check(counter_view.get_node("ItemContext").visible and not counter_view.get_node("CustomerContext").visible, "点击货物切换为鉴定入口")
	_check(_find_button(_main, "鉴定") != null and _find_button(_main, "对话") == null, "货物情境只显示鉴定")
	_check(_session.read_state() == before, "选择客人与货物不推进时间")
	await _capture("03_item_context")
	_push_escape()
	await _frames()
	_check(not counter_view.get_node("ItemContext").visible, "Esc优先关闭情境入口")

	await _click("对话")
	_check(flow.get_active_panel_id() == &"dialogue", "客人情境入口打开对话Panel")
	_check(_session.read_state() == before, "打开对话Panel不推进时间")
	await _click("交易")
	_check(flow.get_active_panel_id() == &"trade", "客人情境入口打开交易Panel")
	await _click("鉴定")
	_check(flow.get_active_panel_id() == &"appraisal", "货物情境入口打开鉴定Panel")
	_check(_session.read_state() == before, "打开交易与鉴定Panel不推进时间")

	await _click("营业")
	_push_escape()
	await _frames()
	_check(not screen.get_node("%Drawer").visible, "没有情境或菜单时Esc收起功能Panel")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await _frames()
		var viewport_rect := Rect2(Vector2.ZERO, screen.size)
		for kind in [&"shop", &"customer", &"item", &"inventory", &"ledger"]:
			_check(viewport_rect.encloses(counter_view.get_hotspot(kind).get_global_rect()), "缩放后热点不溢出：%s/%s" % [dimensions, kind])
		_check(viewport_rect.encloses((screen.get_node("%MenuButton") as Control).get_global_rect()), "缩放后菜单按钮不溢出：%s" % dimensions)
	print("SCENE NAVIGATION UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _push_escape() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
