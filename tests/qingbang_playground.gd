extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := "intro"
	for arg in OS.get_cmdline_user_args():
		if arg in ["intro","fee","raid","pawn","supply","inquiry"]: stage=arg
	var main: Node = load("res://scenes/start_qingbang.tscn").instantiate()
	main.start_at_title=false
	main.get_node("Bootstrap").save_path="user://tests/qingbang-playground/unused.json"
	main.get_node("Bootstrap").save_library_path=""
	root.add_child(main);current_scene=main
	var session: RunSession = main.get_node("Bootstrap").session
	if session==null: quit(1);return
	load("res://tests/qingbang_preview.gd").apply(session,stage)
	var screen := main.get_node("CounterScreen") as CounterScreen
	if stage in ["supply","inquiry"]:
		screen._social_panel.selected_faction="qingbang"
		screen._social_panel.section=1 if stage=="inquiry" else 0
		screen._flow.show_panel(&"social")
	print("Qingbang preview: memory-only, normal saves untouched.")
