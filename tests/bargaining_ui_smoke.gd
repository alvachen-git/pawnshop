extends "res://tests/m6_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "bargaining_1600" if "wide" in OS.get_cmdline_user_args() else "bargaining_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v9.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	var helper := BargainingTests.new()
	helper.setup(_check)
	_session._day.state.run_seed = helper.seed_for("n1_visit1", "sound")
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	for id in ["observe", "base", "light"]: helper.action(_session, "appraise", id)
	await _click("交易")
	var panel := _find_trade(_main)
	_check(panel._body.text.contains("线索未必是毛病") and panel._body.text.contains("低声"), "提示和人物态度可见")
	var evidence := panel.find_child("Evidence_shape", true, false) as Label
	_check(evidence != null and evidence.text.contains("尚不能判断完整性"), "完整证据显示，不依赖悬停")
	var first := _command_button("pressure", "shape")
	first.grab_focus()
	var scroll := first.get_parent().get_parent().get_parent() as ScrollContainer
	scroll.ensure_control_visible(first)
	await _frames()
	_check(first.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and not first.text.contains("…"), "议价说辞自动换行，无硬截断")
	_check(first.size.x <= scroll.size.x and evidence.size.x <= scroll.size.x, "说辞与证据不造成横向溢出")
	await _capture("01_evidence")
	var before := _session.read_state()
	await create_timer(0.1).timeout
	_check(_session.read_state() == before, "阅读和滚动免费")
	await _click_button(_command_button("belittle", ""))
	_check(helper.active(_session).trade.asking_price == 69 and helper.active(_session).trade.rounds_left == 2, "真实点击试探降低要价并扣一轮")
	_check(not (_main.find_child("TradeReceipt", true, false) as TradeReceiptView).visible, "试探不显示成交凭据")
	var used := _command_button("belittle", "")
	_check(used.disabled and used.text.contains("已试探"), "一次性按钮清楚标注")
	scroll.scroll_vertical = 0
	await _frames()
	_check(panel._feedback.text.contains("72 → 69") and not panel._feedback.text.contains("底价"), "只显示真实公开要价变化")
	await _capture("02_yielding")
	await _click_button(_command_button("pressure", "mark"))
	_check(panel._feedback.text.contains("磨痕") and _command_button("pressure", "mark").text.contains("已谈过"), "无效理由有反驳和使用标记")
	# Force no content outcome: advance normally to the fixed firm customer.
	helper.wait_to(_session, 100)
	await _click("交易")
	var asking := helper.active(_session).trade.asking_price
	await _click_button(_command_button("belittle", ""))
	_check(helper.active(_session).trade.asking_price == asking and panel._feedback.text.contains("缘由"), "坚定人物明确拒绝而不动怒")
	helper.wait_to(_session, 360)
	await _click("交易")
	await _click_button(_command_button("belittle", ""))
	_check(panel._feedback.text.contains("脸色一沉"), "重面子人物的生气反馈")
	scroll.scroll_vertical = 0
	await _frames()
	await _capture("03_proud")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(not _main.get_node("CounterScreen/%Drawer").visible, "Esc仍能收起交易页")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("BARGAINING UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _command_button(command: String, detail: String) -> Button:
	for entry in _session.counter_model().trade.buttons:
		if entry.command == command and entry.detail == detail:
			return _find_button(_main, entry.label)
	return null
