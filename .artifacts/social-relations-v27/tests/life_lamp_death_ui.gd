extends "res://tests/opening_ui_smoke.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("LAMP DEATH UI TIMEOUT"); quit(1))
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16)
	root.content_scale_size = root.size
	shot_root = "res://docs/qa/life-lamp/"
	scene = load("res://scenes/start.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = "user://tests/lamp_death_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(scene)
	await frames()
	await click(scene.title_menu.buttons[0])
	session = scene.get_node("Bootstrap").session
	view = scene.get_node("CounterScreen/NarrativeScene")
	var source := {"id": "qa_lamp_harm", "title": "柜前的寒意", "speaker": "旁白", "body": "柜台下伸出一只冰冷的手。", "kind": "anchor", "phase": "open", "night_min": 1, "night_max": 1, "window_start": 0, "window_end": 541, "priority": 99, "weight": 1, "max_count": 4, "cooldown": 0, "required_flags": [], "excluded_flags": [], "required_items": [], "conflicts_with": [], "presentation": {"scene": "counter", "hotspots": true}, "choices": [{"id": "hurt", "label": "伸手去碰", "result": "指尖一凉，寒意刺进胸口。", "minutes": 5, "grant_flags": [], "personal_damage": true}]}
	session._events.catalog.add_definition("events", EventDefinition.from_dto(EventDTO.from_source(source)))
	session.definition._event_ids = ["qa_lamp_harm"]
	session.new_run()
	check(session.execute("open_shop").ok, "death UI fixture opens through game command")
	await frames()
	for i in 3:
		await choice("hurt")
		check(session._day.state.personal_damage == i + 1, "native choice applies injury")
	check(session.event_model().text.contains("影子薄得几乎看不见"), "near-exhaustion warning visible in narrative model")
	await shot("business_warning")
	var before := session.read_state()
	var library := SaveLibrary.new("user://tests/lamp_ui_fault.json")
	library.fail_write = true
	session._save.library = library
	await choice("hurt")
	check(session.read_state() == before and view.visible, "native failed death leaves live event and full state intact")
	session._save.library = null
	await choice("hurt")
	check(session._day.state.phase == &"dead" and session._day.state.summaries.is_empty(), "native business death has no fabricated summary")
	check(session._day.state.cash == session.definition.initial_cash and session._day.state.game_minutes == 20, "native ending preserves actual time and money")
	check(not scene.get_node("CounterScreen/PrivateRoom").visible, "business death stays downstairs")
	check(session.risk_model().history.contains("指尖一凉"), "actual cause appears in death archive")
	check(not session.risk_model().body.contains("操作未保存"), "successful retry clears prior save error")
	await shot("business_death")
	print("LAMP DEATH UI: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
