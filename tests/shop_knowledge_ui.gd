extends "res://tests/fan_condition_ui.gd"

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("KNOWLEDGE UI TIMEOUT"); quit(1))
	_capture_prefix = "knowledge_1600" if "wide" in OS.get_cmdline_user_args() else "knowledge_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start_fan_condition_v29.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/knowledge_ui/auto.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	var store := DraftUIStore.new(); store.origin = _session._day.state.ghost_origin; _session._save = store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	install("knowledge-before"); await service()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var room := screen.facilities.room
	await move_pointer(Vector2(20, 500))
	_check(not visible_copy(room).contains("顾砚生"), "cabinet has no visible name")
	await _capture("cabinet")
	var hover_before := _session.read_state()
	await move_pointer(room.hotspots["knowledge/gu_yansheng"].get_global_rect().get_center())
	_check(room._shader.get_shader_parameter("cabinet_hover") != Vector4.ZERO and not room._hover_label.visible, "hover lights wood without floating name")
	await _capture("cabinet_hover")
	await move_pointer(Vector2(20,500))
	_check(room._shader.get_shader_parameter("cabinet_hover") == Vector4.ZERO and _session.read_state() == hover_before, "leaving removes glow without gameplay change")
	await _click_button(room.hotspots["knowledge/gu_yansheng"])
	_check(room._title.text == "第一柜 · 顾砚生知识", "physical cabinet opens specific knowledge")
	var button := _find_button(room,"学习顾砚生知识 · 1行动点")
	_check(button != null and not button.disabled and room._scroll.get_global_rect().encloses(button.get_global_rect()), "study visible and enabled without book or bench")
	await _capture("before")
	var before := _session.read_state()
	store.fail = true; await _click_button(button)
	_check(_session.read_state() == before and not ShopKnowledgeService.mastered(_session._day.state,"gu_yansheng"), "UI failed save keeps learning retryable")
	store.fail = false; await _click("学习顾砚生知识 · 1行动点")
	_check(PreparationService.count(_session._day.state) == 1 and ShopKnowledgeService.mastered(_session._day.state,"gu_yansheng"), "mouse learns for one preparation")
	_check(_find_button(room,"学习顾砚生知识 · 1行动点") == null and room.body.text.contains("已掌握"), "learned replaces study action")
	await _capture("learned")
	before = _session.read_state()
	await _click_button(room._close); await _click_button(room.hotspots["knowledge/gu_yansheng"])
	_check(_session.read_state() == before, "reopening mastered cabinet is free")
	await _click_button(room._close); await _click_button(room.hotspots.bench)
	_check(_find_button(room,"研习扇画图录 · 1行动点 / 不收费") == null, "bench no longer teaches generic knowledge")
	await _click_button(room._close)
	install("knowledge-equipped"); await service(); await _click_button(room.hotspots["knowledge/gu_yansheng"])
	_check(room.body.text.contains("已掌握"), "restored topic knowledge shown in cabinet")
	for stage in ["knowledge-before", "upgrade-without-book", "tools-without-book", "knowledge-equipped"]:
		await _click_button(room._close)
		install(stage); await service(); await _click_button(room.hotspots.bench)
		_check(room.body.text.length() < 65 and not room.body.text.contains("图录"), "bench shows concise current abilities " + stage)
		_check(room._scroll.get_global_rect().encloses(room.body.get_global_rect()), "bench abilities visible without scrolling " + stage)
		for child in room.actions.get_children():
			if child is Button: _check(room._scroll.get_global_rect().encloses(child.get_global_rect()), "current bench action fits " + stage)
		if stage == "knowledge-before": _check(room.actions.get_child_count() == 1, "unbuilt bench has only repair action")
		if stage == "knowledge-equipped": _check(room.body.text.contains("顾砚生扇画比对 · 已开放"), "available comparison shown")
		await _capture("bench_" + stage)
	print("KNOWLEDGE UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func move_pointer(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await _frames()
