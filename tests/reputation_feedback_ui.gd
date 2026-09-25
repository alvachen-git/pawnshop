extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("REPUTATION UI TIMEOUT"); quit(1))
	_capture_prefix = "reputation_1600" if "wide" in OS.get_cmdline_user_args() else "reputation_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/reputation-feedback/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	_session.definition._randomize_seed = false; _session.definition._seed = 42
	if "wide" in OS.get_cmdline_user_args():
		for candidate in range(1, 100):
			if VarietyService.rng(candidate, "wealthy/advertise/2").randi_range(-1, 3) == 2:
				_session.definition._seed = candidate
				break
	driver.check = _check; driver.catalog = _session._counter.catalog
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 43, "latest v43 normal entry")
	driver.drain(_session)
	for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
		if command == "wait_until_seal" and _session._day.state.phase != &"closed_processing": continue
		driver.action(_session, command); driver.drain(_session)
	_check(_session._day.state.current_night_index == 2, "reach second night naturally")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var flow := screen.get_node("%ScreenFlowCoordinator") as ScreenFlowCoordinator
	flow.show_panel(&"day"); await _frames()
	var day_presenter := find_type(_main, "DayFlowPresenter") as DayFlowPresenter
	if day_presenter != null:
		var buttons := day_presenter._preparation_commands()
		var advert: Dictionary = buttons.filter(func(b: Dictionary) -> bool: return b.id == "prep_advertise")[0]
		_check(not advert.tooltip.contains("80") and advert.label.contains("30银元"), "hidden cap removed, cost retained")
	driver.action(_session, "prep_advertise")
	_check(_session.counter_model().ledger.body.contains("收铺后听回音"), "pending effect visible in ledger")
	driver.action(_session, "open_shop"); driver.drain(_session)
	driver.action(_session, "close_shop")
	if _session._day.state.phase == &"closed_processing": driver.action(_session, "wait_until_seal")
	var snapshot := _session.read_state().duplicate(true)
	flow.show_panel(&"night"); await _frames()
	var night_view := find_type(_main, "NightResolutionView") as NightResolutionView
	_check(night_view != null and night_view._body.text.contains("宣传回音"), "night close feedback visible")
	_check(not night_view._body.text.contains("商誉") and night_view._body.text.contains("本金"), "night hides reputation numbers and keeps financial terms")
	if "wide" in OS.get_cmdline_user_args(): _check(night_view._body.text.contains("好名声又传开"), "positive advertising effect is visible")
	await _capture("closed")
	flow.show_panel(&"ledger"); await _frames()
	var ledger: String = _session.counter_model().ledger.body
	_check(ledger.contains("宣传回音") and not ledger.contains("下次添商誉"), "ledger uses the same feedback without score countdown")
	await _capture("ledger")
	flow.show_panel(&"day"); await _frames()
	_check(not SocialReadModels.notice(_session._day.state).contains("商誉"), "old numeric notice is presented without score")
	_check(_session.read_state() == snapshot, "switching panels leaves game and old records unchanged")
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(_session._day.state, 43), _session.definition, 43, _session._counter.catalog, true)
	_check(restored != null, "current v43 save replay after advertising " + codec.error_message)
	flow.show_panel(&"night"); await _frames()
	driver.action(_session, "resolve_night"); driver.drain(_session)
	for command in ["enter_room", "sleep", "finish_sleep"]:
		driver.action(_session, command); driver.drain(_session)
	flow.show_panel(&"night"); await _frames()
	_check(_session._day.state.phase == &"day_summary", "real day summary reached")
	_check(night_view._account.visible and all_text(night_view._account).contains("宣传回音"), "summary account shows textual outcome")
	_check(not all_text(night_view._account).contains("商誉"), "summary account hides score")
	for label in night_view._account.get_children():
		if label is Label and label.text.contains("宣传回音"):
			(night_view._account.get_parent().get_parent() as ScrollContainer).ensure_control_visible(label)
			await _frames()
			_check(label.get_global_rect().intersects((night_view._account.get_parent().get_parent() as Control).get_global_rect()), "summary feedback can be brought into view")
	await _capture("summary")
	print("REPUTATION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func find_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == type_name: return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found != null: return found
	return null

func all_text(node: Node) -> String:
	var text: String = node.text if node is Label else ""
	for child in node.get_children(): text += all_text(child)
	return text

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://.godot/qa/reputation-feedback/"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder + _capture_prefix + "_" + label + ".png") == OK, "capture " + label)
