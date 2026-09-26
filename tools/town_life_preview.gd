extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if "=" in arg: args[arg.get_slice("=",0)] = arg.get_slice("=",1)
	var size := Vector2i(1600,900) if args.get("--town-wide","false") == "true" else Vector2i(1280,720)
	var version := int(args.get("--town-version","50"))
	if args.get("--town-legacy","false")=="true": version=48
	var main: Node = load("res://scenes/town_life_start.tscn" if version==48 else "res://scenes/town_life_v%d_start.tscn" % version).instantiate()
	main.start_at_title = false; main.get_node("Bootstrap").save_path = "user://tests/town-life-preview/unused.json"
	root.add_child(main); current_scene = main
	var session: RunSession = main.get_node("Bootstrap").session
	TownLifePreview.apply(session,args.get("--town-stage","porter"),args.get("--town-item",""),args.get("--town-condition","sound"),int(args.get("--town-military","0")))
	session.restored.emit(); session.changed.emit()
	root.title = "鬼市当铺 · 街巷百业测试预置 · 进度不保存"
	for i in 10: await process_frame
	root.mode = Window.MODE_WINDOWED; root.size = size; root.content_scale_size = size
