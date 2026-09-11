extends "res://tests/integrated_ui_smoke.gd"

func _expert_dialog() -> ConfirmationDialog:
	for node in _main.find_children("*", "ConfirmationDialog", true, false):
		if node.visible and node.title == "委托行家": return node
	return null

func _seek_dialog() -> ConfirmationDialog:
	for node in _main.find_children("*", "ConfirmationDialog", true, false):
		if node.visible and node.title == "寻配茶盏": return node
	return null

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("GOODS UI TIMEOUT"); quit(1))
	_capture_prefix = "goods_1600" if "wide" in OS.get_cmdline_user_args() else "goods_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/goods_expertise_start.tscn").instantiate(); root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session.definition.id == "goods_expertise_seven" and _session.content_version == 21, "default v21")
	_session._save.library.path = "res://.godot/qa/goods/ui_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/goods/ui_fixture.json"))
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/goods/ui_metadata.json"))
	var codec := SaveCodec.new(); var state := codec.decode(data, _session.definition, 21, driver.catalog, true)
	_check(state != null, "valid actual play checkpoint " + codec.error_message)
	if state == null: quit(1); return
	var lib := _session._save.library
	_check(lib.write_entry("manual/1", state, _session.definition, 21, driver.catalog), "write manual fixture")
	_check(lib.adopt(lib.read_entry("manual/1"), _session), "restore manual fixture")
	driver.drain(_session); await receipts(); await _click("营业")
	var seek: Button
	for button in _main.find_children("*", "Button", true, false):
		if button.text.begins_with("寻配茶盏") and button.is_visible_in_tree() and not button.disabled: seek = button; break
	_check(seek != null, "owned observed cup seeking entry")
	if seek != null:
		await _capture("01_seeking")
		var cash := _session._day.state.cash
		await _click_button(seek)
		await _capture("01b_seek_confirmation")
		await _click_button(_seek_dialog().get_cancel_button())
		_check(_session._day.state.cash == cash and not PreparationService.used(_session._day.state, "seek", 6), "cancel seeking preview costs nothing")
		await _click_button(seek); await _click_button(_seek_dialog().get_ok_button())
		_check(_session._day.state.cash == cash - 3 and PreparationService.used(_session._day.state, "seek", 6), "real seeking charges once")
	await _click("开铺营业"); driver.drain(_session)
	await receipts(); await _click("库存")
	await _click("请行家鉴赏品质 · 6银元 / 20分钟")
	await _capture("02_expert_confirmation")
	var dialog := _expert_dialog()
	var cash := _session._day.state.cash; var minute := _session._day.state.game_minutes
	await _click_button(dialog.get_cancel_button())
	_check(_session._day.state.cash == cash and _session._day.state.game_minutes == minute, "cancel expert costs nothing")
	await _click("请行家鉴赏品质 · 6银元 / 20分钟")
	dialog = _expert_dialog(); await _click_button(dialog.get_ok_button())
	_check(_session._day.state.cash == cash - 6 and _session._day.state.game_minutes == minute + 20, "real expert fee and time")
	await _capture("03_fan_result")
	var pair_entry := {}
	for entry in _session.counter_model().inventory.buttons:
		if entry.command == "expert_pair" and entry.target_id in meta.cup_ids and entry.detail in meta.cup_ids: pair_entry = entry
	_check(not pair_entry.is_empty(), "pair expert entry")
	await _click(pair_entry.label)
	dialog = _expert_dialog(); await _capture("04_pair_confirmation"); await _click_button(dialog.get_ok_button())
	_check(GoodsExpertise.certificate(_session._day.state, meta.cup_ids).result == "matched", "real original pair result")
	await _capture("05_pair_result")
	for step in 80:
		driver.drain(_session)
		var v := _session._counter.customers.active(_session._day.state)
		if v != null: _session.counter_command("reject", v.visit_id)
		elif _session._commerce.trip_reason(_session._day, driver.catalog.get_definition("buyers", "buyer_collector")).is_empty(): break
		else: _session.execute("short_task")
	await receipts(); await _click("库存"); await _click("卖货"); await _click("选择买家 · 瓷器收藏客")
	await _click("选中全部可售货物")
	var panel := _main.find_child("InventoryPanel", true, false) as InventoryPanel
	if panel == null:
		for p in _main.find_children("*", "", true, false):
			if p is InventoryPanel: panel = p; break
	var pair_box: Button
	for b in panel._sale_view.get_children():
		if b is CheckBox and b.text.begins_with("原配茶盏"): pair_box = b; break
	_check(pair_box != null and not pair_box.button_pressed, "explicit pair initially unchecked")
	if pair_box == null: quit(1); return
	await _click_button(pair_box)
	_check(panel._sale_view._total.text.contains("原配加价 21") and panel._sale_view._total.text.contains("预计收款105"), "one consistent pair total")
	await _capture("06_pair_manifest")
	cash = _session._day.state.cash; minute = _session._day.state.game_minutes
	await _click("完成交易 · 20分钟")
	_check(_session._day.state.cash == cash + 105 and _session._day.state.game_minutes == minute + 20, "pair sale UI matches preview")
	await _capture("07_pair_receipt")
	await receipts()
	for action in ["close_shop", "wait_until_seal"]: driver.drain(_session); _check(_session.execute(action).ok, action)
	var before := _session._day.state.to_read_model()
	var bytes := FileAccess.get_file_as_bytes(lib.path)
	lib.fail_write = true
	_check(not _session.execute("resolve_night").ok and _session._day.state.to_read_model() == before and FileAccess.get_file_as_bytes(lib.path) == bytes, "expert and pair sale night disk rollback")
	lib.fail_write = false
	for action in ["resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]: driver.drain(_session); _check(_session.execute(action).ok, action)
	var file := FileAccess.open("res://.godot/qa/goods/" + _capture_prefix + "_pair.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(_session._day.state, 21))); file.close()
	print("GOODS UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)
