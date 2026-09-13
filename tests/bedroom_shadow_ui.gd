extends "res://tests/bedroom_art_ui_smoke.gd"

func _run() -> void:
	_keep_open = "interactive" in OS.get_cmdline_user_args()
	if not _keep_open: create_timer(90).timeout.connect(func() -> void: push_error("SHADOW UI TIMEOUT"); quit(1))
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16); root.content_scale_size = root.size
	shot_root = "res://docs/qa/bedroom-shadow/"
	DirAccess.make_dir_recursive_absolute(shot_root)
	DirAccess.make_dir_recursive_absolute("user://tests")
	var checkpoint := "user://tests/shadow_%d.json" % Time.get_ticks_usec()
	var saved := FileAccess.open(checkpoint, FileAccess.WRITE)
	saved.store_string(FileAccess.get_file_as_string("res://.artifacts/shadow-transfer/pursue_room.json")); saved.close()
	scene = load("res://scenes/start.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = checkpoint
	root.add_child(scene); await frames()
	await click(scene.title_menu.buttons[1])
	session = scene.get_node("Bootstrap").session
	view = scene.get_node("CounterScreen/NarrativeScene")
	var room: PrivateRoomView = scene.get_node("CounterScreen/PrivateRoom")
	check(room.visible and not view.visible, "actual checkpoint enters room")
	check(room._mirror.current_state().mode == &"shadow", "presenter restores production shadow")
	await _pointer(Vector2(width - 25, 80))
	await shot("shadow")
	var live := room._model.duplicate(true)
	var normal := live.duplicate(true); normal.mirror = {}
	room.render(normal); await shot("normal_same_lamp")
	room.render(live)
	if _keep_open:
		root.title = "鬼市当铺 · 镜面影子试玩（独立测试存档）"
		print("SHADOW PREVIEW READY: inspect the mirror, then sleep and respond")
		return
	var before := session.read_state()
	var old_bytes := FileAccess.get_file_as_bytes(checkpoint)
	for i in 3:
		await click(room._mirror.hit_target)
		check(room._observation.visible and room._body.text == BedroomMirrorFeedback.DESCRIPTION, "mirror describes actual shadow")
		if i == 0: await shot("observe")
		await _key(KEY_ESCAPE)
		check(not room._observation.visible and room._mirror.hit_target.has_focus(), "Esc restores mirror focus")
	check(before == session.read_state() and old_bytes == FileAccess.get_file_as_bytes(checkpoint), "repeated observation changes neither state nor disk")
	room._mirror.reset(); room.render(live)
	check(room._mirror.current_state().event_instance == live.mirror.event_instance, "redraw preserves saved event identity")
	check(session.load_checkpoint().ok, "reload succeeds")
	await frames()
	check(room._mirror.current_state().mode == &"shadow", "reload retains shadow")
	await click(room._desk)
	check(room._keepsakes.visible, "keepsakes remain accessible")
	await _key(KEY_ESCAPE)
	await click(room._menu)
	check(scene.find_child("SessionMenu", true, false).visible, "menu still opens")
	await _key(KEY_ESCAPE)
	await click(room._lamp)
	check(room._body.text == PersonalRisk.lamp_state(session._day.state).description, "lamp keeps personal injury description")
	await _key(KEY_ESCAPE)
	await click(room._bed); await click(room._confirm.get_ok_button())
	var risk: RiskPanel = scene.find_child("RiskPanel", true, false)
	check(session._day.state.phase == &"sleep_resolution" and risk.visible, "bed opens existing personal crisis")
	await shot("crisis")
	await click(risk._buttons.get_child(0))
	check(session._day.state.risk_pending.is_empty() and session._day.state.personal_damage == 1, "real avoidance leaves damage unchanged")
	check(room._mirror.current_state().mode == &"normal", "successful avoidance removes shadow")
	check(room._close_observation.text == "放松入眠", "existing sleep continuation retained")
	await shot("resolved")
	await click(room._close_observation)
	check(session._day.state.current_night_index == 4, "relax sleep goes straight to next day")
	print("SHADOW NATIVE %d: %d assertions, %d failures" % [width, checks, failures])
	quit(0 if failures == 0 else 1)
