extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("MIRROR UI TIMEOUT"); quit(1))
	_capture_prefix = "mirror_chapter_1600" if "wide" in OS.get_cmdline_user_args() else "mirror_chapter_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/mirror_chapter_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/mirror_chapter/runtime/ui_auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/mirror_chapter/runtime/ui_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false
	_session.definition._seed = 42
	driver.check = _check
	driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.definition.id == "mirror_chapter" and narrative.visible, "formal title starts chapter and opening")
	await _capture("00_opening")
	for night in [1, 2]:
		driver.open(_session); driver.work(_session, "stop"); driver.finish(_session, "covered")
	driver.open(_session)
	var v := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "acquire mirror")
	await receipts()
	await _click("鬼货与绝当录")
	var before_cloth := _session._day.state.game_minutes
	var before_actions := _session._day.state.action_count
	await _click("盖好红布")
	await _capture("01_free_cloth")
	await _click("揭开红布")
	_check(_session._day.state.game_minutes == before_cloth and _session._day.state.action_count == before_actions, "cloth clicks are free")
	await _click("翻查顾先生的用镜短记 · 5分钟")
	_check("wm_notes" in _session._day.state.narrative_flags, "actual investigation button grants known notes")
	await _capture("01_usage_notes")
	_check(_session.bell_command("wait").ok, "next guest")
	await receipts()
	await _click("鬼货与绝当录")
	await _click("借镜照一照来客 · 5分钟")
	_check(not _session.mirror_pending() and _session.risk_model().body.contains("取药单"), "ordinary vision readable")
	await _capture("02_medicine_glimpse")
	await _click("对话")
	await _click("问药铺柜前那张取药单 · 5分钟")
	await _capture("03_verified_question")
	await _click("交易")
	await _click("请他为急用再让5银元 · 5分钟 · 议价一轮")
	v = _session._counter.customers.active(_session._day.state)
	_check(v.concession_used, "actual concession shares benefit")
	_check(_session.counter_command("reject", v.visit_id).ok, "finish sample")
	while _session._day.state.game_minutes < 360:
		v = _session._counter.customers.active(_session._day.state)
		if v != null:
			var role: String = VarietySaveCodec.selection(_session._day.state, v.visit_id).get("seven_role", "")
			_check(_session.counter_command("pawn" if role == "pawn" else "reject", v.visit_id, "", 40 if role == "pawn" else 0).ok, "serve guest")
		else: _session.bell_command("wait")
	await receipts()
	await _click("鬼货与绝当录")
	await _capture("04_husband_limit")
	_check(not _session.mirror_command("midnight_old_ticket", "peek").ok, "single night limit enforced")
	await work_tail()
	driver.finish(_session, "covered")
	for night in range(4, 8):
		driver.open(_session)
		if night == 4: await work_tail()
		else: driver.work(_session, "covered")
		await receipts()
		await _click("鬼货与绝当录")
		if night == 4:
			await _click("按典物号查旧当存根 · 10分钟")
			await _capture("05_old_ticket")
			await _click("托街坊核实柳巷旧事 · 15分钟")
		if night == 6:
			await _click("对照货郎旧账与柳巷住户 · 15分钟")
			await _click("核对顾先生的两册记录 · 10分钟")
		if night == 7:
			await _click("查那一日夹页里的旁记 · 10分钟")
			await _capture("06_gu_motive")
			await _click("把地址另抄下来，继续查")
			_check("wm_seek" in _session._day.state.narrative_flags, "chapter decision reached through UI")
			await _capture("07_chapter_choice")
		driver.finish(_session, "covered")
	_check(_session._day.state.phase == &"run_ended", "real seven-night finish")
	await _click("营业")
	await _capture("08_finish")
	print("MIRROR CHAPTER UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func work_tail() -> void:
	for step in 150:
		if _session._day.state.game_minutes >= 480: return
		var v := _session._counter.customers.active(_session._day.state)
		if v != null:
			var role: String = VarietySaveCodec.selection(_session._day.state, v.visit_id).get("seven_role", "")
			var command := "pawn" if role == "pawn" else "offer" if role in ["pen4", "pen5"] else "reject"
			_check(_session.counter_command(command, v.visit_id, "", 40 if command == "pawn" else v.trade.asking_price if command == "offer" else 0).ok, "tail trade")
		else: driver.action(_session, "short_task")
	_check(false, "bounded work")
