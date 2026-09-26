extends SceneTree

func _initialize() -> void: call_deferred("preview")

func preview() -> void:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--special-"): args[argument.get_slice("=",0)] = argument.get_slice("=",1)
	root.size = Vector2i(1600,900) if args.get("--special-wide", "false") == "true" else Vector2i(1280,720)
	root.content_scale_size = root.size
	var main: Node = load("res://scenes/start_special_guests_late_v46.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://special-guests-preview/autosave.json"
	root.add_child(main); current_scene = main
	var session: RunSession = main.get_node("Bootstrap").session
	var stage: String = args.get("--special-stage","bedroom")
	if stage in ["bedroom", "bedroom-aged"]: SpecialGuestsPreview.bedroom(session, 5 if stage == "bedroom-aged" else 1)
	else: SpecialGuestsPreview.apply(session,{"hat":"one_quote","wet":"wet_cloth","bundle":"closed"}.get(stage,"one_quote"),args.get("--special-item",CameraEconomy.ITEM))
	session.restored.emit(); session.changed.emit()
	for i in 8: await process_frame
	if stage not in ["bedroom", "bedroom-aged"]: main.get_node("CounterScreen")._route_from_customer(&"trade")
	if args.has("--special-seconds"):
		await create_timer(float(args["--special-seconds"])).timeout
		quit()
