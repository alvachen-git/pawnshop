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
	_check(panel._body.text.contains("掌眼所见") and panel._body.text.contains("尚愿意交谈"), "物品、态度和掌眼证据可见")
	_check(panel._amount_caption.text == "出价（银元）" and not panel._body.text.contains("剩余议价") and not panel._body.text.contains("最迟留到") and not panel._body.text.contains("耐心"), "按确认方案隐藏剩余轮次，保留出价与客人态度")
	_check(panel._metrics.get_child_count() == 2 and panel._purchase_mode.button_pressed, "摘要只保留要价与证据估值，默认收购")
	_check(_no_system_parameters(panel), "可见文本与悬停提示不显示系统参数")
	_check(not panel._bargain_popup.is_visible_in_tree() and not _has_visible_bargain_content(panel), "折叠态不显示议价说辞或证据")
	_check(panel._price.is_visible_in_tree() and not panel._pawn_price.is_visible_in_tree() and panel._submit.is_visible_in_tree() and not panel._pawn_submit.is_visible_in_tree(), "收购只显示一套金额和主按钮")
	_check(_visible_controls_fit_panel(panel) and _visible_trade_controls_have_hit_area(panel), "折叠态控件在面板内且可清楚点击")
	_check(_fully_visible(panel._submit) and _fully_visible(panel._reject), "折叠态主按钮和拒收完整可见，无须滚动")
	await _click_button(panel._pawn_mode)
	_check(not panel._price.is_visible_in_tree() and panel._pawn_price.is_visible_in_tree() and not panel._submit.is_visible_in_tree() and panel._pawn_submit.is_visible_in_tree(), "活当复用同一位置的金额和主按钮")
	_check(_fully_visible(panel._pawn_submit), "活当主按钮完整可见")
	_check(_fully_visible(panel._terms), "活当期限与息费完整可见")
	await _capture("01b_pawn")
	await _click_button(panel._purchase_mode)
	_check(panel._price.is_visible_in_tree() and panel._submit.is_visible_in_tree(), "切回收购恢复同一套操作位")
	await _capture("01_compact")
	await _click_button(panel._bargain_toggle)
	_check(panel._bargain_popup.visible, "真实点击展开商量价钱")
	_check(_no_system_parameters(panel), "展开议价后仍不显示系统参数")
	var evidence := panel.find_child("Evidence_shape", true, false) as Label
	_check(evidence != null and evidence.text.contains("尚不能判断完整性"), "完整证据显示，不依赖悬停")
	_check(_visible_controls_fit_panel(panel) and _visible_trade_controls_have_hit_area(panel), "展开后的议价内容不横向溢出且可点击")
	var first := _command_button("pressure", "shape")
	first.grab_focus()
	var scroll := _scroll_for(first)
	scroll.ensure_control_visible(first)
	await _frames()
	_check(first.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and not first.text.contains("…"), "议价说辞自动换行，无硬截断")
	_check(first.size.x <= scroll.size.x and evidence.size.x <= scroll.size.x, "说辞与证据不造成横向溢出")
	await _capture("02_evidence")
	_check(_fully_visible(panel._submit) and _fully_visible(panel._bargain_toggle), "展开议价时主按钮和收折入口仍完整可见")
	await _click_button(panel._bargain_toggle)
	_check(not panel._bargain_popup.visible and _fully_visible(panel._submit), "点击收折后金额和主动作不残留滚动偏移")
	await _click_button(panel._bargain_toggle)
	var before := _session.read_state()
	await create_timer(0.1).timeout
	_check(_session.read_state() == before, "阅读和滚动免费")
	await _click_button(_command_button("belittle", ""))
	_check(helper.active(_session).trade.asking_price == 69 and helper.active(_session).trade.rounds_left == 2, "真实点击试探降低要价并扣一轮")
	_check(not (_main.find_child("TradeReceipt", true, false) as TradeReceiptView).visible, "试探不显示成交凭据")
	var used := _command_button("belittle", "")
	_check(used.disabled and used.text.contains("已试探"), "一次性按钮清楚标注")
	await _click_button(panel._bargain_toggle)
	scroll.scroll_vertical = 0
	panel._content_scroll.ensure_control_visible(panel._feedback)
	await _frames()
	_check(panel._feedback.text.contains("72 → 69") and not panel._feedback.text.contains("底价"), "只显示真实公开要价变化")
	_check(_fully_visible(panel._feedback) and _fully_visible(panel._submit), "议价反馈与主操作均可完整阅读：反馈 %s，滚动区域 %s" % [panel._feedback.get_global_rect(), panel._content_scroll.get_global_rect()])
	await _capture("03_yielding")
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
	panel._content_scroll.ensure_control_visible(panel._feedback)
	await _frames()
	await _capture("04_proud")
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
	var panel := _find_trade(_main)
	if panel != null and not panel._bargain_popup.visible:
		panel.open_bargain_menu()
	for child in panel._buttons.get_children():
		if child is Button and child.get_meta("trade_command", "") == command and child.get_meta("trade_detail", "") == detail:
			return child
	return null

func _scroll_for(control: Control) -> ScrollContainer:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor
		ancestor = ancestor.get_parent()
	return null

func _has_visible_bargain_content(panel: TradePanel) -> bool:
	for child in panel._buttons.get_children():
		if child is Control and child.is_visible_in_tree():
			return true
	return false

func _visible_controls_fit_panel(panel: TradePanel) -> bool:
	var bounds := panel.get_global_rect().grow(1.0)
	for control in _visible_controls(panel):
		var rect := control.get_global_rect()
		if rect.size.x > 0.0 and (rect.position.x < bounds.position.x or rect.end.x > bounds.end.x):
			return false
	return true

func _visible_trade_controls_have_hit_area(panel: TradePanel) -> bool:
	for control in _visible_controls(panel):
		if control is Button or control is SpinBox:
			if control.size.y < 40.0:
				return false
	return true

func _visible_controls(node: Node) -> Array[Control]:
	var controls: Array[Control] = []
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			controls.append(child)
		controls.append_array(_visible_controls(child))
	return controls

func _fully_visible(control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	var bounds := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		# Scroll offsets use integers while the panel anchors can be fractional.
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().grow(1.01).encloses(bounds):
			return false
		ancestor = ancestor.get_parent()
	return root.get_visible_rect().encloses(bounds)

func _no_system_parameters(panel: TradePanel) -> bool:
	for control in _visible_controls(panel):
		var text := control.tooltip_text
		if control is Label or control is Button:
			text += control.text
		# Owner confirmed the hidden-rounds presentation on 2026-09-11.
		for token in ["剩余议价", "轮次", "耐心", "最迟留到", "议价一轮", "底价"]:
			if text.contains(token): return false
	return true
