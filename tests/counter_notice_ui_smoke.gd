extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "counter_notice_1600" if "wide" in OS.get_cmdline_user_args() else "counter_notice_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session.content_version == 21 and _session.definition.id == "night_market" and FamiliarStories.enabled(_session.definition) and not _session.definition.market.is_empty(), "default combines familiar stories with market")
	_session._save.library.path = "res://.godot/qa/notice_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	if screen.get_node("%Drawer").visible: await _click("收起 · Esc")
	var notice := screen.get_node("MarketNotice") as Button
	var menu := screen.get_node("%MenuButton") as Button
	var view := screen.get_node("CounterView") as CounterView
	_check(view.get_node_or_null("InventoryButton") == null and view.get_node_or_null("LedgerButton") == null, "duplicate shortcuts removed")
	_check(notice.global_position.x > screen.size.x * 0.85, "notice sits at right")
	_check(notice.global_position.y > screen.size.y * 0.70 and notice.icon != null, "envelope at bottom right")
	_check(notice.get_global_rect().end.y < screen.get_node("%ShopStatusView").global_position.y, "envelope above status bar")
	_check(menu.icon != null and menu.text.is_empty() and menu.size == Vector2(48, 48), "menu has icon and 48px target")
	_check(not menu.get_global_rect().intersects(view.get_node("CustomerPanel").get_global_rect()), "menu clear of customer card")
	_check(not notice.get_global_rect().intersects(view.get_hotspot(&"ledger").get_global_rect()), "notice clear of ledger")
	_check(screen._notice_stamp.visible, "new notice marked")
	await create_timer(0.3).timeout
	await _capture("01_counter")
	var before := _session.read_state()
	await _click_button(notice)
	var panel := screen.get_node("%InventoryPanel") as InventoryPanel
	_check(panel._sale_view._buyer == "buyer_lu", "notice opens Lu directly")
	_check(not notice.visible, "drawer hides notice instead of leaving a clipped edge")
	_check(panel._sale_view._submit.disabled and panel._sale_view._total.text.contains("店里还有客人"), "guest still blocks departure")
	_check(not screen._notice_stamp.visible, "read mark clears")
	_check(before == _session.read_state(), "read notice has no gameplay cost")
	await _capture("02_letter")
	await _click("收起 · Esc")
	_check(notice.has_focus(), "closing letter restores focus")
	await _click("菜单")
	_check(screen.get_node("%SessionMenu").visible, "icon opens working menu")
	_check(not notice.visible, "menu hides notice")
	_check(screen.get_node("%SessionMenu").get_global_rect().end.y < screen.get_node("%ShopStatusView").global_position.y, "menu does not cover status bar")
	_check(Rect2(Vector2.ZERO, screen.size).encloses(screen.get_node("%SessionMenu").get_global_rect()), "menu stays in viewport")
	await _capture("03_menu")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE; escape.pressed = true
	root.push_input(escape); await _frames()
	_check(not screen.get_node("%SessionMenu").visible and menu.has_focus(), "escape closes menu and restores focus")
	for route in ["库存", "账本"]:
		await _click(route)
		_check(screen.get_node("%Drawer").visible, "scene route remains usable: " + route)
		await _click("收起 · Esc")
	_check(before == _session.read_state(), "navigation is free")
	print("COUNTER NOTICE UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)
