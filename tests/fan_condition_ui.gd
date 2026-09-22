extends "res://tests/fan_bargaining_ui.gd"

func install(stage: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/fan-condition/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(payload,_session.definition,29,_session._counter.catalog,true)
	_check(state != null,"v29 UI fixture " + codec.error_message)
	if state == null: return
	_session._day.state=state; _session.message=""
	_session.restored.emit(); _session.changed.emit()

func command_button(panel: TradePanel, command: String) -> Button:
	for child in panel._buttons.get_children():
		if child is Button and child.get_meta("trade_command", "") == command: return child
	return null

func visible_copy(node: Node) -> String:
	var result := ""
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is RichTextLabel): result += str(node.text)
	for child in node.get_children(): result += visible_copy(child)
	return result

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("CONDITION UI TIMEOUT"); quit(1))
	_capture_prefix = "fan_condition_1600" if "wide" in OS.get_cmdline_user_args() else "fan_condition_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/condition_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := DraftUIStore.new(); store.origin = _session._day.state.ghost_origin; _session._save = store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 29 and _session.definition.id == "fan_condition_ten", "unified v29")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	for stage in ["no-bench", "intact", "minor", "major"]:
		await receipts(); install(stage); await _frames()
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"appraisal"); await _frames()
		var visit := CustomerManager.new().active(_session._day.state)
		var start := _session._day.state.game_minutes
		var inspect := _find_button(_main, "检查破损 · 5分钟")
		_check(inspect != null and not inspect.disabled, "fixed inspection available")
		var desk := _find_button(_main, "送上鉴物台 · 辨认真假")
		_check(desk != null and desk.disabled == (stage == "no-bench"), "bench qualification visible")
		_check(not visible_copy(root).contains("识货：") and not visible_copy(root).contains("细看：") and not visible_copy(root).contains("复检："), "obsolete buttons absent")
		await _capture(stage + "_before")
		if stage == "no-bench":
			var before := _session.read_state()
			store.fail = true; await _click_button(inspect)
			_check(_session.read_state() == before, "actual inspection save failure rolls back")
			store.fail = false; inspect = _find_button(_main, "检查破损 · 5分钟")
		await _click_button(inspect)
		visit = CustomerManager.new().active(_session._day.state)
		_check(FanConditionService.checked(visit.item) and _session._day.state.game_minutes == start + 5, "real click inspects in five minutes")
		_check(visible_copy(root).contains(FanConditionService.TEXT[visit.item.goods.fan_condition]), "actual condition visible")
		_check(not visible_copy(root).contains("17–83"), "stale estimate absent")
		await _capture(stage + "_checked")
		if stage != "intact":
			screen.get_node("%ScreenFlowCoordinator").show_panel(&"trade"); await _frames()
			var panel := _find_trade_panel(_main)
			await _click_button(panel._bargain_toggle)
			var button := command_button(panel, "condition_pressure")
			_check(button != null and not button.disabled, "damage bargaining available")
			await _capture(stage + "_pressure")
			await _click_button(button)
			_check(_session._day.state.game_minutes == start + 10 and visit.item.goods.has("condition_pressure"), "real damage pressure five minutes")
			_check(not visible_copy(root).contains("商誉"), "hidden reputation not shown")
			_check(panel._content_scroll.get_global_rect().encloses(panel._ask_value.get_global_rect()), "asking visible at this resolution")
			await _capture(stage + "_response")
	# Full image comparison is still entered only from the desk button.
	install("minor"); await _frames()
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"appraisal"); await _frames()
	var start := _session._day.state.game_minutes
	await _click("送上鉴物台 · 辨认真假")
	var view := root.get_node_or_null("FanAppraisalOverlay") as FanAppraisalView
	_check(view != null, "desk opens without prior damage check")
	if view == null: quit(1); return
	await _frames()
	for points in [[Vector2(.72,.32),Vector2(.38,.245)], [Vector2(.74,.69),Vector2(.80,.355)]]:
		await desk_select(view.book, points[0]); await desk_select(view.fan, points[1]); await _click_button(view.note_buttons.same)
	_check(_session._day.state.game_minutes == start, "drafts free")
	await _click_button(view.stamp); await _click_button(view.choice_buttons.sound)
	await _capture("desk_commit")
	await _click_button(view.confirm_button)
	_check(_session._day.state.game_minutes == start + 10, "confirmation only ten minutes")
	await _click_button(view.close_button)
	print("FAN CONDITION UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)
