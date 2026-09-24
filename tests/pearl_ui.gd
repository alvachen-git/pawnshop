extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("PEARL UI TIMEOUT"); quit(1))
	_capture_prefix = "pearl_1600" if "wide" in OS.get_cmdline_user_args() else "pearl_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").manifest_path = "res://data/pearl_market_manifest.json"; _main.get_node("Bootstrap").save_path = "user://tests/pearl-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 38,"default new game v38")
	PrecisionPreview.apply(_session,2,"pearl_necklace","mended","intact",false,"opera"); PearlPreview.apply(_session,"few")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var v: CustomerVisit = _session._day.state.visits[0]
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	_check(_session.counter_model().appraisal.buttons.size()==2,"no deep entry")
	var before_entry := _session._day.state.game_minutes
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk := root.get_node_or_null("PearlDeskOverlay") as PearlDeskView
	_check(desk != null,"item route opens pearl desk")
	if desk == null: quit(1); return
	_check(_session._day.state.game_minutes==before_entry+10,"counter charges once before desk")
	_check(desk.canvas.find_child("exterior",true,false)==null and desk.canvas.find_child("begin",true,false)==null,"desk has no duplicate appraisal entry buttons")
	await _capture("desk")
	var bad := -1; var good := -1
	for b in v.item.goods.pearl_value.beads:
		if b.quality=="imitation": bad=int(b.index)
		else: good=int(b.index)
	await click_point(desk.bead_buttons[bad].get_global_rect().get_center())
	await _click_button(desk.canvas.find_child("hole",true,false))
	_check(bad in desk.data().holes,"hole records distinct bead")
	var original := desk.pearl_image.texture as AtlasTexture
	await _click_button(desk.canvas.find_child("turn_right",true,false))
	_check((desk.pearl_image.texture as AtlasTexture).region != original.region,"turn changes image region")
	await _click_button(desk.canvas.find_child("light_left",true,false))
	_check(desk.pearl_image.material.get_shader_parameter("light_x")<0,"light changes rendered material")
	await _capture("hole")
	await _click_button(desk.canvas.find_child("zoom",true,false))
	var kept_angle:int=desk.data().angles[str(bad)]
	await _click_button(desk.canvas.find_child("compare",true,false))
	await click_point(desk.bead_buttons[good].get_global_rect().get_center())
	_check(desk.hole_view and desk.zoomed and desk.data().angles[str(good)]==kept_angle,"switching pearls keeps hole zoom and rotation")
	_check(good in desk.data().holes and desk.pearl_image.scale.x>1,"retained hole view records newly inspected bead")
	await _click_button(desk.canvas.find_child("compare",true,false))
	_check(desk.data().pairs.size()==1,"two selected beads compare")
	await _capture("compare")
	for side in ["front","right","left"]:
		await _click_button(desk.canvas.find_child("light_"+side,true,false))
		await _click_button(desk.canvas.find_child("turn_left",true,false))
		kept_angle=int(desk.data().angles[str(desk.data().selected)])
		for bead_index in [0,1,2]:
			await click_point(desk.bead_buttons[bead_index].get_global_rect().get_center())
			_check(desk.data().light==side and desk.data().angles[str(bead_index)]==kept_angle and desk.hole_view and desk.zoomed,"batch scan retains full setup")
		_check((desk.canvas.find_child("light_"+side,true,false) as Button).button_pressed,"active light remains selected")
	await _capture("batch_setup")
	await _click_button(desk.canvas.find_child("hole",true,false))
	await _click_button(desk.canvas.find_child("zoom",true,false))
	var untouched := 0
	while untouched in desk.data().holes: untouched+=1
	await click_point(desk.bead_buttons[untouched].get_global_rect().get_center())
	_check(not desk.hole_view and not desk.zoomed and untouched not in desk.data().holes,"surface and normal zoom also persist without claiming unseen hole")
	await _click_button(desk.canvas.find_child("guide",true,false))
	var guide := root.get_node("PearlGuide") as PearlGuideView
	for page in 3:
		_check(guide.page==page,"guide page")
		await _capture("guide_"+str(page))
		await _click_button(guide.canvas.find_child("next",true,false))
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	_check(_session._day.state.game_minutes==before_entry+10,"turning comparison and guide are free")
	await _click_button(desk.canvas.find_child("notes",true,false))
	await choose(desk.material_choice,1)
	_check(not desk.seal_button.disabled,"partial notes permitted")
	await _capture("notes")
	await _click_button(desk.seal_button)
	_check(root.get_node_or_null("PearlDeskOverlay")==null and not screen.get_node("%Drawer").visible,"seal returns counter")
	screen._route_from_customer(&"trade"); await _click("商量价钱")
	var claims := _main.find_child("PearlClaimForm",true,false) as WatchClaimForm
	_check(claims!=null,"pearl claims visible")
	if claims==null: quit(1); return
	_check(claims.payload()=={"material":"none"},"notes defaults")
	await choose(claims.selections.material,5)
	_check(PearlAppraisal.row(_session._day.state,v.item.instance_id).material=="none","speech separate from notes")
	await _capture("claims")
	var actual:int=v.item.goods.pearl_value.actual
	await _click_button(claims.submit_button)
	_check(v.item.goods.pearl_value.actual==actual,"claim actual immutable")
	await _capture("reply")
	# Fifth-cabinet entry and first study, while second cabinet remains the watch guide.
	screen._close_drawer(); PrecisionPreview.apply(_session,2,"pearl_necklace"); PearlPreview.apply(_session,"guide")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	screen._close_drawer(); screen._close_menu(); screen._counter_view.dismiss_contexts()
	_check(screen.facilities.enter("",false),"enter facilities for pearl guide")
	await _frames()
	var room:=screen.facilities.room
	await _click_button(room.hotspots["knowledge/luxury_jade"])
	guide=root.get_node_or_null("PearlGuide") as PearlGuideView
	_check(guide!=null and ShopKnowledgeService.topic_info(_session.definition,"luxury_jade").cabinet==5,"fifth cabinet pearl guide")
	var prep:=PreparationService.count(_session._day.state)
	await _click_button(guide.study)
	_check(guide.study.disabled and PreparationService.count(_session._day.state)==prep+1,"study once")
	await _capture("cabinet_study")
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	await _click_button(room.hotspots["knowledge/luxury_watch"])
	var watchguide:=root.get_node_or_null("WatchGuide") as WatchGuideView
	_check(watchguide!=null,"watch guide still second cabinet")
	watchguide.queue_free(); await _frames(); screen.facilities.leave(false)
	PrecisionPreview.apply(_session,0,"pearl_necklace","sound","minor",false,"factory")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	v=_session._day.state.visits[0]
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	_check(not _session.counter_model().appraisal.buttons[1].enabled,"missing equipment gate visible")
	await _click(_session.counter_model().appraisal.buttons[0].label)
	_check(TieredAppraisal.record(_session._day.state,v.item.instance_id).get("exterior",false),"basic without equipment")
	await _capture("no_equipment")
	PearlDeskView.open_pearl(screen,_session,v.item.instance_id); await _frames()
	var entry := root.get_node_or_null("PearlEntry") as ConfirmationDialog
	_check(entry!=null and entry.get_ok_button().disabled and root.get_node_or_null("PearlDeskOverlay")==null,"direct entry respects equipment gate")
	entry.queue_free(); await _frames()
	# Unpaid inventory/facility route: explicit cost, then same paid desk; hidden holes require turning.
	PrecisionPreview.apply(_session,2,"pearl_necklace","mended","intact",true,"opera"); PearlPreview.apply(_session,"few")
	_session.restored.emit(); _session.changed.emit(); await _frames(); screen._close_drawer()
	v=_session._day.state.visits[0]
	before_entry=_session._day.state.game_minutes
	LuxuryAppraisalView.open(screen,_session,v.item.instance_id); await _frames()
	entry=root.get_node_or_null("PearlEntry") as ConfirmationDialog
	_check(entry!=null and not entry.get_ok_button().disabled and _session._day.state.game_minutes==before_entry,"direct entry presents cost without charging")
	entry.confirmed.emit(); await _frames()
	desk=root.get_node_or_null("PearlDeskOverlay") as PearlDeskView
	_check(desk!=null and _session._day.state.game_minutes==before_entry+10,"direct entry uses paid transaction")
	for bead in v.item.goods.pearl_value.beads:
		if bead.quality=="imitation": bad=int(bead.index); break
	desk.select_bead(bad); desk.show_hole()
	var hole_angle:int=v.item.goods.pearl_value.beads[bad].hole_angle
	desk.act({"op":"turn","index":bad,"angle":(hole_angle+1)%3})
	_check((desk.pearl_image.texture as AtlasTexture).region.position.y==0,"hidden hole not visible from wrong angle")
	await _capture("hidden_turn")
	desk.act({"op":"turn","index":bad,"angle":hole_angle})
	_check((desk.pearl_image.texture as AtlasTexture).region.position.y>0,"turn reveals hidden coating detail")
	await _capture("hidden_hole")
	desk.queue_free(); await _frames()
	LuxuryAppraisalView.open(screen,_session,v.item.instance_id); await _frames()
	_check(root.get_node_or_null("PearlDeskOverlay")!=null and root.get_node_or_null("PearlEntry")==null and _session._day.state.game_minutes==before_entry+10,"paid review opens directly without another charge")
	root.get_node("PearlDeskOverlay").queue_free(); await _frames()
	screen._close_drawer()
	print("PEARL UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures==0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/pearl-v38/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png")==OK,"capture "+label)
