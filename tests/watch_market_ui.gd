extends "res://tests/watch_ui.gd"

func _run() -> void:
	create_timer(140).timeout.connect(func() -> void: push_error("WATCH MARKET UI TIMEOUT"); quit(1))
	_capture_prefix = "watch34_1600" if "wide" in OS.get_cmdline_user_args() else "watch34_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").manifest_path = "res://data/watch_market_manifest.json"; _main.get_node("Bootstrap").save_path = "user://tests/watch34-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 34,"new game v34")
	PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,"guide")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._close_drawer(); _check(screen.facilities.enter("",false),"enter facilities")
	await _frames()
	var room := screen.facilities.room
	var info := ShopKnowledgeService.topic_info(_session.definition,"luxury_watch")
	_check(info.cabinet == 2 and room.hotspots["knowledge/luxury_watch"].position.x < room.hotspots["knowledge/luxury_metal"].position.x,"guide placed before third cabinet")
	await _capture("cabinet")
	await _click_button(room.hotspots["knowledge/luxury_watch"])
	var guide := root.get_node_or_null("WatchGuide") as WatchGuideView
	_check(guide != null,"second cabinet opens guide")
	if guide == null: quit(1); return
	var before := _session.read_state()
	for i in 3:
		await _click_button(guide.content.find_child("sample_"+str(i),true,false))
		_check(guide.player.playing,"guide sample actually plays")
		await create_timer(4.2).timeout
		_check(guide.progress.value > 3.5 and guide.progress.value < 5.5,"playback follows audible clip time")
		_check(guide.sample_buttons[i].button_pressed,"active sample visible")
		await create_timer(4.2).timeout
		_check(not guide.player.playing and guide.progress.value == 8,"full clip completes including final silence")
		_check(guide.playback_status.text.contains("已听完"),"silent ending distinguished from stopped playback")
		await _click_button(guide.content.find_child("stop_sample",true,false))
		_check(not guide.player.playing,"sample stops")
	_check(_session.read_state() == before,"samples read-only")
	await _capture("guide_listening")
	await _click_button(guide.canvas.find_child("next",true,false)); _check(guide.page == 1,"mechanism chapter")
	var reference_count := 0
	for child in guide.content.get_children():
		if child is TextureRect: reference_count += 1
	_check(reference_count == 1 and guide.content.has_node("genuine_reference"),"only annotated genuine reference shown")
	await _capture("guide_mechanism")
	await _click_button(guide.canvas.find_child("next",true,false)); _check(guide.page == 0,"two chapters only; no price chapter")
	await _click_button(guide.canvas.find_child("previous",true,false)); _check(guide.page == 1,"previous wraps across two chapters")
	var cash: int = _session._day.state.cash; var prep := PreparationService.count(_session._day.state)
	await _click_button(guide.study)
	_check(ShopKnowledgeService.mastered(_session._day.state,"luxury_watch"),"guide learning unlocks actual knowledge")
	_check(_session._day.state.cash == cash and PreparationService.count(_session._day.state) == prep+1,"one preparation no silver")
	_check(guide.study.disabled,"cannot learn twice")
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	await _click_button(room.hotspots["knowledge/luxury_watch"])
	guide = root.get_node_or_null("WatchGuide")
	_check(guide != null and guide.study.disabled,"free reread mastered")
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	screen.facilities.leave(false)
	PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,"fault")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var v: CustomerVisit = _session._day.state.visits[0]
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	var appraisal: Dictionary = _session.counter_model().appraisal.visual
	_check(appraisal.estimate == "25–500" and appraisal.judgement == "暂不判断","ordinary summary with wide initial watch range")
	await _capture("appraisal_summary")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk := root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
	_check(desk != null,"v34 desk")
	_check(desk.mark_button == null and desk.clear_button == null,"mark controls removed")
	_check(not desk.seek.editable,"timeline is playback progress only")
	for child in desk.canvas.get_children():
		if child is Label: _check(not child.text.contains("指南在铺内第二柜"),"cabinet hint removed")
	await _click_button(desk.wind_button); await _click_button(desk.listen_button); await create_timer(8.6).timeout
	await _click_button(desk.note_button)
	_check(not desk.seal_button.disabled and desk.data().spots.is_empty(),"can seal with just flat listening and no mechanism inspection")
	await _capture("partial_seal_available")
	await _click_button(desk.note_panel.find_child("close_notes",true,false))
	await _click_button(desk.vertical_button); await _click_button(desk.listen_button); await create_timer(8.6).timeout
	_check(desk.data().marks.is_empty(),"full listening needs no manual marks")
	await _capture("listening_without_marks")
	await _click_button(desk.note_button); await choose(desk.running_choice,1)
	_check(not TieredAppraisal.stage(_session._day.state,v.item.instance_id,2).committed,"partial judgment remains draft")
	await _capture("partial_evidence")
	await _click_button(desk.seal_button)
	_check(TieredAppraisal.stage(_session._day.state,v.item.instance_id,2).committed,"partial judgment sealed through UI")
	_check(root.get_node_or_null("WatchDeskOverlay") == null,"successful seal closes watch desk")
	_check(not screen.get_node("%Drawer").visible,"successful seal returns to counter without drawer")
	await _capture("sealed_counter")
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	_check(_session.counter_model().appraisal.visual.judgement.contains("换姿态后反复停顿"),"summary shows player's running judgment")
	await _capture("appraisal_observed")
	_check(TieredAppraisal.pending(_session._day.state,v) == ["running"],"running-only evidence available")
	_check(_session.counter_command("luxury_pressure",v.visit_id).ok,"running-only proof")
	_check("running" in WatchEconomy.owner(_session._day.state,v).accepted,"unmarked correct running judgment accepted")
	_check(v.item.goods.watch_value.actual == 400,"sound original with fault worth 400 unchanged")
	var buttons: Array = _session.counter_model().trade.buttons
	_check(buttons.any(func(b: Dictionary) -> bool: return b.command == "watch_bluff"),"bluff available separately")
	screen._route_from_customer(&"trade")
	await _click("商量价钱")
	await _capture("negotiation")
	for b in buttons:
		if b.command == "watch_bluff": await _click(b.label); break
	_check(WatchEconomy.owner(_session._day.state,v).bluff_used,"actual UI bluff dispatch")
	_check(v.item.goods.watch_value.actual == 400,"UI bargaining preserves value")
	print("WATCH MARKET UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/watch-v34/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture "+label)
