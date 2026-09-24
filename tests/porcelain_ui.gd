extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func()->void:push_error("PORCELAIN UI TIMEOUT");quit(1))
	_capture_prefix="porcelain_1600" if "wide" in OS.get_cmdline_user_args() else "porcelain_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720);root.content_scale_size=root.size
	_main=load("res://scenes/start.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/porcelain-ui/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0]);_check(_session.content_version==42,"combined v42 default")
	PrecisionPreview.apply(_session,2,"porcelain_vase","mended","intact",false,"antique")
	PorcelainPreview.apply(_session,{"--precision-porcelain-case":"partial","--precision-era":"qing","--precision-craft":"fine"})
	_session.restored.emit();_session.changed.emit();await _frames()
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	var v:CustomerVisit=_session._day.state.visits[0];var fixed:=v.item.goods.duplicate(true)
	await _capture("counter")
	await _click_button(screen._counter_view.get_hotspot(&"item"));await _click("鉴定")
	_check(_session.counter_model().appraisal.buttons.size()==2,"only exterior and apparatus counter entries")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk:=root.get_node_or_null("PorcelainDeskOverlay") as PorcelainDeskView
	_check(desk!=null,"porcelain item routed to desk");if desk==null:quit(1);return
	_check(desk.canvas.find_child("exterior",true,false)==null and desk.canvas.find_child("begin",true,false)==null,"no redundant apparatus entrances")
	await _capture("desk")
	var minutes:=_session._day.state.game_minutes
	for light in ["left","front","right"]:
		_check(desk.canvas.find_child("light_"+light,true,false)==null,"redundant light control removed")
	_check(desk.reference_choice.visible and desk.canvas.find_child("sample",true,false)!=null,"era references and sample switch retained")
	await _click_button(desk.canvas.find_child("right",true,false));_check(desk.data().angle==1,"right view")
	await _click_button(desk.canvas.find_child("group_painting",true,false));await _click_button(desk.canvas.find_child("zoom",true,false))
	await choose(desk.reference_choice,3)
	_check(desk.data().reference=="republic" and desk.data().zoom,"reference change retains zoom")
	await _capture("painting_zoom")
	await _click_button(desk.canvas.find_child("zoom",true,false));await _click_button(desk.canvas.find_child("flip",true,false))
	_check(desk.data().group=="foot","flip shows foot")
	await _capture("foot")
	await _click_button(desk.canvas.find_child("guide",true,false));var guide:=root.get_node("PorcelainGuide") as PorcelainGuideView
	var observations:Array=desk.data().viewed.duplicate()
	for page in 5:
		_check(guide.page==page,"five guide pages")
		if page<4:await _click_button(guide.canvas.find_child("guide_foot",true,false))
		else:
			for part in PorcelainAppraisal.GROUPS:
				await _click_button(guide.canvas.find_child("craft_"+part,true,false))
				_check(guide.craft_group==part,"craft guide switches part "+part)
				await _capture("craft_"+part)
		await _capture("guide_"+str(page));await _click_button(guide.canvas.find_child("next",true,false))
	_check(observations==desk.data().viewed,"guide does not add object observations")
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	_check(minutes==_session._day.state.game_minutes,"all operations after entry free")
	await _click_button(desk.canvas.find_child("notes",true,false));await choose(desk.era_choice,3)
	_check(not desk.seal_button.disabled,"partial judgment can seal");await _capture("notes")
	await _click_button(desk.seal_button)
	_check(root.get_node_or_null("PorcelainDeskOverlay")==null and not screen.get_node("%Drawer").visible,"seal returns counter")
	screen._route_from_customer(&"trade");await _click("商量价钱")
	var claims:=_main.find_child("PorcelainClaimForm",true,false) as WatchClaimForm
	_check(claims!=null,"era and craft claims form");if claims==null:quit(1);return
	_check(claims.payload()=={"era":"qing"},"default private note")
	await choose(claims.selections.era,3);await _capture("claims")
	_check(PorcelainAppraisal.row(_session._day.state,v.item.instance_id).era=="qing","changed speech keeps private note")
	await _click_button(claims.submit_button);await _capture("reply")
	_check(_session._day.state.visits[0].item.goods==fixed,"UI keeps fixed value")
	# Cabinet guide learning and no-equipment preview.
	screen._close_drawer();PrecisionPreview.apply(_session,2,"porcelain_vase");PorcelainPreview.apply(_session,{"--precision-porcelain-case":"guide"})
	_session.restored.emit();_session.changed.emit();await _frames();screen._close_drawer();screen._close_menu();screen._counter_view.dismiss_contexts()
	_check(screen.facilities.enter("",false),"enter book cabinets");await _frames()
	await _click_button(screen.facilities.room.hotspots["knowledge/luxury_porcelain"])
	guide=root.get_node_or_null("PorcelainGuide") as PorcelainGuideView;_check(guide!=null,"existing porcelain cabinet opens guide");if guide==null:quit(1);return
	var cash:=_session._day.state.cash;var prep:=PreparationService.count(_session._day.state)
	await _click_button(guide.study)
	_check(ShopKnowledgeService.mastered(_session._day.state,"luxury_porcelain") and PreparationService.count(_session._day.state)==prep+1 and _session._day.state.cash==cash,"free study once")
	_check(guide.study.disabled,"repeat learning disabled");await _capture("learned")
	guide.queue_free();await _frames();screen.facilities.room.queue_free();await _frames()
	PrecisionPreview.apply(_session,0,"porcelain_vase");_session.restored.emit();_session.changed.emit();await _frames()
	v=_session._day.state.visits[0];PorcelainDeskView.open_porcelain(screen,_session,v.item.instance_id);await _frames()
	var entry:=root.get_node_or_null("PorcelainEntry") as ConfirmationDialog
	_check(entry!=null and entry.get_ok_button().disabled,"missing equipment gated")
	_check(_session.fan_command("luxury_exterior",v.item.instance_id).ok,"no equipment exterior check")
	await _capture("missing_equipment");entry.queue_free()
	print("PORCELAIN UI: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)

func _capture(label:String) -> void:
	await _frames();await RenderingServer.frame_post_draw
	var folder:="res://docs/qa/porcelain-v41/";DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png")==OK,"capture "+label)
