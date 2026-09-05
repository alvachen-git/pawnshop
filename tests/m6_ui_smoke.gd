extends "res://tests/m5_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "m6_1600" if "wide" in OS.get_cmdline_user_args() else "m6_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m6_manifest.json"
	if "production" in OS.get_cmdline_user_args():
		_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m7_manifest.json"
		_capture_prefix += "_production"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	_check(_session != null, "M6生产界面启动")
	if _session == null: quit(1); return
	await _capture("01_debt_contract")
	await _resolve_events()
	await _click("账本")
	await _capture("02_ledger")
	_check(_session.counter_model().ledger.body.contains("本金 300"), "账本持续显示本金和息费")
	await _click("营业"); await _click("开铺"); await _click("交易")
	_find_trade(_main)._price.value = 95
	await _click("正式报价并收购")
	await _finish_m5()
	_check(_session.read_state().cash == 0 and _session.read_state().fee_arrears[0].amount == 3, "真实买卖造成短款3")
	await _capture("03_shortfall_summary")
	await _click("进入下一夜"); await _resolve_events(); await _click("账本")
	await _capture("04_due_tonight")
	_check(_session.counter_model().ledger.body.contains("今夜到期"), "次夜明确展示到期提醒")
	await _click("营业"); await _click("开铺"); await _finish_m5()
	_check(_session.read_state().phase == "bankrupt", "到期未缴触发真实经营失败")
	await _capture("05_bankrupt")
	await _new_m5()
	_check(_session.read_state().bankruptcy_archive.size() == 1, "新经营保留破铺录")
	await _third_m5()
	await _click("盖好红布 · 10分钟")
	await _midnight_ui()
	await _capture("06_mirror_invitation")
	await _click("揭开红布 · 5分钟")
	await _click("借镜照一照来客 · 5分钟")
	await _capture("07_first_glimpse")
	_check(_session.risk_model().body.contains("正在回头"), "追看前警告已显示")
	await _click("收回视线")
	await _click("交易")
	var pressure_label := ""
	for row in _session.counter_model().trade.buttons:
		if row.command == "pressure" and row.detail == "flaw": pressure_label = row.label
	await _click(pressure_label)
	_find_trade(_main)._price.value = 20
	await _click("正式报价并收购")
	_check(_session.read_state().inventory_instances.size() == 2, "铜镜证据帮助真实议价收表")
	await _click("鬼货与绝当录"); await _click("盖好红布 · 10分钟")
	await _finish_m5()
	_check(_session.read_state().summaries.back().outcome == "mirror_safe", "初窥后收手与覆镜可平安收尾")
	await _capture("08_safe_summary")
	await _new_m5(); await _third_m5()
	await _midnight_ui()
	await _click("借镜照一照来客 · 5分钟")
	await _click("看清那张旧当票 · 5分钟")
	await _capture("09_old_ticket")
	var id: String = _session.risk_model().held_ids[0]
	await _click("库存")
	await _click("泣血铜镜 → 夜半收镜客：90 · 10分钟")
	_check(_session.read_state().inventory_instances[0].ownership_state == "sold", "真实出售已经追看的铜镜")
	await _finish_m5()
	_check(_session.read_state().risk_pending == id, "出售后纠缠仍在")
	await _capture("10_pursuit_crisis")
	await _click("回头看向身后的人")
	_check(_session.read_state().phase == "dead" and _session.read_state().death_archive.size() == 1, "预警后继续回头进入死亡终局")
	await _capture("11_death")
	await _click("营业"); await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
	_check(_session.read_state().phase == "dead", "真实UI重载死亡终局")
	await _click("鬼货与绝当录")
	await _capture("12_history")
	print("M6 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func _midnight_ui() -> void:
	while _session.read_state().game_minutes < 360:
		await _resolve_events()
		await _click("营业")
		await _click("等待 · 60 分钟" if 360 - int(_session.read_state().game_minutes) >= 60 else "歇一歇 · 5 分钟")
	await _resolve_events()
	await _click("鬼货与绝当录")
	_check(not _session.risk_model().attention_id.is_empty(), "子时来客的邀请可见")
