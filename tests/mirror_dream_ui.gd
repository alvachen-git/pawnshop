extends "res://tests/inventory_event_notice_ui.gd"

var session: RunSession
var screen: CounterScreen
var dream: MirrorDreamView

class FailingStore extends GhostReplayStore:
	func save_state(_s: RunState, _d: RunDefinition, _v: int) -> bool: return false

func shot(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa/mirror-dream/%d-%s.png" % [root.size.x, label])

func enter_key() -> void:
	for down in [true, false]:
		var key := InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = down
		root.push_input(key)
		await process_frame
	await frames()

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa/mirror-dream"))
	var main = load("res://scenes/start_v28.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/v28-ui/auto.json"
	root.add_child(main)
	session = main.get_node("Bootstrap").session
	screen = main.get_node("CounterScreen"); dream = screen.get_node("MirrorDream")
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v28/bedtime.json"))
	session._day.state = SaveCodec.new().decode(fixture, session.definition, 28, session._counter.catalog, true)
	check(session._day.state != null, "verified real bedtime fixture")
	session.restored.emit(); session.changed.emit(); await frames()
	await click(screen._room.get_node("RoomBed"))
	await enter_key()
	await frames()
	check(dream.visible and dream._page == 0, "sleep opens dream")
	await shot("arrival")
	var state_before := session.read_state()
	await create_timer(0.18).timeout
	await enter_key()
	check(dream._page == 1 and dream._heard, "confirm advances exactly one page")
	check(dream._text.get_content_height() <= dream._text.size.y + 1, "first voiced page fits")
	await shot("wife")
	var close: Button = dream.find_child("CollapseDream", true, false)
	await click(close)
	check(not dream.visible and dream._resume.visible and not dream._audio.playing, "collapse stops audio and leaves bedroom resume")
	check(not session.can_execute("finish_sleep"), "collapsed dream cannot be bypassed")
	await shot("collapsed")
	await click(dream._resume)
	check(dream.visible and dream._page == 1 and not dream._audio.playing, "resume preserves reading position without replaying sound")
	check(state_before == session.read_state(), "reading and hiding grant no fact or time")
	for page in range(2, 8):
		await create_timer(0.18).timeout
		await click(dream._next)
		check(dream._page == page, "one page per click")
		check(dream._text.get_content_height() <= dream._text.size.y + 1, "entire short page fits")
		if page == 3: await shot("sorrow")
		if page == 5: await shot("request")
		if page == 6: await shot("direction")
		check(state_before == session.read_state(), "page does not grant evidence")
	var store := session._save; session._save = FailingStore.new()
	await create_timer(0.18).timeout; await click(dream._next)
	check(dream.visible and dream._page == 7 and dream._next.text == "重试醒来", "failed save retains final retry")
	check(state_before == session.read_state(), "failed wake rolls back sleep, money, and event")
	await shot("retry")
	session._save = store
	await create_timer(0.18).timeout; await click(dream._next)
	check(not dream.visible and session._day.state.phase == &"day_summary", "one wake click completes sleep")
	check(MirrorDreamService.FLAG in session._day.state.narrative_flags, "dream journal committed")
	check(session._day.state.personal_damage == state_before.personal_damage, "no dream damage")
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"risk"); await frames()
	check(session.risk_model().body.contains("她托我寻找离家的丈夫"), "existing investigation guidance is visible")
	await shot("guidance")
	var complete := session.read_state()
	session.restored.emit(); session.changed.emit(); await frames()
	check(not dream.visible and complete == session.read_state(), "completed dream never replays on restore")
	session._day.state = SaveCodec.new().decode(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v28/dream.json")), session.definition, 28, session._counter.catalog, true)
	session.restored.emit(); session.changed.emit(); await frames()
	check(dream.visible and dream._page == 0, "unfinished reload restarts at beginning")
	print("MIRROR DREAM UI ", root.size, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
