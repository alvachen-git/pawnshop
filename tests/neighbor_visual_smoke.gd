extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("NEIGHBOR VISUAL TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	_capture_prefix = "neighbor_v2"
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/neighbor_v2_autosave.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "production scene loads")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/neighbor_v2_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	driver.check = _check
	driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._close_drawer()
	var view := screen.get_node("CounterView") as CounterView
	_check(view._portrait.texture.resource_path == CounterVisualCatalog.NEIGHBOR_PORTRAIT, "opening neighbor resolves to revised sprite")
	var state_before := _session.read_state()
	var new_texture := view._portrait.texture
	var new_material := view._portrait.material
	# Same scene and viewport for the old/new comparison; no gameplay changes.
	view._portrait.texture = load("res://assets/art04/customers/neighbor.png")
	view._portrait.material = CounterVisualCatalog.portrait_material(view._portrait.texture)
	view._bounds(view._portrait, 0.315, 0.027, 0.68, 0.592)
	await _shot("1600_before")
	view._portrait.texture = new_texture
	view._portrait.material = new_material
	view._bounds(view._portrait, 0.315, 0.025, 0.68, 0.604)
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _frames()
		_check(Rect2(Vector2.ZERO, screen.size).encloses(view._portrait.get_global_rect()), "full portrait fits at %d" % dimensions.x)
		var portrait_size := view._portrait.size
		var side := minf(portrait_size.x, portrait_size.y)
		var image_top := view._portrait.position.y + (portrait_size.y - side) * 0.5
		var waist_y := image_top + side * (1086.0 / 1254.0)
		var wood_back_y := view.size.y * (445.0 / 941.0 / 0.9)
		_check(absf(waist_y - wood_back_y) < view.size.y * 0.005, "waist occlusion meets painted counter at %d" % dimensions.x)
		await _shot("%d_after" % dimensions.x)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	await _frames()
	for mode in 3:
		await _click("菜单")
		await _click_button(screen.get_node("%PreviewSelector"))
		_check(screen.atmosphere_presenter.current_mode == mode, "real atmosphere selector reaches %d" % mode)
		_check(_session.read_state() == state_before, "visual changes preserve gameplay state")
		await _shot(["1600_normal", "1600_late", "1600_ghost"][mode])
	await _click("菜单")
	await _click_button(screen.get_node("%PreviewSelector"))
	await _click("对话")
	var dialogue := screen.get_node("%DialoguePanel") as DialoguePanel
	_check(dialogue._portrait.texture == new_texture, "dialogue uses the same revised identity")
	_check(not dialogue._portrait.material.get_shader_parameter("hand_contact_shadow"), "dialogue portrait has no table shadow")
	await _shot("1600_dialogue")
	await _click("收起 · Esc")
	await _click("交易")
	_check(screen.get_node("%Drawer").visible, "customer trade remains accessible")
	await _click("收起 · Esc")
	_check(_session.read_state() == state_before, "opening and closing drawers costs no time or cash")
	var visit := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "first trade still completes")
	await _frames()
	_check(not view._portrait.visible, "departure removes both hands and their shadow")
	await receipts()
	screen._close_drawer()
	await _shot("1600_departed")
	print("NEIGHBOR VISUAL: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _shot(label: String) -> void:
	root.gui_release_focus()
	Input.warp_mouse(Vector2(1550, 800))
	await create_timer(0.15).timeout
	await _capture(label)
