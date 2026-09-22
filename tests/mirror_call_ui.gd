extends "res://tests/inventory_event_notice_ui.gd"

var session: RunSession
var screen: CounterScreen
var dream: MirrorDreamView

class FailingStore extends GhostReplayStore:
	func save_state(_s: RunState, _d: RunDefinition, _v: int) -> bool: return false

func click(button: Button) -> void:
	await create_timer(0.20).timeout
	await super.click(button)

func shot(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa/mirror-dream-call/%d-%s.png" % [root.size.x, label])

func restore(stage: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v29/" + stage + ".json"))
	session._day.state = SaveCodec.new().decode(data, session.definition, 29, session._counter.catalog, true)
	check(session._day.state != null, "verified fixture " + stage)
	session.restored.emit(); session.changed.emit(); await frames()

func enter_key() -> void:
	for down in [true, false]:
		var key := InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = down
		root.push_input(key); await process_frame
	await frames()

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa/mirror-dream-call"))
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false; main.get_node("Bootstrap").save_path = "user://tests/v29-ui/auto.json"
	root.add_child(main)
	session = main.get_node("Bootstrap").session
	screen = main.get_node("CounterScreen"); dream = screen.get_node("MirrorDream")
	await restore("bedtime")
	await click(screen._room.get_node("RoomBed")); await enter_key()
	check(dream.visible and dream._event_id == MirrorDreamService.CALL, "bed confirmation opens choice without accidentally inspecting")
	await create_timer(1.0).timeout
	check(dream._cry.playing and dream._cry.get_playback_position() > 0.1, "real recorded sobbing is playing")
	check(dream._cry.stream.get_length() > 10 and dream._cry.volume_db <= -8, "quiet substantial audio cue")
	check(not dream._wife.visible and not dream._text.text.contains("哭"), "room remains visible, no textual crying substitute")
	check(dream._text.text == "闭上眼睛，逐渐失去意识，但似乎有个声音。", "requested bedtime narration")
	check(dream._text.get_content_height() <= dream._text.size.y + 1, "bedtime narration fits")
	await shot("door")
	var before := session.read_state()
	await click(dream.find_child("CollapseDream", true, false))
	check(not dream.visible and dream._cry.playing, "collapse keeps sobbing playing")
	await create_timer(dream._cry.stream.get_length()).timeout
	check(dream._cry.playing and dream._cry.get_playback_position() < 5.0, "sobbing naturally loops past full recording while collapsed")
	var playback_position := dream._cry.get_playback_position()
	await click(dream._resume)
	check(dream.visible and dream._cry.playing and dream._cry.get_playback_position() >= playback_position and before == session.read_state(), "return continues audio without restarting or consuming choice")
	var store := session._save; session._save = FailingStore.new()
	await click(dream._choices.get_node("inspect"))
	check(dream._event_id == MirrorDreamService.CALL and before == session.read_state(), "failed inspect keeps decision retryable")
	check(not dream._cry.playing, "inspect stops looping even when saving fails")
	session._save = store
	await click(dream._choices.get_node("inspect"))
	check(dream._event_id == MirrorDreamService.EVENT and dream._page == 0 and not dream._cry.playing, "inspect enters dream and stops door audio")
	before = session.read_state()
	for page in range(1, 8):
		await create_timer(0.18).timeout; await enter_key()
		check(dream._page == page, "exactly one dream page advances")
		check(dream._text.get_content_height() <= dream._text.size.y + 1, "dream text fits")
		check(before == session.read_state(), "reading grants no story fact")
		if page == 1: await shot("wife")
		if page == 3: await shot("sorrow")
		if page == 5: await shot("request")
		if page == 7: await shot("fade")
	session._save = FailingStore.new()
	await create_timer(0.18).timeout; await click(dream._next)
	check(before == session.read_state() and dream._event_id == MirrorDreamService.EVENT, "failed waking rolls back sleep")
	session._save = store
	await click(dream._next)
	check(dream._event_id == MirrorDreamService.MORNING and dream._page == 0 and not dream._wife.visible, "waking opens morning room recollection")
	check(not dream._cry.playing and not dream._audio.playing, "no crying continues into morning")
	await shot("morning")
	before = session.read_state()
	await click(dream._next)
	check(dream._page == 1 and dream._text.text.contains("旧当票"), "first-person recollection and existing evidence direction")
	check(before == session.read_state(), "morning reading does not grant investigation")
	check(dream._text.get_content_height() <= dream._text.size.y + 1, "morning guidance fits")
	await shot("guidance")
	session._save = FailingStore.new()
	await click(dream._next)
	check(before == session.read_state() and dream._next.text == "重试起身", "failed rising retains retry and date")
	await shot("retry")
	session._save = store
	await click(dream._next)
	check(not dream.visible and session._day.state.current_night_index == 5 and session._day.state.phase == &"pre_open", "rise opens following day once")
	session.restored.emit(); session.changed.emit(); await frames()
	check(not dream.visible, "completed dream never replays")
	for stage in ["call", "second"]:
		await restore(stage)
		var night := session._day.state.current_night_index
		await click(dream._choices.get_node("ignore"))
		check(not dream.visible and not dream._cry.playing, "ignoring stops cue and skips dream")
		check(session._day.state.current_night_index == night + 1 and MirrorDreamService.FLAG not in session._day.state.narrative_flags, "ignore sleeps to next day without hearing story")
	print("MIRROR CALL UI ", root.size, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
