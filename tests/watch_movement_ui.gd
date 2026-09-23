extends "res://tests/watch_ui.gd"

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("MOVEMENT UI TIMEOUT"); quit(1))
	_capture_prefix = "watch36_1600" if "wide" in OS.get_cmdline_user_args() else "watch36_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").manifest_path = "res://data/watch_patterns_manifest.json"; _main.get_node("Bootstrap").save_path = "user://tests/watch36-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session; await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 36,"default new game v36")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	for scenario in ["engraving","gears"]:
		PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,scenario)
		_session.restored.emit(); _session.changed.emit(); await _frames()
		var v: CustomerVisit = _session._day.state.visits[0]
		await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定"); await _click(_session.counter_model().appraisal.buttons[1].label)
		var desk := root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
		_check(desk != null,"open desk")
		if desk == null: quit(1); return
		await _click_button(desk.open_button)
		_check(desk.object_plate.texture == WatchArt.movement(v.item),"new sprite used in actual game")
		for i in 2:
			var point := WatchAppraisal.spot(v.item,i)
			await click_point(desk.object_plate.get_global_rect().position+desk.object_plate.get_global_rect().size*point)
			_check(desk.data().spots.size() == i+1,"real point collects matching clue")
		await _capture(scenario+"_desk")
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = true
		event.position = desk.object_plate.get_global_rect().position+desk.object_plate.get_global_rect().size*WatchAppraisal.spot(v.item,0)
		root.push_input(event,true); await _frames(); event.pressed = false; root.push_input(event,true); await _frames()
		_check(desk.zoom_panel.visible,"right click compare enlarged")
		await _capture(scenario+"_zoom")
		await _click_button(desk.zoom_panel.find_child("close_zoom",true,false))
		await _click_button(desk.note_button); await choose(desk.id_choice,2); await _click_button(desk.seal_button)
		_check(root.get_node_or_null("WatchDeskOverlay") == null,"seal returns counter")
		_check(_session.counter_command("watch_claim",v.visit_id,'{"identity":"imitation"}').ok,"new pictures connect to claims")
		_check(v.item.goods.watch_value.actual == 100,"fake value unchanged")
		screen._close_drawer()
	PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,"guide")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var guide := WatchGuideView.open(screen,_session); await _frames()
	await _click_button(guide.canvas.find_child("next",true,false)); await _capture("guide")
	_check(guide.content.has_node("genuine_reference"),"guide still only genuine reference")
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	print("WATCH MOVEMENT UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/watch-v36/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture "+label)
