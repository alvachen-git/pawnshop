extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("AQI POINTER TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_capture_prefix = "aqi_pointer_%d" % root.size.x
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v25/pointer.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v25/pointer-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	var counter: CounterView = _main.get_node("CounterScreen")._counter_view
	var companion: AqiCompanionView = counter.companion
	for topic in ["chat", "paper"]:
		await restore_stage("idle-10")
		var before := _session.read_state()
		var visits_before := _session._day.state.visits.map(func(v: CustomerVisit) -> Array: return [v.visit_id, v.status, v.arrival, v.expires_at])
		await _click_button(companion.hotspot)
		var button := companion.dialogue._choices.get_node("Choice_aq_%s_10" % topic) as Button
		# The bell is later in the GUI tree despite being painted below the paper.
		# Click the actual overlap instead of the usual button centre.
		var overlap := button.get_global_rect().intersection(counter.bell.get_global_rect())
		print("POINTER ", topic, " overlap=", overlap, " minute=", before.game_minutes)
		await click_at(overlap.get_center() if overlap.has_area() else button.get_global_rect().get_center())
		print("AFTER minute=", _session.read_state().game_minutes, " active=", _session.counter_model().active_id)
		_check(_session.read_state() == before, "topic click never rings hidden bell " + topic)
		if not companion.dialogue.visible:
			quit(1); return
		_check(companion.dialogue._title.text != "柜边的阿七", "topic actually opens " + topic)
		await _capture(topic)
		button = companion.dialogue._choices.get_child(0)
		overlap = button.get_global_rect().intersection(counter.bell.get_global_rect())
		_check(overlap.has_area(), "confirmation overlaps bell " + topic)
		await click_at(overlap.get_center())
		var after := _session.read_state()
		var visits_after := _session._day.state.visits.map(func(v: CustomerVisit) -> Array: return [v.visit_id, v.status, v.arrival, v.expires_at])
		_check(after.game_minutes == before.game_minutes and after.cash == before.cash and visits_after == visits_before, "completed interaction preserves time money customers " + topic)
		_check(after.event_history.size() == before.event_history.size() + 1, "interaction records exactly once " + topic)
		await key(KEY_ESCAPE)
		await _frames()
		_check(not counter.bell.disabled, "bell usable after dialogue closes")
		await _click_button(counter.bell)
		_check(not _session.counter_model().active_id.is_empty(), "explicit bell still receives customer")
	print("AQI POINTER UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)
		await _frames()
