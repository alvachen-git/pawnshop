extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("UNIFIED UI TIMEOUT"); quit(1))
	_capture_prefix = "unified_1600" if "wide" in OS.get_cmdline_user_args() else "unified_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	# Explicit legacy catalog: the default entry now starts the v31 unified run.
	_main.get_node("Bootstrap").manifest_path = "res://data/unified_manifest.json"
	_main.get_node("Bootstrap").save_path = "user://tests/unified-ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 30 and _session.definition.id == "unified_ten", "title starts unified v30")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	await install("unified/introduction")
	_check(screen._counter_view._portrait.visible and screen._counter_view._counter_foreground.visible, "Sun portrait and counter mask visible")
	_check(not screen._counter_view._item_hotspot.visible and not screen.facilities.available(), "itemless reception locks facilities")
	await _capture("introduction")
	await _click_button(screen._counter_view.get_hotspot(&"customer"))
	await _click("交谈")
	for step in 3:
		await _click(MilitaryIntroduction.CHOICES[step])
	_check(_session._day.state.social.introduced, "real clicks finish reception")
	await _click_button(screen._counter_view.get_hotspot(&"social"))
	_check(screen._social_panel.visible, "physical book opens social panel")
	await _capture("book")
	await _click_button(screen._social_panel._close)
	_check(not screen._social_panel.visible, "close book")
	await install("unified/upgrade")
	var close := screen.get_node("%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	await _click_button(screen.facilities.entry)
	await create_timer(.5).timeout
	_check(screen.facilities.in_room and not screen._social_panel.visible, "facilities navigation in unified run")
	await _click_button(screen.facilities.room.hotspots.bench)
	await _capture("facilities")
	await install("unified/minor")
	_check(not screen._counter_view._counter_foreground.visible, "Sun mask cleared for ordinary customer")
	await _capture("fan")
	await install("unified-social/plaque")
	_check(screen._counter_view.get_hotspot(&"plaque").visible, "earned plaque is a counter entry")
	await _click_button(screen._counter_view.get_hotspot(&"social"))
	await _capture("plaque_book")
	await install("unified-companion/idle-8")
	_check(screen._counter_view.companion.visible and not screen._social_panel.visible, "Aqi companion coexists after restoring")
	await _capture("companion")
	await install("unified-story/call")
	_check(_session.event_model().pending_id == MirrorDreamService.CALL and not screen._social_panel.visible, "crying at night keeps narrative focus")
	await _capture("call")
	print("UNIFIED UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data,_session.definition,30,_session._counter.catalog,true)
	_check(state != null,"verified UI fixture " + stage + " " + codec.error_message)
	if state == null: return
	_session._day.state = state
	_session.message = ""
	_session.restored.emit(); _session.changed.emit()
	await _frames()
	await create_timer(.4).timeout

func _capture(label: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/unified-v30/"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder + _capture_prefix + "_" + label + ".png") == OK,"capture " + label)
