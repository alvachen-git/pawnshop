extends SceneTree

var main: Node
var session: RunSession
var passes := 0
var failures := 0
var wide := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error(label)
func frames(count := 5) -> void:
	for i in count: await process_frame
func capture(label: String) -> void:
	await frames()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/special-guests")
	root.get_texture().get_image().save_png("res://.godot/qa/special-guests/%s_%s.png" % ["1600" if wide else "1280",label])
func run() -> void:
	wide = "wide" in OS.get_cmdline_user_args()
	root.size = Vector2i(1600,900) if wide else Vector2i(1280,720)
	root.content_scale_size = root.size
	main = load("res://scenes/start_special_guests_late_v46.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/special-guests-ui/auto.json"
	root.add_child(main); current_scene = main
	session = main.get_node("Bootstrap").session
	await frames(10)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900) if wide else Vector2i(1280,720)
	root.content_scale_size = root.size
	await frames(10)
	check(root.get_texture().get_image().get_size() == root.size and root.size == (Vector2i(1600,900) if wide else Vector2i(1280,720)),"actual capture resolution")
	var screen := main.get_node("CounterScreen") as CounterScreen
	for kind in ["closed", "one_quote", "wet_cloth"]:
		var visit := SpecialGuestsPreview.apply(session,kind)
		session.restored.emit(); session.changed.emit(); await frames()
		screen._route_from_customer(&"trade"); await frames()
		var model := session.counter_model()
		check(model.visual.customer_name == "？？？","anonymous " + kind)
		if kind == "wet_cloth":
			check(screen._counter_view._portrait.texture.resource_path.ends_with("wet_bundle_v45.png"),"wet guest uses selected independent portrait")
		check(model.trade.can_offer,"direct offer " + kind)
		check(not model.trade.has("camera_claims"),"special trade has no alternate quotation")
		await capture(kind)
		if kind == "one_quote":
			check(session.counter_command("luxury_exterior",visit.visit_id).ok,"high-grade exterior")
			check(session.fan_command("luxury_begin",visit.item.instance_id,"2").ok,"camera apparatus accessible")
			await frames(); await capture("camera")
	SpecialGuestsPreview.bedroom(session)
	session.restored.emit(); session.changed.emit(); await frames()
	var sound := screen.find_child("HeldGoodsAudio",true,false) as HeldGoodsAudio
	check(sound != null,"held audio installed")
	await create_timer(2.2).timeout
	check(sound.play_count >= 1,"first sound in bedroom")
	check(sound.noted_context == session._day.state.run_token,"first audible caption recorded locally")
	var previous := sound.last_clip
	for i in 5:
		sound.player.stop(); sound.remaining = 0; await frames(3)
		check(sound.last_clip != previous,"no consecutive repeated clip")
		check(sound.remaining >= 3.7 and sound.remaining <= 8.0,"repeat interval 4 to 8 seconds")
		previous = sound.last_clip
	await capture("first_sound")
	session.restored.emit()
	check(not sound.armed and not sound.player.playing,"load stops before rearming")
	await frames(); check(sound.remaining >= 0.7 and sound.remaining <= 2.0,"load restarts first delay")
	sound.room._model.pending = true; await frames()
	check(not sound.armed,"dialogue pauses sound")
	sound.room._model.pending = false; await frames()
	var dream := MirrorDreamView.new(); main.add_child(dream); dream.show(); await frames()
	check(not sound.armed,"dream pauses sound")
	dream.queue_free(); await frames()
	check(sound.armed,"dream ending rearms")
	paused = true; await frames()
	check(not sound.armed and not sound.player.playing,"global pause stops playback")
	paused = false; await frames()
	check(sound.armed,"global unpause restarts delay")
	sound.room.hide(); await frames()
	check(not sound.armed,"leaving bedroom stops playback")
	sound.room.show(); await frames()
	await capture("bedroom")
	var played := sound.play_count
	screen._toggle_menu(); await frames()
	check(not sound.player.playing and not sound.armed,"menu suspends sound")
	screen._close_menu(); await frames()
	check(sound.armed,"menu close rearms")
	var item: ItemInstance = session._day.state.inventory_instances[0]
	item.ownership_state = "sold"; session.changed.emit(); await frames()
	check(not sound.player.playing and not sound.armed,"selling ends sound")
	item.ownership_state = "owned"; session.changed.emit(); await frames()
	check(sound.armed,"held item resumes sound")
	session._day.state.phase = &"sleep_resolution"; session.changed.emit(); await frames()
	check(not sound.player.playing and not sound.armed,"sleep ends sound")
	check(sound.play_count == played,"no replay burst")
	SpecialGuestsPreview.bedroom(session,5)
	session.restored.emit(); session.changed.emit(); await frames()
	sound.room._bed_pressed(); await frames()
	check(sound.room._confirm.dialog_text.contains("胸口"),"fifth night warning before confirming sleep")
	check(sound.room._confirm.size.x <= 500,"warning wraps in compact dialog")
	await capture("wet_warning")
	sound.room._confirm.hide()
	check(session.execute("sleep").ok,"fifth night sleep succeeds")
	await frames()
	check(session._day.state.personal_damage == 1,"bedtime loses one lamp level")
	check(sound.room._body.text.contains("哭声"),"crying narration visible on damage")
	check(sound.room._observation.visible and sound.room._close_observation.visible,"bedtime narration can continue")
	check(sound.room._body.get_global_rect().end.y <= sound.room._close_observation.get_global_rect().position.y,"narration does not cover continue button")
	await capture("wet_pressure")
	check(session.execute("finish_sleep").ok,"aged preset can finish sleeping")
	check(session.execute("continue_run").ok,"aged preset can advance to next night")
	await frames()
	if "movie" in OS.get_cmdline_user_args():
		SpecialGuestsPreview.bedroom(session); session.changed.emit()
		await create_timer(32).timeout
	print("SPECIAL GUEST UI: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
