extends "res://tests/tiered_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("WATCH UI TIMEOUT"); quit(1))
	_capture_prefix = "watch_1600" if "wide" in OS.get_cmdline_user_args() else "watch_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").manifest_path = "res://data/watch_manifest.json"; _main.get_node("Bootstrap").save_path = "user://tests/watch-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 33,"new game v33")
	PrecisionPreview.apply(_session,2,"gold_watch","mended","minor",true)
	var current := _session._day.state.visits[0] as CustomerVisit
	for value in 30:
		_session._day.state.run_seed = value*3571
		if WatchAppraisal.profile(_session._day.state,current.item) == "positional": break
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	var model: Dictionary = _session.counter_model().appraisal
	_check(model.buttons.size() == 2,"two entrances only")
	await _click(model.buttons[1].label)
	var desk := root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
	_check(desk != null,"counter opens watch desk")
	if desk == null: quit(1); return
	await _capture("arrival")
	await _click_button(desk.wind_button); await _click_button(desk.listen_button)
	_check(desk.audio_player.playing and desk.playing,"real audio starts")
	_check(desk.open_button.disabled and desk.vertical_button.disabled,"pose locked during listening")
	await create_timer(8.6).timeout; await _frames()
	_check("wound/flat" in desk.data().listened,"full playback recorded")
	await _click_button(desk.vertical_button); await _click_button(desk.listen_button)
	await create_timer(8.6).timeout; await _frames()
	_check("wound/vertical" in desk.data().listened,"vertical playback recorded")
	desk.seek.value = 3.0; await _click_button(desk.mark_button)
	_check(desk.data().marks["wound/vertical"].size() == 1,"audio mark through real button")
	await _click_button(desk.open_button)
	for index in 2:
		var spot := WatchAppraisal.spot(current.item,index)
		await click_point(desk.object_plate.get_global_rect().position+desk.object_plate.get_global_rect().size*spot)
	_check(desk.data().spots.size() == 2,"actual geometry spots found")
	await _capture("movement")
	var right := InputEventMouseButton.new(); right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true; right.position = desk.object_plate.get_global_rect().position+desk.object_plate.get_global_rect().size*WatchAppraisal.spot(current.item,0)
	root.push_input(right,true); await _frames(); _check(desk.zoom_panel.visible,"right click zoom")
	right.pressed = false; root.push_input(right,true); await _frames()
	await _capture("zoom")
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true; root.push_input(escape,true); await _frames()
	escape.pressed = false; root.push_input(escape,true); await _frames()
	_check(not desk.zoom_panel.visible,"escape closes zoom")
	await _click_button(desk.note_button)
	_check(desk.note_panel.visible,"note button opens modal")
	await choose(desk.id_choice,1); await choose(desk.repair_choice,2); await choose(desk.running_choice,1)
	await _capture("draft")
	await _click_button(desk.seal_button)
	_check(WatchAppraisal.correct(_session._day.state,current.item),"notes reflect independent sound and movement")
	_check(_session._day.state.game_minutes == 10,"one paid session no repeated charges")
	await _capture("sealed")
	for b in [desk.listen_button,desk.note_button,desk.open_button,desk.exterior_button]:
		_check(b.get_global_rect().end.x <= root.size.x and b.get_global_rect().end.y <= root.size.y,"controls within viewport")
	await _click_button(desk.note_panel.find_child("close_notes",true,false))
	await _click_button(desk.canvas.find_child("close",true,false))
	await _click(_session.counter_model().appraisal.buttons[1].label)
	desk = root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
	_check(desk != null and desk.data().marks["wound/vertical"].size() == 1,"reopen restores acoustic notes")
	desk.queue_free(); await _frames()
	PrecisionPreview.apply(_session,0,"gold_watch","sound","intact",false)
	_session.restored.emit(); _session.changed.emit(); await _frames()
	current = _session._day.state.visits[0]
	var basic_model: Dictionary = _session.counter_model().appraisal
	_check(basic_model.buttons.size() == 2 and basic_model.buttons[0].enabled and not basic_model.buttons[1].enabled,"no equipment still permits basic inspection")
	desk = WatchDeskView.create(screen,_session,current.item.instance_id); await _frames()
	_check(desk.listen_button.disabled and desk.helper.text.contains("钟表开验具"),"specific missing equipment visible")
	await _click_button(desk.exterior_button); await _capture("no_equipment")
	_check(_session._day.state.game_minutes == 5,"basic-only view charges five")
	desk.queue_free(); await _frames()
	PrecisionPreview.apply(_session,2,"gold_watch","sound","intact",false)
	_session.restored.emit(); _session.changed.emit(); await _frames()
	current = _session._day.state.visits[0]
	_check(_session.fan_command("luxury_begin",current.item.instance_id,"2").ok,"reference-state entry")
	desk = WatchDeskView.create(screen,_session,current.item.instance_id); await _frames()
	await _click_button(desk.open_button); await _capture("reference_state")
	desk.queue_free(); await _frames()
	print("WATCH UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/watch-v33/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture "+label)
