extends "res://tests/m6_ui_smoke.gd"

# Only fixture setup chooses seeds. All gameplay below uses viewport mouse input.
func _run() -> void:
	_capture_prefix = "m7_1600" if "wide" in OS.get_cmdline_user_args() else "m7_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m7_manifest.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	_check(_session != null, "M7生产界面启动")
	if _session == null: quit(1); return
	var helper := M7Tests.new()
	helper.run_def = _session.definition
	helper._expect = _check
	for variant in ["sound", "repaired"]:
		await _fresh_seed(helper.seed_for("n1_visit1", variant))
		await _click("鉴定")
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._images.size() == 2, "碗初见不显示接缝细节")
		var before := _session.read_state()
		await _click("背面"); await _click("正面")
		_check(_session.read_state() == before, "正背面切换不耗时、不换货")
		await _command("dialogue", "question", "repairs")
		await _command("appraisal", "appraise", "light")
		_check(panel._images.size() == 3 and panel._selected == variant, "侧光后立即显示对应细节")
		await _panel_capture("appraisal", "bowl_" + variant)
		before = _session.read_state()
		await _click("正面"); await _click("检查细节")
		_check(_session.read_state() == before, "复看物证不耗时")
		if variant == "repaired":
			await _command("dialogue", "question", "seam")
			await _panel_capture("dialogue", "bowl_contradiction")
			_check(not _session._counter.reason(_session._day, "pressure", _session.counter_model().active_id, "repair").is_empty(), "追问后不再重复折价")
		await _buy_and_reload()
	for variant in ["brass", "plated"]:
		await _fresh_seed(helper.seed_for("n1_visit2", variant))
		await _command("trade", "reject")
		await _wait_minutes(90)
		await _command("dialogue", "question", "material")
		await _command("appraisal", "appraise", "magnet")
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._images.size() == 2, "磁针不解锁划痕图")
		await _panel_capture("appraisal", "holder_magnet_" + variant)
		if variant == "plated": await _command("dialogue", "question", "magnetic_core")
		await _command("appraisal", "appraise", "scratch")
		_check(panel._images.size() == 3, "查看划痕才显示材质细节")
		await _panel_capture("appraisal", "holder_scratch_" + variant)
		await _buy_and_reload()
	for variant in ["sound", "flawed"]:
		for situation in ["ordinary", "urgent"]:
			await _fresh_seed(helper.seed_for("n2_visit1", variant, situation))
			await _finish_m5(); await _click("进入下一夜")
			var before := _session.read_state()
			await _reload_ui()
			_check(before == _session.read_state(), "重载第二夜开铺前不换货或处境")
			await _resolve_events(); await _click("营业"); await _click("开铺")
			await _command("dialogue", "question", "reason")
			await _command("dialogue", "question", "deadline")
			_check(_active_visit().item.revealed_clue_ids.is_empty(), "急售口供不产生机芯物证")
			await _panel_capture("dialogue", "watch_" + situation + "_" + variant)
			await _command("appraisal", "appraise", "observe")
			await _command("appraisal", "appraise", "inspect")
			await _panel_capture("appraisal", "watch_movement_" + situation + "_" + variant)
			if variant == "flawed": await _command("trade", "pressure", "flaw")
			var reserve := _active_visit().trade.reserve_price
			var patience := _active_visit().trade.patience
			await _command("trade", "concession")
			_check(_active_visit().trade.reserve_price == reserve - (5 if situation == "urgent" else 0), "UI急售仅有一次独立5元优惠")
			_check(_active_visit().trade.patience == patience - (1 if situation == "ordinary" else 0), "普通客催价损失一份耐心")
			await _panel_capture("trade", "watch_price_" + situation + "_" + variant)
			await _buy_and_reload()
	print("M7 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func _fresh_seed(seed_value: int) -> void:
	await _new_m5()
	_session._day.state.run_seed = seed_value
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, _session._counter.catalog)
	_session.changed.emit()
	await _resolve_events(); await _click("营业"); await _click("开铺")

func _active_visit() -> CustomerVisit:
	return _session._counter.customers.active(_session._day.state)

func _command(panel: String, command: String, detail := "") -> void:
	await _click(CounterScreen.PANEL_TITLES[panel])
	if panel == "trade":
		await _click_trade_intent(command, detail)
		return
	for row in _session.counter_model()[panel].buttons:
		if row.command == command and row.detail == detail:
			await _click(row.label)
			return
	_check(false, "缺少操作：" + command + "/" + detail)

func _wait_minutes(minute: int) -> void:
	for guard in 110:
		if _session.read_state().game_minutes >= minute: return
		await _resolve_events(); await _click("营业")
		await _click("等待 · 60 分钟" if minute - int(_session.read_state().game_minutes) >= 60 else "歇一歇 · 5 分钟")
	_check(false, "等待在有限步内结束")

func _reload_ui() -> void:
	await _click("营业"); await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())

func _buy_and_reload() -> void:
	await _click("交易")
	_find_trade(_main)._price.value = _active_visit().trade.reserve_price
	await _click("正式报价并收购")
	_check(_session.read_state().inventory_instances.size() == 1, "样板通过真实界面成交")
	await _finish_m5()
	_check(_session.read_state().phase == "day_summary", "样板正常结算息费并保存")
	var before := _session.read_state()
	await _reload_ui()
	_check(_session.read_state() == before, "真实写盘读档完整保留问答、证据、优惠与成交")

func _panel_capture(panel_id: String, label: String) -> void:
	await _click(CounterScreen.PANEL_TITLES[panel_id])
	var panel := _main.find_child(panel_id.capitalize() + "Panel", true, false) as IntentPanel
	var scroll := panel._column.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0
	await _frames()
	_check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "抽屉内容没有横向溢出")
	await _capture(label)
