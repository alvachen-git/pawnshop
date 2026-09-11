extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("PAWN CHANCE UI TIMEOUT"); quit(1))
	_capture_prefix = "pawn_chance_1600" if "wide" in OS.get_cmdline_user_args() else "pawn_chance_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/pawn_chance/fixtures.json"))
	for chance in ["20", "50"]:
		_main = load("res://scenes/start.tscn").instantiate()
		_main.get_node("Bootstrap").manifest_path = "res://data/pawn_chance_manifest.json"
		_main.get_node("Bootstrap").save_path = "user://pawn_chance_seven/autosave_v20.json"
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		_check(_session.definition.id == "pawn_chance_seven" and _session.content_version == 20, "legacy v20 entry")
		_session._save.library.path = "res://.godot/qa/pawn_chance/ui_%d.json" % Time.get_ticks_usec()
		_main.title_menu.configure(true, false)
		driver.check = _check; driver.catalog = _session._counter.catalog
		narrative = _main.get_node("CounterScreen/NarrativeScene")
		await _frames(); await _click_button(_main.title_menu.buttons[0])
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/pawn_chance/" + fixtures[chance].file))
		var codec := SaveCodec.new()
		var state := codec.decode(payload, _session.definition, 20, driver.catalog, true)
		_check(state != null, "real pre-open checkpoint")
		if state == null: quit(1); return
		var lib := _session._save.library
		_check(lib.write_entry("manual/1", state, _session.definition, 20, driver.catalog), "manual snapshot")
		_check(lib.adopt(lib.read_entry("manual/1"), _session), "load through library")
		driver.drain(_session); driver.action(_session, "open_shop"); driver.drain(_session)
		while not PawnReturnService.current(_session._day.state).is_empty():
			_session.counter_command("redeem", PawnReturnService.current(_session._day.state).id)
		var current: CustomerVisit
		for step in 180:
			current = _session._counter.customers.active(_session._day.state)
			if current != null and current.visit_id == fixtures[chance].visit_id: break
			if current != null: _session.counter_command("reject", current.visit_id)
			else: driver.action(_session, "short_task")
			driver.drain(_session)
		_check(current != null and current.visit_id == fixtures[chance].visit_id, "actual ordinary caller")
		await receipts(); await _click("交易")
		var panel := _find_trade(_main)
		var expected: String = (driver.catalog.get_definition("customers", current.customer_id) as CustomerDefinition).persona.pawn_background
		_check(panel._body.text.contains(expected), "background rendered before loan")
		for hidden in ["20%", "50%", "80%", "sample_three", "赎回概率", "贫穷档"]: _check(not panel._body.text.contains(hidden), "no hidden result " + hidden)
		_check(panel._body.text.contains("期限3夜") and panel._body.text.contains("10%"), "contract remains visible")
		await _capture(chance + "_background")
		panel._pawn_price.value = maxi(1, roundi(current.trade.reserve_price * 0.5))
		var ancestor := panel._pawn_submit.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(panel._pawn_submit)
			ancestor = ancestor.get_parent()
		await _frames(); await _capture(chance + "_loan_form")
		await _click("正式报价并活当")
		await create_timer(0.35).timeout
		await _frames(); await _capture(chance + "_receipt")
		_check(current.status == "pawned" and _session._day.state.pawn_tickets.back().source_visit_id == current.visit_id, "real UI issues ticket")
		await receipts(); await _click("账本")
		await _capture(chance + "_ledger")
		await _click("当票")
		await _capture(chance + "_ticket")
		_main.queue_free(); await process_frame
	print("PAWN CHANCE UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
