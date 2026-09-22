extends "res://tests/bargaining_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "manual_1600" if "wide" in OS.get_cmdline_user_args() else "manual_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/seven_night.tscn").instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var storage: SaveLibraryView = _main.storage
	_check(storage != null, "production storage attached")
	storage.library.path = "user://tests/" + _capture_prefix + "_library.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage.library.path))
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	_session.new_run()
	await _frames()
	_check(_find_button(_main, "存档 / 读档") == null, "no standalone save/load button")
	await _capture("00_counter_menu_only")
	await _open_storage("save")
	_check(storage.list.get_child_count() == 6, "six manual positions")
	storage.filter.grab_focus()
	for step in 14:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		root.push_input(tab)
		await _frames()
		_check(storage.overlay.is_ancestor_of(root.gui_get_focus_owner()), "keyboard stays within save list")
	var before := _session.read_state()
	await _click_button(storage.list.get_node("manual_1"))
	_check(storage.status.text.contains("保存成功"), "successful save feedback")
	_check(_session.read_state() == before and not storage.library.dirty(_session._day.state), "save free and clean")
	await _capture("01_six_slots")
	await _click_button(storage.list.get_node("manual_1"))
	_check(storage.confirm.visible, "overwrite confirmation")
	await _click_button(storage.confirm.get_cancel_button())
	storage.close()
	_check(_session.execute("open_shop").ok, "open actual shop")
	_main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(storage.leave_dialog.visible and storage.leave_dialog.dialog_text.contains("营业期间不能保存"), "normal window close uses same open warning")
	await _click_button(storage.leave_dialog.get_cancel_button())
	_check(_session.read_state().phase == "open", "window close cancel preserves live run")
	await _open_storage("load")
	await _click("保存游戏")
	_check(storage.status.text.contains("营业期间不能保存") and storage.list.get_node("manual_1").disabled, "open save disabled")
	await _capture("02_open_disabled")
	await _click("读取游戏")
	await _click_button(storage.list.get_node("manual_1"))
	_check(storage.confirm.visible, "open can load after confirmation")
	await _click_button(storage.confirm.get_ok_button())
	_check(_session.read_state().phase == "pre_open" and not storage.overlay.visible, "actual load restores saved preopen")
	_check(not (_main.find_child("CustomerDeparture", true, false) as Control).visible, "load has no stale departure")
	_session.execute("open_shop")
	_session.execute("short_task")
	_session.execute("close_shop")
	await _open_storage("save")
	await _click_button(storage.list.get_node("manual_2"))
	_check(storage.status.text.contains("保存成功"), "closed but unsettled UI save")
	await _capture("03_closed_saved")
	var previous_file := FileAccess.get_file_as_string(storage.library.path)
	storage.library.fail_write = true
	await _click_button(storage.list.get_node("manual_2"))
	await _click_button(storage.confirm.get_ok_button())
	_check(storage.error_dialog.visible and FileAccess.get_file_as_string(storage.library.path) == previous_file, "failed overwrite reports and preserves save")
	await _click_button(storage.error_dialog.get_ok_button())
	storage.library.fail_write = false
	storage.close()
	_session.execute("wait_until_seal")
	storage.request_leave("title")
	_check(storage.leave_dialog.visible, "dirty close requests exit decision")
	await _capture("04_exit_confirmation")
	await _click_button(storage.leave_dialog.get_cancel_button())
	_check(_session.read_state().phase == "night_resolution", "cancel exit preserves current progress")
	storage.request_leave("title")
	for button in storage.leave_dialog.get_ok_button().get_parent().get_children():
		if button is Button and button.text == "保存后离开": await _click_button(button); break
	_check(storage.overlay.visible and storage.mode == "save", "save-before-leave asks for slot")
	await _click_button(storage.list.get_node("manual_3"))
	_check(is_instance_valid(_main.title_menu) and _main.title_menu.visible, "saved successfully then returned to title")
	# Load a real opening checkpoint through the same six shared slots.
	var catalog := JsonContentProvider.new("res://data/opening_manifest.json").load_catalog().catalog
	var opening := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var temporary := RunSession.new(opening, catalog.content_version, SaveManager.new("user://tests/manual_opening.json"), catalog)
	_check(storage.library.write_entry("manual/6", temporary._day.state, opening, catalog.content_version, catalog), "opening stored in shared sixth slot")
	await _click_button(_main.title_menu.buttons[1])
	_check(storage.overlay.visible, "title uses shared load list")
	var sixth := storage.list.get_node("manual_6") as Button
	(sixth.get_parent().get_parent() as ScrollContainer).ensure_control_visible(sixth)
	await _frames()
	await _click_button(sixth)
	await _click_button(storage.confirm.get_ok_button())
	_check(_session.definition.id == "opening_v01", "cross-entry loads correct opening content")
	await _frames()
	_check((_main.find_child("NarrativeScene", true, false) as Control).visible, "opening resumes pending scene")
	await _open_storage("load")
	_check(storage.overlay.visible, "storage reachable over narrative")
	await _capture("05_cross_entry")
	storage.close()
	_main.queue_free()
	await _frames()
	print("MANUAL SAVE UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(1 if _failures else 0)

func _open_storage(mode: String) -> void:
	await _frames()
	var departure := _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	if departure.visible: await _click_button(departure._primary)
	var narrative := _main.find_child("NarrativeScene", true, false) as NarrativeScene
	var menu_button := narrative._menu_button if narrative.visible else _main.find_child("MenuButton", true, false) as Button
	await _click_button(menu_button)
	var menu := _main.find_child("SessionMenu", true, false) as SessionMenuView
	_check(menu.visible, "ordinary menu reachable")
	if _session._day.state.phase == &"open":
		_check(menu._save_button.disabled and menu._save_button.tooltip_text.contains("营业期间不能保存"), "menu save restriction explained")
	var target := menu._save_button if mode == "save" else menu.get_node("%LoadRunButton") as Button
	await _click_button(target)
	_check(_main.storage.overlay.visible, "menu opens shared storage")
