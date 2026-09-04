extends "res://tests/m4_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "m5_1600" if "wide" in OS.get_cmdline_user_args() else "m5_1280"
	if "wide" in OS.get_cmdline_user_args(): root.size = Vector2i(1600, 900)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	_check(_session != null, "M5生产主场景加载")
	if _session == null:
		quit(1)
		return
	await _third_m5()
	await _capture("01_mirror_warning")
	_check(_session.risk_model().body.contains("关门前"), "首次入库规则明确可读")
	await _click("盖好红布 · 10分钟")
	_check(_session.risk_model().body.contains("红布已盖"), "实际鼠标遮盖成功")
	await _capture("02_covered")
	await _finish_m5()
	_check(_session.read_state().summaries.back().outcome == "mirror_safe", "真实UI安全三夜闭环")
	await _capture("03_safe_summary")
	await _click("合卷")
	await _new_m5()
	await _third_m5()
	await _finish_m5()
	_check(not _session.read_state().risk_pending.is_empty(), "未处理进入可挽救警告")
	await _capture("04_lethal_warning")
	await _click("低头退开，将红布覆上")
	_check(_session.read_state().summaries.back().outcome == "mirror_survived", "真实UI保命分支")
	await _capture("05_survived")
	await _new_m5()
	await _third_m5()
	await _finish_m5()
	await _click("抬眼看向镜中人")
	_check(_session.read_state().phase == "dead", "明确警告后主动选择死亡")
	await _capture("06_death_record")
	await _click("营业")
	await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
	_check(_session.read_state().phase == "dead", "真实UI读取死亡存档不能复活")
	await _click("鬼货与绝当录")
	var panel := _main.find_child("RiskPanel", true, false) as RiskPanel
	var archive_label: Label = panel._history
	var scroll := panel._column.get_parent() as ScrollContainer
	scroll.ensure_control_visible(archive_label)
	await _frames()
	await _capture("07_archive")
	await _new_m5()
	_check(_session.read_state().death_archive.size() == 1, "真实UI新游戏保留绝当录")
	await _click("鬼货与绝当录")
	await _capture("08_new_run_archive")
	print("M5 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _third_m5() -> void:
	for night in 2:
		await _resolve_events()
		await _click("营业")
		await _click("开铺")
		await _finish_m5()
		await _click("进入下一夜")
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("鉴定")
	await _click("识货：观察镜缘 · 5分钟")
	await _click("辨规：读镜背刻字 · 5分钟")
	await _capture("mirror_appraisal")
	await _click("交易")
	_find_trade(_main)._price.value = 54
	await _click("正式报价并收购")
	_check(_session.risk_model().held_ids.size() == 1, "真实铜镜成交并自动打开鬼货处理")

func _finish_m5() -> void:
	await _click("营业")
	await _click("等到封铺（消耗全部剩余时间）")
	await _click("合上今夜的账册")

func _new_m5() -> void:
	await _click("营业")
	await _click("新游戏")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
