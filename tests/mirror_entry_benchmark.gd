extends SceneTree

var samples: Array = []
var callbacks: Dictionary = {}
var recording := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").manifest_path = "res://data/aqi_reunion_manifest.json"
	main.get_node("Bootstrap").save_path = "user://tests/mirror-benchmark/auto.json"
	root.add_child(main)
	var session: RunSession = main.get_node("Bootstrap").session
	session.profile_enabled = true
	var screen: CounterScreen = main.get_node("CounterScreen")
	for row in session.changed.get_connections():
		var callback: Callable = row.callable
		session.changed.disconnect(callback)
		session.changed.connect(func() -> void:
			var t := Time.get_ticks_usec()
			callback.call()
			if recording:
				var key := str(callback)
				callbacks[key] = int(callbacks.get(key, 0)) + Time.get_ticks_usec() - t
		)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v27-reunion/ready-apology.json"))
	for i in 21:
		session._day.state = SaveCodec.new().decode(fixture, session.definition, 27, session._counter.catalog, true)
		assert(session._day.state != null)
		session.restored.emit(); session.changed.emit()
		await create_timer(0.12).timeout
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"dialogue")
		await create_timer(0.12).timeout
		var id: String = session._counter.customers.active(session._day.state).visit_id
		var entry: Button
		if "input" in OS.get_cmdline_user_args():
			var dialogue: DialoguePanel = screen.get_node("%DialoguePanel")
			for child in dialogue._buttons.get_children():
				if child is Button and child.text.contains("请镜中女子现身"): entry = child; break
			assert(entry != null and entry.is_visible_in_tree() and not entry.disabled)
			(dialogue._column.get_parent() as ScrollContainer).ensure_control_visible(entry)
			await create_timer(0.12).timeout
		recording = i > 0
		session.profile_us.clear()
		var t := Time.get_ticks_usec()
		if entry != null:
			for pressed in [true, false]:
				var input := InputEventMouseButton.new()
				input.position = entry.get_global_rect().get_center()
				input.button_index = MOUSE_BUTTON_LEFT; input.pressed = pressed
				root.push_input(input)
		else:
			var result := session.counter_command("ending_begin", id)
			assert(result.ok)
		var command_us := Time.get_ticks_usec() - t
		assert(session._day.state.mirror_resolution.get("step", 0) == 1)
		await RenderingServer.frame_post_draw
		var frame_us := Time.get_ticks_usec() - t
		recording = false
		assert(screen.get_node("MirrorReunion").visible)
		samples.append({"command_ms": command_us / 1000.0, "frame_ms": frame_us / 1000.0, "profile_us": session.profile_us.duplicate()})
	var times: Array = samples.slice(1).map(func(s: Dictionary): return s.frame_ms)
	times.sort()
	print("MIRROR ENTRY BENCHMARK ", root.size, " cold=", samples[0], " warm_p95_ms=", times[18], " warm_max_ms=", times[19])
	print("CALLBACK_TOTAL_US ", JSON.stringify(callbacks))
	print("SAMPLES ", JSON.stringify(samples))
	var saves: Array = []
	for i in 4:
		var started := Time.get_ticks_usec()
		assert(session._save.save_state(session._day.state, session.definition, 27))
		saves.append((Time.get_ticks_usec() - started) / 1000.0)
	print("SAVE_ONLY_MS ", saves)
	quit()
