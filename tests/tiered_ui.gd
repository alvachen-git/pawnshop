extends "res://tests/integrated_ui_smoke.gd"

var original: RunState

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("PRECISION UI TIMEOUT"); quit(1))
	_capture_prefix = "precision_1600" if "wide" in OS.get_cmdline_user_args() else "precision_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/tiered_manifest.json" # Frozen v32 regression fixture.
	_main.get_node("Bootstrap").save_path = "user://tests/precision-ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 32 and _session.definition.id == "precision_ten","default new game uses v32")
	original = RunSnapshot.copy(_session._day.state)
	await install(0)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	var model: Dictionary = _session.counter_model().appraisal
	_check(model.buttons.size() == 3 and model.buttons[0].enabled and not model.buttons[1].enabled,"three concise actions, basic needs no equipment")
	await _capture("basic_missing")
	await _click(model.buttons[0].label)
	_check(_session._day.state.game_minutes == 5,"basic UI costs five")
	await _capture("basic_checked")
	await install(3)
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk := root.get_node_or_null("TieredAppraisalOverlay") as TieredAppraisalView
	_check(desk != null,"counter opens visual appraisal")
	if desk == null: quit(1); return
	_check(_session._day.state.game_minutes == 10,"two-tier starts paid at entrance")
	_check(desk.object_plate.texture != null and desk.reference_plate.texture != null,"object and atlas art loaded")
	await _capture("standard_ambiguous")
	await pair(desk,"unsure")
	await choose(desk.identity,desk.identity_keys.find("unsure"))
	await choose(desk.condition,desk.condition_keys.find("unsure"))
	await _click_button(desk.seal)
	_check(TieredAppraisal.stage(_session._day.state,desk.item_id,2).committed,"standard conclusion kept")
	await _click_button(desk.begin_buttons[2])
	_check(_session._day.state.game_minutes == 20,"deep after standard adds ten")
	await pair(desk,"different")
	var v := _session._counter.customers.active(_session._day.state)
	var book := LuxuryAppraisalService.info(_session._day.state,v.item)
	await choose(desk.identity,desk.identity_keys.find(book.identity[v.item.selected_variant_id]))
	await choose(desk.condition,desk.condition_keys.find(book.condition[v.item.selected_variant_id]))
	await _click_button(desk.canvas.find_child("zoom",true,false))
	_check(desk.zoom_layer.visible,"zoom actual button")
	await _capture("deep_zoom")
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	root.push_input(escape,true); await _frames()
	_check(not desk.zoom_layer.visible,"escape first closes zoom")
	await _click_button(desk.seal)
	_check(TieredAppraisal.correct(_session._day.state,v.item,3),"mouse-selected detailed evidence supports revised conclusion")
	_check(TieredAppraisal.stage(_session._day.state,v.item.instance_id,2).identity == "unsure","deep does not overwrite previous conclusion")
	_check(desk.body.text.length() < 110 and desk.observation.text.length() < 100,"short contextual text")
	_check(desk.seal.get_global_rect().end.y < root.size.y,"actions remain on screen")
	await _capture("deep_sealed")
	await _click_button(desk.canvas.find_child("close",true,false))
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"trade"); await _frames()
	await _click_trade_intent("luxury_pressure","")
	_check(WealthyCustomers.trade(_session._day.state,v).value == 300,"advanced evidence only excludes unchecked exterior")
	# All ten actual atlases load through both stages, including the silver-service alias.
	for short in ["embroidery","gold_bangle","gold_watch","mantel_clock","pearl_necklace","jade_pendant","album","porcelain_vase","repeater","silver_set"]:
		await install(3,short)
		v = _session._counter.customers.active(_session._day.state)
		_check(_session.fan_command("luxury_begin",v.item.instance_id,"3").ok,"direct deep " + short)
		desk = TieredAppraisalView.create(screen,_session,v.item.instance_id); await _frames(); desk.tier = 3; desk.refresh(); await _frames()
		_check(desk.object_plate.texture != null and desk.reference_plate.texture != null,"two valid plates " + short)
		await _capture(short)
		desk.queue_free(); await _frames()
	await install(2)
	_session._day.state.phase = &"pre_open"; _session._day.state.shop_growth.precision.kits.clear()
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var trade_panel := _find_trade_panel(_main)
	if trade_panel._bargain_popup.visible: await _click_button(trade_panel._bargain_popup.close_button)
	screen._counter_view.dismiss_contexts()
	var close := screen.get_node("%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	await _click_button(screen.get_node("%MenuButton")); await _click("修缮与查铺"); await create_timer(.6).timeout
	_check(screen.facilities.in_room,"enter facilities through menu")
	await _frames(); await _click_button(screen.facilities.room.hotspots.bench)
	await _capture("facilities_two")
	var prior_cash := _session._day.state.cash
	await _click("建三级精鉴台 · 160银元 / 1行动点 / 两夜工期")
	_check(_session._day.state.cash == prior_cash-160 and FanAppraisalService.bench_level(_session._day.state) == 2,"UI commissions third bench while level two stays usable")
	await _capture("construction")
	_session._day.state.current_night_index = 8; _session.changed.emit(); await _frames()
	await _click("添置钟表开验具 · 50银元 / 1行动点")
	await _click("添置钟表深验组件 · 80银元 / 1行动点")
	_check(FanAppraisalService.bench_level(_session._day.state) == 3 and TieredAppraisal.owns(_session._day.state,"clock_deep"),"UI purchases standard and deep kits after completion")
	await _capture("facilities_three")
	print("PRECISION UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func install(level: int, short := "porcelain_vase") -> void:
	_session._day.state = RunSnapshot.copy(original)
	PrecisionPreview.apply(_session,level,short)
	_session.restored.emit(); _session.changed.emit(); await _frames(); await create_timer(.15).timeout

func pair(desk: TieredAppraisalView, note: String) -> void:
	for index in 2:
		await _click_button(desk.detail_buttons[index])
		var relative := Vector2(.25 if index == 0 else .75,.5)
		for plate in [desk.object_plate,desk.reference_plate]:
			await click_point(plate.get_global_transform()* (plate.size*relative))
		await _click_button(desk.canvas.find_child("note_"+note,true,false))
	_check(_session._day.state.game_minutes == (10 if desk.tier == 2 else 20),"circle and comparison free")

func choose(button: OptionButton, index: int) -> void:
	# Click a native popup row, translating embedded-window coordinates.
	await click_point(button.get_global_rect().get_center())
	var popup := button.get_popup()
	var point := Vector2(popup.size.x/2.0,4+(popup.size.y-8)*(index+.5)/popup.item_count)
	if popup.is_embedded(): await click_point(Vector2(popup.position)+point)
	else:
		var motion := InputEventMouseMotion.new(); motion.position = point; popup.push_input(motion,true)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = pressed; popup.push_input(event,true)
		await _frames()
	_check(button.selected == index,"verdict selected via popup")

func click_point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = pressed; root.push_input(event,true)
	await _frames()

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/precision-v32/"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture " + label)
