extends "res://tests/m6_ui_smoke.gd"

var driver = preload("res://tests/integrated_test_driver.gd").new()
var narrative: NarrativeScene

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("INTEGRATED UI TIMEOUT"); quit(1))
	_capture_prefix = "integrated_1600" if "wide" in OS.get_cmdline_user_args() else "integrated_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/integrated_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/integrated_seven/runtime/legacy_ui.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/integrated_seven/runtime/" + _capture_prefix + "_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	driver.check = _check
	driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _capture("00_title")
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.definition.id == "integrated_seven" and narrative.visible, "default new game opens integrated story")
	await _capture("01_factory")
	for step in 12: await narrative_choice()
	await narrative_choice("accounts")
	_check(narrative._text.text.contains("500"), "opening accounts use 500 principal")
	await _capture("02_accounts")
	await narrative_choice("ledger")
	await narrative_choice("ready")
	await _click("营业")
	await _click("开铺")
	await narrative_choice()
	await _click("交易")
	var v := _session._counter.customers.active(_session._day.state)
	_find_trade(_main)._price.value = v.trade.reserve_price
	await _click("正式报价并收购")
	await _capture("03_first_receipt")
	await receipts()
	await narrative_choice()
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]: driver.action(_session, action)
	await _frames()
	await _capture("04_first_room")
	await narrative_choice("photo")
	await narrative_choice("letter")
	await narrative_choice("lamp")
	await narrative_choice("settled")
	driver.action(_session, "sleep")
	await narrative_choice()
	driver.action(_session, "finish_sleep")
	driver.action(_session, "continue_run")
	driver.open(_session); driver.finish(_session, "covered")
	driver.open(_session)
	await _click("营业")
	await _click("交易")
	v = _session._counter.customers.active(_session._day.state)
	_find_trade(_main)._price.value = v.trade.asking_price
	await _click("正式报价并收购")
	await receipts()
	await _click("鬼货与绝当录")
	await _click("盖好红布 · 10分钟")
	for step in 90:
		v = _session._counter.customers.active(_session._day.state)
		if v != null and v.visit_id.ends_with("/n3_visit5"): break
		if v != null:
			var row := VarietySaveCodec.selection(_session._day.state, v.visit_id)
			if row.get("seven_role", "") == "pawn": _check(_session.counter_command("pawn", v.visit_id, "", 40).ok, "third night collateral")
			else: _session.counter_command("reject", v.visit_id)
		else: driver.action(_session, "short_task")
	await receipts()
	await _click("鬼货与绝当录")
	await _capture("05_mirror_invitation")
	await _click("揭开红布 · 5分钟")
	var clues := v.item.revealed_clue_ids.duplicate()
	await _click("借镜照一照来客 · 5分钟")
	_check(v.item.revealed_clue_ids == clues, "visible mirror flow gives no watch evidence")
	await _capture("06_old_ticket")
	await _click("看清那张旧当票 · 5分钟")
	_session.counter_command("reject", v.visit_id)
	await _click("鬼货与绝当录")
	await _click("盖好红布 · 10分钟")
	driver.work(_session, "covered")
	await receipts()
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep"]: driver.action(_session, action)
	await _click("鬼货与绝当录")
	await _capture("07_personal_crisis")
	await _click("垂下眼，护住命灯")
	driver.action(_session, "finish_sleep"); driver.action(_session, "continue_run")
	await _click("营业")
	await _click("调查收货消息 · 准备1次")
	await _click("联系收货人 · 准备1次")
	await _capture("08_preparation")
	await _click("结束准备")
	await _click("开铺")
	driver.work(_session, "covered"); driver.finish(_session, "covered")
	driver.open(_session); driver.work(_session, "covered"); driver.finish(_session, "covered")
	driver.open(_session)
	_check(_session._day.state.pawn_tickets[0].status == "redeemed", "sixth night pawn returned")
	for step in 40:
		v = _session._counter.customers.active(_session._day.state)
		if v != null: _session.counter_command("reject", v.visit_id)
		elif _session._day.state.game_minutes >= 60: break
		else: driver.action(_session, "short_task")
	await receipts()
	await _click("库存")
	await _click("卖货")
	await _click("选择买家 · 外埠文房收货人")
	await _click("选中全部可售货物")
	await _capture("09_appointment")
	await _click("完成交易 · 20分钟")
	await _capture("10_batch_receipt")
	await receipts()
	driver.finish(_session, "covered")
	driver.open(_session); driver.finish(_session, "covered")
	_check(_session._day.state.phase == &"run_ended" and _session._day.state.summaries.size() == 7, "default entrance completes all seven nights")
	await _click("夜间结算")
	await _capture("11_seven_night_end")
	print("INTEGRATED UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func narrative_choice(id := "") -> void:
	await _frames()
	var button: Button = narrative._choices.get_child(0) if id.is_empty() else narrative._choices.get_node("Choice_" + id)
	await _click_button(button)
	await _frames()

func receipts() -> void:
	await _settle_feedback()
	for name in ["TradeReceipt", "CustomerDeparture"]:
		var receipt := _main.find_child(name, true, false) as TradeReceiptView
		for step in 50:
			if not receipt.visible: break
			await _click_button(receipt._primary)
			await _frames()
