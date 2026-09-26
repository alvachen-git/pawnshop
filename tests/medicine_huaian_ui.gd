extends SceneTree

var passes := 0
var failures := 0
var main: Node
var session: RunSession
var wide := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error(label)
func frames(n := 6) -> void:
	for i in n: await process_frame
func run() -> void:
	wide = "wide" in OS.get_cmdline_user_args()
	main = load("res://scenes/start_medicine_huaian_v47.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/medicine-ui/auto.json"
	root.add_child(main); current_scene = main
	session = main.get_node("Bootstrap").session
	await frames(12)
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1600,900) if wide else Vector2i(1280,720); root.content_scale_size = root.size
	await frames()
	var screen := main.get_node("CounterScreen") as CounterScreen
	var conversation := screen.get_node("MedicineConversation") as MedicineConversation
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/medicine-huaian")
	check(root.get_texture().get_image().get_size() == root.size,"actual resolution")
	for stage in ["first","final","report","saved","bereaved"]:
		MedicinePreview.apply(session,stage)
		session.restored.emit(); session.changed.emit(); await frames(12)
		await create_timer(0.4).timeout
		check(conversation.visible,"automatic RPG story " + stage)
		check(screen._counter_view._portrait.modulate.a >= 0.99,"arrival fade finished")
		check(conversation._speaker.text == ("周婶" if stage == "bereaved" else "周怀安"),"speaker " + stage)
		var texture := screen._counter_view._portrait.texture
		check(texture != null and texture.resource_path.ends_with("neighbor_v2.png" if stage == "bereaved" else "zhou_huaian_v47.png"),"dedicated actor " + stage)
		check(conversation._text.get_global_rect().end.y <= conversation._next.get_global_rect().position.y,"text avoids continue button")
		var snapshot := session.read_state()
		for i in 3: session.counter_model(); MedicineStory.dialogue(session._day.state)
		check(snapshot == session.read_state(),"reading story does not mutate money")
		root.get_texture().get_image().save_png("res://.godot/qa/medicine-huaian/%s_%s.png" % ["1600" if wide else "1280",stage])
		if stage == "final":
			conversation._page = conversation._pages.size()-1; conversation.display_page(); await frames()
			root.get_texture().get_image().save_png("res://.godot/qa/medicine-huaian/%s_plea.png" % ("1600" if wide else "1280"))
		for i in 12:
			if not conversation.visible: break
			conversation._last_press = 0; conversation.advance(); await frames(2)
		check(not conversation.visible,"conversation finishes " + stage)
		if stage == "final":
			var visit := session._counter.customers.active(session._day.state)
			check(visit.trade.asking_price == 40,"final missing balance quote")
			screen._route_from_customer(&"trade"); await frames()
			check(session.counter_model().trade.can_offer,"normal offer usable after plea")
			root.get_texture().get_image().save_png("res://.godot/qa/medicine-huaian/%s_final_trade.png" % ("1600" if wide else "1280"))
			screen._close_drawer()
		if stage in ["saved","bereaved"]:
			check(MedicineStory.ENDING in session._day.state.narrative_flags,"ending persisted")
			session.restored.emit(); await frames()
			check(not conversation.visible,"heard ending does not replay")
	print("MEDICINE UI: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
