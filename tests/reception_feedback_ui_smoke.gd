extends "res://tests/bargaining_ui_smoke.gd"
func _run() -> void:
	_capture_prefix = "reception_1600" if "wide" in OS.get_cmdline_user_args() else "reception_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/seven_night.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	_session.new_run()
	var driver := SevenTestDriver.new()
	driver.check = _check
	for night in 2: driver.open(_session); driver.finish(_session)
	driver.open(_session)
	for i in 8: driver.action(_session, "short_task")
	await _click("鉴定")
	var old := _session._counter.customers.active(_session._day.state)
	_check(old.person.name == "周德顺", "seed42 third-night first visitor matches report")
	_check(_session.counter_command("appraise", old.visit_id, "observe").ok, "observe actual watch")
	while _session._day.state.game_minutes < 80: driver.action(_session, "short_task")
	await _click("交易")
	var item := _session._counter.catalog.get_definition("items", old.item.definition_id) as ItemDefinition
	var clue_id := ""
	for id in old.item.revealed_clue_ids:
		if item.find_clue(id).leverage == 0: clue_id = id; break
	_check(not clue_id.is_empty(), "observed clue is an invalid price argument")
	await _click_button(_command_button("pressure", clue_id))
	_check(old.status == "patience_exhausted" and _session._day.state.game_minutes == 85, "real pressure reproduces departure at 19:25")
	var old_message := _session.message
	_check(old_message.contains("100") and old_message.contains("耐心耗尽"), "original operation result retained")
	var next := _session._counter.customers.active(_session._day.state)
	_check(next.person.name == "陈子诚" and next.trade.patience > 0, "next customer remains willing")
	await _click("对话")
	var dialogue := _main.find_child("DialoguePanel", true, false) as DialoguePanel
	_check(dialogue._identity.text.contains("陈子诚") and not dialogue._body.text.contains(old_message) and not dialogue._body.text.contains("顾客离场"), "new dialogue has only new visitor context")
	await _capture("01_new_dialogue")
	for page in ["鉴定", "交易"]:
		await _click(page)
		var key := "appraisal" if page == "鉴定" else "trade"
		_check(_session.counter_model()[key].visual.message.is_empty(), "old response absent from " + key)
	await _click_button(_command_button("belittle", ""))
	_check(_find_trade(_main)._feedback.text == _find_trade(_main)._reaction_text({"message": _session.message, "before": next.trade.opening_price, "after": next.trade.asking_price}), "new customer's own bargaining response visible")
	await _click("对话")
	_check(dialogue._body.text.contains(_session.message) and not dialogue._body.text.contains("耐心耗尽"), "switching panels keeps only this customer's feedback")
	await _capture("02_own_response")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("RECEPTION FEEDBACK UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
