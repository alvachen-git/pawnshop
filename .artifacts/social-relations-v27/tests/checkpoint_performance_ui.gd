extends "res://tests/inventory_event_notice_ui.gd"

class TimedSave extends SaveManager:
	var elapsed := 0
	func save_state(state: RunState, definition: RunDefinition, version: int) -> bool:
		var start := Time.get_ticks_usec()
		var ok := super.save_state(state, definition, version)
		elapsed += Time.get_ticks_usec() - start
		return ok

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/checkpoint_performance/auto.json"
	root.add_child(main)
	var session: RunSession = main.get_node("Bootstrap").session
	var catalog := session._counter.catalog
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/ending.json"))
	var store := GhostReplayStore.new(); store.origin = data.ghost_origin
	var replay := RunSession.new(session.definition, 23, store, catalog)
	replay.replaying = true
	for row in data.action_journal:
		if replay._day.state.current_night_index == 8 and row.method == "execute" and row.args[0] in ["prep_finish", "open_shop"]: break
		replay.callv(row.method, row.args)
	session._day.state = replay._day.state
	session._pawn_choices = replay._pawn_choices.duplicate(true)
	var saver := TimedSave.new("user://tests/checkpoint_performance/auto.json")
	saver.catalog = catalog
	saver.library = SaveLibrary.new("user://tests/checkpoint_performance/library.json")
	session._save = saver
	check(saver.save_state(session._day.state, session.definition, 23), "initial checkpoint validated")
	session.changed.emit()
	var screen: CounterScreen = main.get_node("CounterScreen")
	var flow = screen.get_node("%ScreenFlowCoordinator")
	var panel: DayFlowPanel = screen.get_node("%DayFlowPanel")
	for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "enter_room"]:
		flow.show_panel(&"day")
		await frames()
		saver.elapsed = 0
		var start := Time.get_ticks_usec()
		if panel._buttons.has(command):
			check(not panel._buttons[command].disabled, "enabled " + command)
			panel._buttons[command].pressed.emit()
		else:
			check(session.execute(command).ok, "settlement " + command)
		var action_ms := (Time.get_ticks_usec() - start) / 1000.0
		await RenderingServer.frame_post_draw
		print("UI ACTION ", command, ": handler ", action_ms, " ms; first frame ", (Time.get_ticks_usec() - start) / 1000.0, " ms; save ", saver.elapsed / 1000.0, " ms")
		await frames()
		check(session._day.state.phase == {"open_shop": &"open", "close_shop": &"closed_processing", "wait_until_seal": &"night_resolution", "resolve_night": &"shop_resolution", "enter_room": &"private_room"}[command], "phase " + command)
	await capture("room")
	print("CHECKPOINT UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
