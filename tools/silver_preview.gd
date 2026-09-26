extends SceneTree

func _initialize() -> void:
	call_deferred("preview")

func preview() -> void:
	var args := OS.get_cmdline_user_args()
	var size := Vector2i(1600, 900) if "--silver-wide=true" in args else Vector2i(1280, 720)
	root.size = size; root.content_scale_size = size
	var main: Node = load("res://scenes/start_silver_v48.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/silver-preview/unused.json"
	main.get_node("Bootstrap").save_library_path = ""
	root.add_child(main); current_scene = main
	var session: RunSession = main.get_node("Bootstrap").session
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/silver-v48/reputation-16.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(payload, session.definition, 48, session._counter.catalog, true)
	if state == null:
		push_error("银楼试玩进度无法校验：" + codec.error_message); quit(1); return
	if state.social.reputation != 16 or state.current_night_index != 4 or not SilverPolicy.active(state):
		push_error("银楼试玩起点不符合商誉16、第四夜登门条件。"); quit(1); return
	var store := GhostReplayStore.new(); store.origin = state.ghost_origin.duplicate(true)
	session._save = store; session._day.state = state
	session.restored.emit(); session.changed.emit()
	for i in 12: await process_frame
	root.title = "鬼市当铺 · 银楼快速试玩 · 本次进度不保存"
	root.mode = Window.MODE_WINDOWED; root.size = size; root.content_scale_size = size
	if "--silver-verify" in args:
		var screen := main.get_node("CounterScreen") as CounterScreen
		if not screen.first_debt_conversation.visible or session.can_execute("open_shop") or not session._save is GhostReplayStore:
			push_error("银楼试玩对白或隔离条件不符。"); quit(1); return
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/qa/silver/preview-16.png")
		print("SILVER PREVIEW: reputation=16 night=4 cash=%d AP=%d; RPG visible; no persistent save" % [state.cash, PreparationService.action_points(state, session.definition)])
