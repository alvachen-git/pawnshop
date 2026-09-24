extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("BANGLE UI TIMEOUT");quit(1))
	_capture_prefix="bangle_1600" if "wide" in OS.get_cmdline_user_args() else "bangle_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720);root.content_scale_size=root.size
	_main=load("res://scenes/start_bangle_v40.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/bangle-ui/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0]);_check(_session.content_version==40,"default combined v40")
	PrecisionPreview.apply(_session,2,"gold_bangle","flawed","intact",false,"silk");BanglePreview.apply(_session,"matched")
	_session.restored.emit();_session.changed.emit();await _frames()
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	var v:CustomerVisit=_session._day.state.visits[0];var facts:=v.item.goods.duplicate(true)
	_check(screen._counter_view._item_image.material==null,"native alpha keeps gold shading")
	_check(screen._counter_view._item_image.size.x<screen._counter_view.size.x*.09,"counter bangle uses wearable scale")
	_check(screen._counter_view.get_hotspot(&"item").size.x>=screen._counter_view._item_image.size.x,"small bangle keeps usable hit target")
	await _capture("counter_scale")
	await _click_button(screen._counter_view.get_hotspot(&"item"));await _click("鉴定")
	_check(_session.counter_model().appraisal.buttons.size()==2,"two counter entrances")
	await _capture("counter")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk:=root.get_node_or_null("BangleDeskOverlay") as BangleDeskView
	_check(desk!=null,"gold item opens bangle desk");if desk==null:quit(1);return
	_check(desk.canvas.find_child("begin",true,false)==null and desk.canvas.find_child("exterior",true,false)==null,"no duplicate entry buttons")
	var initial_minutes:=_session._day.state.game_minutes
	await _click_button(desk.canvas.find_child("place",true,false))
	await _click_button(desk.canvas.find_child("add_20",true,false));await _click_button(desk.canvas.find_child("add_10",true,false))
	_check(desk.data().weighed and desk.data().measured==30,"manual balance matched fake")
	await _capture("balanced")
	await _click_button(desk.canvas.find_child("remove_10",true,false));await _click_button(desk.canvas.find_child("add_5",true,false));await _click_button(desk.canvas.find_child("add_5",true,false))
	_check(BangleAppraisal.total(desk.data())==30,"repeated denomination works")
	await _click_button(desk.canvas.find_child("part_stamp",true,false));await _click_button(desk.canvas.find_child("view",true,false))
	_check("stamp" in desk.data().viewed,"magnify records stamp");await _capture("stamp")
	await _click_button(desk.canvas.find_child("close_zoom",true,false))
	var stamp_atlas:Texture2D=desk.after_image.texture.atlas
	await _click_button(desk.canvas.find_child("part_inner",true,false))
	_check(desk.after_image.texture.atlas!=stamp_atlas,"inner band has separate unstamped artwork")
	await _capture("inner")
	var original_store:=_session._save;var failing:=FailingStore.new();failing.origin=_session._day.state.ghost_origin.duplicate(true);_session._save=failing
	await _click_button(desk.fire_button)
	_check(desk.data().active.is_empty() and desk.data().started.is_empty(),"failed start cannot play or record")
	_session._save=original_store;await _click_button(desk.fire_button)
	await create_timer(.25).timeout
	await _click_button(desk.canvas.find_child("stop_fire",true,false))
	_check(desk.data().finished.is_empty() and "inner" in desk.data().started,"early stop not completed")
	await _click_button(desk.fire_button);await create_timer(.8).timeout
	_check(not desk.data().active.is_empty() and desk.data().finished.is_empty(),"fire does not finish early")
	await create_timer(2.5).timeout;await _frames()
	_check("inner" in desk.data().finished and desk.data().active.is_empty(),"three second completion")
	_check(float(desk.after_image.material.get_shader_parameter("soot"))>.5,"smoke visible before wiping")
	await _capture("cooled")
	await _click_button(desk.canvas.find_child("wipe",true,false))
	_check(float(desk.after_image.material.get_shader_parameter("soot"))==0 and "inner" in desk.data().wiped,"wipe reveals comparison directly")
	_check((desk.after_image.texture as AtlasTexture).atlas.resource_path.ends_with("inner-band.png"),"actual inner coating detail image")
	_check(desk.canvas.find_child("compare",true,false)==null and desk.before_image.modulate==Color.WHITE,"no redundant comparison button or dim reference")
	await _capture("compared")
	await _click_button(desk.canvas.find_child("guide",true,false));var guide:=root.get_node("BangleGuide") as BangleGuideView
	for page in 3:
		_check(guide.page==page,"guide page");await _capture("guide_"+str(page));await _click_button(guide.canvas.find_child("next",true,false))
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	_check(_session._day.state.game_minutes==initial_minutes,"all internal actions free")
	await _click_button(desk.canvas.find_child("notes",true,false));await choose(desk.material_choice,3)
	_check(not desk.seal_button.disabled,"partial seal enabled");await _capture("notes")
	await _click_button(desk.seal_button)
	_check(root.get_node_or_null("BangleDeskOverlay")==null and not screen.get_node("%Drawer").visible,"seal returns counter")
	screen._route_from_customer(&"trade");await _click("商量价钱")
	var claims:=_main.find_child("BangleClaimForm",true,false) as WatchClaimForm
	_check(claims!=null,"claims form present");if claims==null:quit(1);return
	_check(claims.payload()=={"material":"plated"},"notes default speech")
	await choose(claims.selections.material,1);await _capture("claims")
	_check(BangleAppraisal.row(_session._day.state,v.item.instance_id).material=="plated","changing speech preserves note")
	await _click_button(claims.submit_button);await _capture("reply")
	v=_session._day.state.visits[0];_check(v.item.goods==facts,"UI actions preserve facts")
	# Metal cabinet guide learning.
	screen._close_drawer();PrecisionPreview.apply(_session,2,"gold_bangle");BanglePreview.apply(_session,"guide")
	_session.restored.emit();_session.changed.emit();await _frames();screen._close_drawer();screen._close_menu();screen._counter_view.dismiss_contexts()
	_check(screen.facilities.enter("",false),"facility entry");await _frames()
	await _click_button(screen.facilities.room.hotspots["knowledge/luxury_metal"])
	guide=root.get_node_or_null("BangleGuide") as BangleGuideView
	_check(guide!=null,"third cabinet opens guide");if guide==null:quit(1);return
	var cash:=_session._day.state.cash;var prep:=PreparationService.count(_session._day.state)
	await _click_button(guide.study)
	_check(ShopKnowledgeService.mastered(_session._day.state,"luxury_metal") and PreparationService.count(_session._day.state)==prep+1 and _session._day.state.cash==cash,"learn once free")
	_check(guide.study.disabled,"repeat study disabled");await _capture("learned")
	guide.queue_free();await _frames();screen.facilities.room.queue_free();await _frames()
	# Hidden detail, partial notes without any equipment work, and no-tools gate.
	PrecisionPreview.apply(_session,2,"gold_bangle","flawed","minor",true,"opera");BanglePreview.apply(_session,"matched")
	_session.restored.emit();_session.changed.emit();await _frames();screen._close_drawer()
	v=_session._day.state.visits[0];_session.fan_command("luxury_begin",v.item.instance_id,"2")
	desk=BangleDeskView.open_bangle(screen,_session,v.item.instance_id);await _frames()
	desk.act({"op":"select","part":"stamp"});var angle:int=v.item.goods.bangle_value.angles.stamp
	desk.act({"op":"turn","angle":(angle+1)%3})
	_check((desk.after_image.texture as AtlasTexture).atlas.resource_path.ends_with("base.png"),"hidden clue not shown in wrong angle")
	desk.act({"op":"turn","angle":angle})
	_check((desk.after_image.texture as AtlasTexture).atlas.resource_path.ends_with("plated.png"),"turn exposes hidden detail")
	await _capture("hidden_detail");desk.show_notes();await _click_button(desk.seal_button);await _frames()
	PrecisionPreview.apply(_session,0,"gold_bangle","sound","intact",false,"factory");_session.restored.emit();_session.changed.emit();await _frames()
	v=_session._day.state.visits[0];BangleDeskView.open_bangle(screen,_session,v.item.instance_id);await _frames()
	var entry:=root.get_node_or_null("BangleEntry") as ConfirmationDialog
	_check(entry!=null and entry.get_ok_button().disabled,"missing tools direct entry gated")
	_check(_session.fan_command("luxury_exterior",v.item.instance_id).ok,"no-tools exterior remains usable")
	entry.queue_free();await _frames()
	print("BANGLE UI: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)

func _capture(label: String) -> void:
	await _frames();await RenderingServer.frame_post_draw
	var folder:="res://docs/qa/bangle-v39/";DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png")==OK,"capture "+label)
