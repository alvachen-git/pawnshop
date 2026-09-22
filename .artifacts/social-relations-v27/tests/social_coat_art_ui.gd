extends "res://tests/social_ui.gd"

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("COAT ART UI TIMEOUT"); quit(1))
	_capture_prefix = "coat_folded_1600" if "wide" in OS.get_cmdline_user_args() else "coat_folded_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/coat_art_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	install("cotton"); await receipts()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._close_drawer()
	await create_timer(0.4).timeout
	var view := screen._counter_view
	var prop := view._item_image
	_check(prop.texture.resource_path.ends_with("cotton_coat_folded.png"), "folded asset loaded")
	_check(prop.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "transparent asset")
	_check(prop.get_global_rect().size.x >= root.size.x * .23, "large tabletop footprint")
	_check(view._item_hotspot.get_global_rect().encloses(prop.get_global_rect()), "click target covers prop")
	_check(not prop.get_global_rect().intersects(view.get_hotspot(&"social").get_global_rect()), "coat clears relation book")
	_check(not prop.get_global_rect().intersects(view.bell.get_global_rect()), "coat clears bell")
	_check(prop.get_global_rect().end.y < root.size.y * .9, "coat stays above status strip")
	await _capture("01_counter")
	var before := JSON.stringify(_session.read_state())
	await _click_button(view._item_hotspot)
	_check(view._item_context.is_visible_in_tree(), "click folded bundle opens actions")
	await _capture("02_actions")
	await _click_button(view._appraisal_action)
	_check(screen.get_node("%ScreenFlowCoordinator").get_active_panel_id() == &"appraisal", "appraisal still reachable")
	_check(JSON.stringify(_session.read_state()) == before, "viewing prop spends nothing")
	await _capture("03_appraisal")
	install("intimidation"); await receipts(); screen._close_drawer()
	await create_timer(0.4).timeout
	_check(not prop.texture.resource_path.ends_with("cotton_coat_folded.png"), "next fixture is another item")
	_check(is_equal_approx(prop.anchor_left, .425) and is_equal_approx(prop.anchor_right, .595), "other items restore normal scale")
	_check(is_equal_approx(view._item_hotspot.anchor_right, .595), "other item hit area restored")
	print("COAT ART UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)
