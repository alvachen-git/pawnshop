extends "res://tests/shop_hud_ui.gd"

class BalanceStore extends GhostReplayStore:
	var fail := false
	var saved: RunState
	func save_state(state: RunState, _definition: RunDefinition, _version: int) -> bool:
		if fail: return false
		saved = RunSnapshot.copy(state)
		return true
	func load_state(_definition: RunDefinition, _version: int) -> RunState:
		return RunSnapshot.copy(saved)

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("ACTION POINTS UI TIMEOUT"); quit(1))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = "user://tests/action_points/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := BalanceStore.new()
	_session._save = store
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var status := screen.get_node("%ActionPointsStatus") as Label
	var panel := screen.get_node("%DayFlowPanel") as DayFlowPanel
	await _frames()
	_check(status.text == "行动点 —", "first night has no action points")
	var state := _session._day.state
	state.current_night_index = 2
	state.phase = &"pre_open"
	state.pending_event_id = ""
	state.cash = 281
	# This HUD fixture represents the counter after the second-night greetings.
	state.social.introduced = true
	state.social.intro_step = 3
	for flag in ["lu_visit_met", "lu_visit_terms", "lu_letters_unlocked"]:
		state.narrative_flags.append(flag)
	_session.message = ""
	_session.changed.emit()
	await _frames()
	_check(status.text == "行动点 2/2", "second night starts with two points")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"day")
		await _frames()
		_capture_prefix = "action_points_%d" % dimensions.x
		_check(panel._description.text.begins_with("下次结息费") and not panel._description.text.contains("开铺前可用行动点办事"), "opening hint removed without leading blank line")
		for removed in ["开铺前 · 现银", "今夜准备剩余", "开铺后不可返回", "本金暂不催收"]:
			_check(not panel._description.text.contains(removed), "removed copy: " + removed)
		_check(panel._description.text.contains("应付10银元") and panel._description.text.contains("第21夜"), "fee and principal deadlines retained")
		_check(panel._buttons.prep_attract.text == "招揽客人 · 3大洋 · 1行动点", "action cost label")
		_check_fields(screen, screen.get_node("%MenuButton"))
		_check(status.accessibility_name == status.text and status.tooltip_text.contains("每夜2点"), "action point accessibility and tooltip")
		await _capture("before")
		await _click_button(panel._buttons.prep_choose_category)
		await _click_button(panel._buttons.prep_cancel_category)
		_check(status.text == "行动点 2/2" and PreparationService.count(_session._day.state) == 0, "cancel category costs nothing")
	store.fail = true
	await _click_button(panel._buttons.prep_attract)
	_check(status.text == "行动点 2/2" and _session._day.state.cash == 281, "failed save rolls back points and cash in HUD")
	store.fail = false
	await _click_button(panel._buttons.prep_attract)
	_check(status.text == "行动点 1/2" and _session._day.state.cash == 278, "successful action immediately updates HUD")
	_check(not _session.message.contains("今夜准备剩余") and not _session.message.contains("现银"), "result does not repeat HUD balances")
	_check(_session.load_checkpoint().ok, "restore checkpoint through session")
	await _frames()
	_check(status.text == "行动点 1/2", "restored HUD derives balance from history")
	var one_point := RunSnapshot.copy(_session._day.state)
	var opened := _session.execute("open_shop")
	_check(opened.ok, "open with one point left: " + opened.message)
	await _frames()
	_check(status.text == "行动点 1/2" and not status.text.contains("不可用"), "opening keeps remaining points without disabled text")
	_session._day.state = one_point
	_session.restored.emit()
	_session.changed.emit()
	var learned := _session.growth_command("learn_knowledge", "gu_yansheng")
	_check(learned.ok, "knowledge shares allowance: " + learned.message)
	await _frames()
	_check(status.text == "行动点 0/2", "knowledge immediately updates shared balance")
	_check(not _session.execute("prep_tea").ok and _session.message == "今夜行动点已用完。", "exhausted allowance prevents further spending")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"day")
		await _frames()
		_capture_prefix = "action_points_%d" % dimensions.x
		_check_fields(screen, screen.get_node("%MenuButton"))
		await _capture("spent")
	_session._day.state.current_night_index = 3
	_session.changed.emit()
	await _frames()
	_check(status.text == "行动点 2/2", "new night restores allowance")
	var built := _session.growth_command("build", "display")
	_check(built.ok, "facility uses shared allowance: " + built.message)
	await _frames()
	_check(status.text == "行动点 1/2", "facility immediately updates shared balance")
	print("ACTION POINTS UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
