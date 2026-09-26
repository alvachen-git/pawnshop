extends SceneTree

func _initialize() -> void: call_deferred("preview")
func preview() -> void:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--special-"): args[argument.get_slice("=",0)] = argument.get_slice("=",1)
	var size := Vector2i(1600,900) if args.get("--special-wide","false") == "true" else Vector2i(1280,720)
	root.size = size; root.content_scale_size = size
	var main: Node = load("res://scenes/start_medicine_huaian_v47.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/medicine-preview/auto.json"
	root.add_child(main); current_scene = main
	var session: RunSession = main.get_node("Bootstrap").session
	MedicinePreview.apply(session,args.get("--special-stage","first"))
	session.restored.emit(); session.changed.emit()
	for i in 10: await process_frame
	root.mode = Window.MODE_WINDOWED; root.size = size; root.content_scale_size = size
