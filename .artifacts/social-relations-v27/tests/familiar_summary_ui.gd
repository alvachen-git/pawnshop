extends "res://tests/familiar_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "familiar_summary_1600" if "wide" in OS.get_cmdline_user_args() else "familiar_summary_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/familiar_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/familiar/summary_auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var library := _session._save.library
	library.path = "res://.godot/qa/familiar/summary_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/familiar/late_507_final.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 17, _session._counter.catalog, true)
	_check(state != null, "load real completed story fixture")
	_check(library.write_entry("manual/1", state, _session.definition, 17, _session._counter.catalog), "publish final slot")
	_check(library.adopt(library.read_entry("manual/1"), _session), "read final slot through shared manager")
	await _frames()
	await _click("夜间结算")
	var panel := _main.get_node("CounterScreen/Drawer/DrawerColumn/PanelStack/NightResolutionView") as NightResolutionView
	var scroll := panel._account.get_parent().get_parent() as ScrollContainer
	var pointer := InputEventMouseMotion.new()
	pointer.position = scroll.get_global_rect().get_center()
	root.push_input(pointer)
	for step in 32:
		var wheel := InputEventMouseButton.new()
		wheel.position = pointer.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel)
		wheel = wheel.duplicate()
		wheel.pressed = false
		root.push_input(wheel)
		await _frames()
	_check(scroll.scroll_vertical > 0, "mouse reaches account footer")
	var notes := FamiliarStories.note(_session._day.state)
	_check(notes.contains("姜素云") and notes.contains("仍在当"), "future ticket remains active in final account")
	await _capture("pending_ticket")
	print("FAMILIAR SUMMARY UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
