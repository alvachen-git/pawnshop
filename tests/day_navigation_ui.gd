extends "res://tests/inventory_event_notice_ui.gd"

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/day_navigation/auto.json"
	root.add_child(main)
	var session: RunSession = main.get_node("Bootstrap").session
	session._save = GhostReplayStore.new()
	var state := session._day.state
	state.current_night_index = 3
	state.phase = &"open"
	state.pending_event_id = ""
	session.message = ""
	session.changed.emit()
	var screen: CounterScreen = main.get_node("CounterScreen")
	var flow = screen.get_node("%ScreenFlowCoordinator")
	var panel: DayFlowPanel = screen.get_node("%DayFlowPanel")
	flow.show_panel(&"day")
	await frames()
	check(panel._buttons.has("choose_wait") and not panel._buttons.has("short_task") and panel._buttons.has("wait_until_seal"), "waiting and closing at first level")
	check(not panel._buttons.has("read_seven_notes"), "known messages button removed")
	await capture("business")
	var before := session.read_state()
	await click(panel._buttons.choose_wait)
	check(session.read_state() == before, "opening the duration picker costs nothing")
	check(panel._buttons.size() == session.definition.actions.size() + 1, "durations and return only")
	await capture("duration")
	await click(panel._buttons.cancel_wait)
	check(session.read_state() == before and panel._buttons.has("choose_wait"), "cancelling costs nothing")
	for action in session.definition.actions:
		session._day.state.pending_event_id = ""
		session.changed.emit()
		flow.show_panel(&"day")
		var minute := int(session._day.state.game_minutes)
		await click(panel._buttons.choose_wait)
		await click(panel._buttons["wait_option/" + action.id])
		check(session._day.state.game_minutes == minute + action.minutes, "selected duration executes once: " + action.id)
	# Near closing, long choices are disabled while the remainder stays available.
	session._day.state.pending_event_id = ""
	session._day.state.game_minutes = session.definition.night_minutes - 5
	session.changed.emit()
	flow.show_panel(&"day")
	await click(panel._buttons.choose_wait)
	check(panel._buttons["wait_option/medium_task"].disabled and not panel._buttons["wait_option/short_task"].disabled , "remaining time is respected")
	await click(panel._buttons.cancel_wait)
	check(not panel._buttons.wait_until_seal.disabled, "closing accessible directly")
	await click(panel._buttons.wait_until_seal)
	check(session._day.state.phase == &"night_resolution", "until closing uses normal transition")
	check(session.execute("resolve_night").ok, "normal night settlement")
	await frames()
	await click(screen.get_node("%CloseDrawerButton"))
	await click(screen.get_node("%CounterView").get_hotspot(&"shop"))
	check(flow.get_active_panel_id() == &"day" and panel._buttons.has("enter_room"), "business page recovers room entry after dismissing settlement")
	check(not panel._buttons.enter_room.disabled and not panel._buttons.has("choose_wait"), "room action available without stale waiting actions")
	await capture("room-entry")
	await click(panel._buttons.enter_room)
	check(session._day.state.phase == &"private_room", "room entry works from business page")
	print("DAY NAVIGATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/day-navigation-%d-%s.png" % [root.size.x, label])
