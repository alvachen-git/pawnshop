extends "res://tests/m6_ui_smoke.gd"

var driver = preload("res://tests/integrated_test_driver.gd").new()
var narrative: NarrativeScene

func _run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("PREPARATION UI TIMEOUT"); quit(1))
	_capture_prefix = "preparation_1600" if "wide" in OS.get_cmdline_user_args() else "preparation_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene") if "default" in OS.get_cmdline_user_args() else "res://scenes/prepared_seven.tscn").instantiate()
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
	_check(OpeningPreparation.enabled(_session.definition) and narrative.visible, "new game opens story with preparation rules")
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
	await _click("营业")
	var before_prep := _session._day.state.cash
	await _capture("04a_second_preparation")
	var preparation_panel := _main.find_child("DayFlowPanel", true, false) as DayFlowPanel
	var attract_button: Button = preparation_panel._buttons.prep_attract
	_check(attract_button.text == "招揽客人 · 3大洋 · 准备1次" and not attract_button.text.contains("增加"), "concise preparation label")
	_check(attract_button.tooltip_text.contains("增加1位"), "preparation effect in tooltip")
	var motion := InputEventMouseMotion.new()
	motion.position = attract_button.get_global_rect().get_center()
	root.push_input(motion, true)
	await create_timer(1.0).timeout
	await _capture("04a_hover_details")
	await prep_click("prep_choose_category")
	await _capture("04b_categories")
	await prep_click("prep_cancel_category")
	_check(_session._day.state.cash == before_prep and PreparationService.count(_session._day.state) == 0, "cancel category is free")
	await prep_click("prep_attract")
	await prep_click("prep_tea")
	_check(_session._day.state.cash == before_prep - 8 and _session._day.state.visits.size() == 7, "visible costs and extra customer")
	await _capture("04c_prepared")
	await _click_button(_main.find_child("CloseDrawerButton", true, false))
	await _click("账本")
	_check(_main.find_child("LedgerPanel", true, false).is_visible_in_tree(), "ledger actually opened")
	await _capture("04d_preparation_ledger")
	await _click_button(_main.find_child("CloseDrawerButton", true, false))
	await _click("营业")
	await _click("开铺营业")
	driver.finish(_session, "covered")
	if "default" in OS.get_cmdline_user_args():
		print("DEFAULT PREPARATION UI: %d assertions, %d failures" % [_assertions, _failures])
		_main.queue_free(); await process_frame
		quit(0 if _failures == 0 else 1)
		return
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
	await prep_click("prep_investigate")
	await prep_click("prep_choose_category")
	await prep_click("prep_category/stationery")
	await _capture("08_preparation")
	await _click("开铺营业")
	driver.work(_session, "covered"); driver.finish(_session, "covered")
	await _click("营业")
	await prep_click("prep_choose_category")
	await prep_click("prep_category/watches")
	await prep_click("prep_visitors")
	await prep_click("read_seven_notes")
	await _capture("08b_intel")
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
	print("PREPARATION UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func narrative_choice(id := "") -> void:
	await _frames()
	var button: Button = narrative._choices.get_child(0) if id.is_empty() else narrative._choices.get_node("Choice_" + id)
	await _click_button(button)
	await _frames()

func receipts() -> void:
	await _frames()
	for name in ["TradeReceipt", "CustomerDeparture"]:
		var receipt := _main.find_child(name, true, false) as TradeReceiptView
		for step in 50:
			if not receipt.visible: break
			await _click_button(receipt._primary)
			await _frames()

func prep_click(id: String) -> void:
	print("PREPARATION UI click ", id)
	var panel := _main.find_child("DayFlowPanel", true, false) as DayFlowPanel
	_check(panel != null and panel._buttons.has(id), "preparation button " + id)
	if panel == null or not panel._buttons.has(id): return
	await _click_button(panel._buttons[id])
	print("PREPARATION UI done ", id)
