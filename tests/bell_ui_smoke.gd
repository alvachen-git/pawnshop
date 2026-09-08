extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("BELL UI TIMEOUT"); quit(1))
	_capture_prefix = "bell_1600" if "wide" in OS.get_cmdline_user_args() else "bell_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/bell/%d.json" % Time.get_ticks_usec()
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	_main.title_menu.configure(true, false)
	driver.check = _check
	driver.catalog = _session._counter.catalog
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	var screen: CounterScreen = _main.get_node("CounterScreen")
	screen._close_drawer()
	await _frames()
	var view: CounterView = screen.get_node("CounterView")
	var bell: Button = view.bell
	_check(not view.has_node("CounterActions"), "felt has no duplicate inquiry/appraisal/offer row")
	_check(bell.get_global_rect().get_center().x > view.get_global_rect().position.x + view.size.x * 0.70 and bell.anchor_bottom < 0.75, "bell is beside the right desk lamp")
	_check(not bell.get_global_rect().intersects(view.get_hotspot(&"ledger").get_global_rect()), "bell target does not overlap ledger target")
	var clean_state := _session.read_state()
	root.gui_release_focus()
	await _capture("00_clean_counter")
	for mode in [1, 2]:
		screen.atmosphere_presenter.set_preview(mode)
		await _frames()
		_check(view.bell.atmosphere == mode and clean_state == _session.read_state(), "bell lighting follows visual preview without changing gameplay")
		await _capture("00_late" if mode == 1 else "00_ghost")
	screen.atmosphere_presenter.set_preview(-1)
	await _click_button(view.get_hotspot(&"customer"))
	_check(view._customer_context.visible and view._dialogue_action.get_theme_stylebox("normal") is StyleBoxTexture, "existing customer context uses paper art")
	await _capture("00a_customer_context")
	await _click("对话")
	var dialogue: DialoguePanel = _main.find_child("DialoguePanel", true, false)
	_check(dialogue._buttons.get_child_count() > 0 and dialogue._buttons.get_child(0).get_theme_stylebox("normal") is StyleBoxTexture, "existing question buttons inherit paper art")
	await _capture("00b_dialogue_paper")
	await _click("收起 · Esc")
	await _click_button(view.get_hotspot(&"item"))
	_check(view._item_context.visible and view._appraisal_action.get_theme_stylebox("normal") is StyleBoxTexture, "existing item context uses paper art")
	await _capture("00c_item_context")
	await _click("鉴定")
	await _capture("00d_appraisal_paper")
	await _click("收起 · Esc")
	await _click("交易")
	_check(_find_trade(_main)._submit.get_theme_stylebox("normal") is StyleBoxTexture, "existing quote submit button uses paper art")
	await _capture("00e_trade_paper")
	await _click("收起 · Esc")
	_check(clean_state == _session.read_state(), "restyled context and panel navigation stays free")
	_check(not view.get_node("CounterMessage").visible and view.get_node("CounterMessage").text.is_empty(), "felt has no queue or transaction summary")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(bell.get_global_rect()), "bell fits window edge")
	_check(not bell.disabled, "bell available with ordinary customer")
	var before := _session.read_state()
	await _click_button(bell)
	_check(before == _session.read_state(), "short tap with customer is harmless")
	await press_bell(bell, true)
	await create_timer(0.3).timeout
	await _capture("01_hold_progress")
	await press_bell(bell, false)
	_check(before == _session.read_state(), "early release cancels hold")
	await press_bell(bell, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(5, 5)
	root.push_input(motion, true)
	await create_timer(1.1).timeout
	await press_bell(bell, false)
	_check(before == _session.read_state(), "pointer departure cancels hold")
	var id: String = _session.counter_model().active_id
	await press_bell(bell, true)
	await create_timer(1.1).timeout
	_check(_session._day.state.visit_history.size() == 1 and _session._day.state.visit_history[0].visit_id == id and _session._day.state.game_minutes == 5, "hold dismisses original visitor once")
	await create_timer(1.1).timeout
	await press_bell(bell, false)
	_check(_session._day.state.game_minutes == 5, "held button does not dismiss another or auto wait")
	_check(not bell.disabled, "manual dismissal leaves bell ready to await next visitor")
	await receipts()
	screen._close_drawer()
	await _frames()
	await _capture("02_empty_felt")
	var next := _session._day.state.visits[1]
	await _click_button(bell)
	_check(_session._day.state.game_minutes == next.arrival and _session.counter_model().active_id == next.visit_id, "tap empty counter jumps exactly to next customer")
	await _capture("03_next_customer")
	before = _session.read_state()
	await press_bell(bell, true)
	screen._flow.show_panel(&"ledger")
	await create_timer(1.1).timeout
	await press_bell(bell, false)
	_check(before == _session.read_state() and bell.disabled, "drawer opening cancels ongoing hold")
	screen._close_drawer()
	await _frames()
	bell.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	await create_timer(1.1).timeout
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = false
	root.push_input(key, true)
	await _frames()
	_check(_session._day.state.visit_history.size() == 2, "keyboard hold also dismisses")
	print("BELL UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func press_bell(bell: Button, down: bool) -> void:
	var point := bell.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	root.push_input(click, true)
	await _frames()
