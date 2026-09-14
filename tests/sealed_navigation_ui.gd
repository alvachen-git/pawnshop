extends "res://tests/manual_save_ui_smoke.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("SEALED NAVIGATION TIMEOUT"); quit(1))
	_capture_prefix = "sealed_1600" if "wide" in OS.get_cmdline_user_args() else "sealed_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = "user://tests/sealed_%d.json" % Time.get_ticks_usec()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library = SaveLibrary.new("user://tests/sealed_library_%d.json" % Time.get_ticks_usec())
	_main.storage = SaveLibraryView.new()
	_main.add_child(_main.storage)
	_main.storage.bind(_session)
	_main.storage.loaded.connect(_main._enter_game)
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	_session.new_run()
	var driver := preload("res://tests/integrated_test_driver.gd").new()
	driver.check = _check
	driver.catalog = _session._counter.catalog
	driver.drain(_session)
	# Finish the first night through real actions, then reproduce the reported second night.
	for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
		driver.action(_session, command)
		driver.drain(_session)
	await _frames()
	_check(_session.read_state().current_night_index == 2, "latest default run reaches second night")
	await _click("营业")
	await _click("开铺营业")
	driver.drain(_session)
	await _click("营业")
	await _click("等到封铺（消耗全部剩余时间）")
	_check(_session.read_state().phase == "night_resolution", "wait seals second night")
	var sealed := _session.read_state()
	await _open_storage("save")
	await _click_button(_main.storage.list.get_node("manual_1"))
	_check(_main.storage.status.text.contains("保存成功"), "save sealed night through real menu")
	await _click("关闭 · Esc")
	await _click("营业")
	await _capture("after_save")
	var entry := _find_button(_main, "查看夜间结算")
	_check(entry != null and not entry.disabled, "sealed shop retains a visible settlement entry after saving")
	if entry == null: _finish(); return
	var panel := _main.find_child("DayFlowPanel", true, false) as DayFlowPanel
	_check(panel._buttons.size() == 1 and not panel._description.text.contains("开铺前"), "sealed panel removes obsolete business commands and preparation advice")
	await _click_button(entry)
	_check(_session.read_state() == sealed, "viewing settlement does not spend time or settle accounts")
	await _click("合上今夜的账册")
	_check(_session.read_state().phase == "shop_resolution", "settles before entering room")
	var settled := _session.read_state()
	await _open_storage("save")
	await _click_button(_main.storage.list.get_node("manual_2"))
	_check(_main.storage.status.text.contains("保存成功"), "save shop resolution")
	await _click("关闭 · Esc")
	await _click("营业")
	await _capture("return_room")
	entry = _find_button(_main, "回房")
	_check(entry != null and not entry.disabled and panel._buttons.size() == 1, "settled shop offers direct room entry")
	if entry == null: _finish(); return
	await _click_button(entry)
	_check(_session.read_state().phase == "private_room", "room entry works after save")
	_check(_session.read_state().cash == settled.cash and _session.read_state().summaries == settled.summaries, "room entry does not settle fees twice")
	# Reload each saved phase; closing/reopening the shop must still permit continuation.
	for slot in [1, 2]:
		_main.storage.open("load")
		await _frames()
		await _click_button(_main.storage.list.get_node("manual_%d" % slot))
		await _click_button(_main.storage.confirm.get_ok_button())
		await _frames()
		_check(_session.read_state().phase == ("night_resolution" if slot == 1 else "shop_resolution"), "restores saved phase %d" % slot)
		await _click("营业")
		if slot == 1:
			await _click_button(_find_button(_main, "查看夜间结算"))
			await _click("合上今夜的账册")
			await _click("营业")
		await _click_button(_find_button(_main, "回房"))
		_check(_session.read_state().phase == "private_room", "loaded save can enter room %d" % slot)
		_check(_session.read_state().cash == settled.cash, "loaded path does not double charge fees %d" % slot)
	await _capture("loaded_room")
	_finish()

func _finish() -> void:
	print("SEALED NAVIGATION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
