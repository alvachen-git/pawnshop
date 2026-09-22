extends "res://tests/social_ui.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("INTRODUCTION UI TIMEOUT"); quit(1))
	_capture_prefix = "sun_halfbody_1600" if "wide" in OS.get_cmdline_user_args() else "sun_halfbody_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/sun_visit_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	install("introduction")
	await create_timer(.45).timeout
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view
	var book := screen._social_panel
	_check(not screen.get_node("Drawer").visible, "arrival shows counter instead of business drawer")
	_check(view._portrait.visible and view._portrait.texture.resource_path == CounterVisualCatalog.SUN_PORTRAIT, "painted living portrait visible")
	_check(not view._item_image.visible and not view._item_hotspot.visible, "no offered merchandise")
	_check(not view.get_node("%CustomerText").text.contains("最迟留到"), "no seller timeout label")
	await _capture("01_arrival")
	await _check_counter_occlusion(view)
	await service()
	_check(book._roster.get_child_count() == 0 and book._empty.visible, "book empty before conversation")
	await _capture("02_unmet_book")
	screen._close_drawer(); await _frames()
	await _click_button(view._customer_hotspot)
	_check(view._dialogue_action.visible and not view._trade_action.visible, "only dialogue action offered")
	await _click_button(view._dialogue_action)
	await _capture("03_greeting")
	_check(_session.counter_model().dialogue.body.contains("街面巡查") and _session.counter_model().dialogue.body.contains("军需采办"), "introduction explains duties")
	_check(_find_button(_main,MilitaryIntroduction.CHOICES[0]).text.contains("孙长官"), "player uses officer address")
	await _click(MilitaryIntroduction.CHOICES[0])
	_check(_session._day.state.social.intro_step == 1, "first real dialogue choice")
	_check(_session.counter_model().dialogue.body.contains("岗哨") and _session.counter_model().dialogue.body.contains("该停"), "military authority explained")
	await _capture("04_tasks")
	# Resume a journal-validated mid-conversation save through the same UI.
	var data := SaveCodec.new().encode(_session._day.state,27)
	var restored := SaveCodec.new().decode(data,_session.definition,27,_session._counter.catalog,true)
	_check(restored != null, "mid-dialogue save validates")
	if restored != null:
		_session._day.state = restored; _session.restored.emit(); _session.changed.emit()
		await create_timer(.3).timeout
		await _click_button(view._customer_hotspot); await _click_button(view._dialogue_action)
	_check(_find_button(_main,MilitaryIntroduction.CHOICES[1]) != null, "reload resumes second speech")
	await _click(MilitaryIntroduction.CHOICES[1])
	await _capture("05_namecard")
	await _click(MilitaryIntroduction.CHOICES[2])
	await create_timer(.3).timeout
	_check(_session._day.state.social.introduced and not view._portrait.visible, "farewell unlocks faction and removes visitor")
	await service()
	_check(book._roster.get_child_count() == 1 and _find_button(book,"接下采购单") != null, "tasks appear only after farewell")
	await _click("旧事"); await _capture("06_history")
	_check(book._body.text.contains("孙大元登门"), "meeting recorded in faction history")
	screen._close_drawer(); screen.get_node("%ScreenFlowCoordinator").show_panel(&"day")
	await _frames()
	var day := screen.get_node("Drawer/DrawerColumn/PanelStack/DayFlowPanel") as DayFlowPanel
	_check(not day._description.text.contains("这一带的街面") and not day._description.text.contains("孙大元登门"), "business panel no longer contains conversation")
	await _capture("07_business")
	_check(_session.execute("open_shop").ok, "normal opening after farewell")
	_check(_session.counter_model().active_id != MilitaryIntroduction.id(_session._day.state), "ordinary queue resumes")
	await _frames()
	_check(not view._counter_foreground.visible, "special occlusion removed for ordinary visitors")
	print("SUN VISIT UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _check_counter_occlusion(view: CounterView) -> void:
	# Compare rendered pixels with/without the visitor. Real wood and status strip
	# must stay identical; skin and uniform must never paint over the sill/table.
	await RenderingServer.frame_post_draw
	var with_person := root.get_texture().get_image()
	view._portrait.hide(); view._counter_foreground.hide()
	await _frames(); await RenderingServer.frame_post_draw
	var room_only := root.get_texture().get_image()
	var maximum := 0.0
	for x in [0.39,0.44,0.50,0.56,0.60]:
		for y in [0.480,0.495,0.52,0.57,0.62,0.72,0.85,0.95]:
			var at := Vector2i(int(root.size.x*x),int(root.size.y*y))
			var a := with_person.get_pixelv(at); var b := room_only.get_pixelv(at)
			maximum = maxf(maximum,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	_check(maximum < 0.012, "wooden sill tabletop and status remain unobstructed")
	var face := Vector2i(int(root.size.x*.50),int(root.size.y*.19))
	_check(with_person.get_pixelv(face) != room_only.get_pixelv(face), "portrait visible above the real sill")
	view._portrait.show(); view._counter_foreground.show()
	await _frames()
