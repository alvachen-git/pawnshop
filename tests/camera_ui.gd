extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func()->void:push_error("CAMERA UI TIMEOUT");quit(1))
	_capture_prefix="camera_1600" if "wide" in OS.get_cmdline_user_args() else "camera_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720);root.content_scale_size=root.size
	_main=load("res://scenes/start.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/camera-ui/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0]);_check(_session.content_version==43,"v43 default")
	PrecisionPreview.apply(_session,2,"camera","sound","intact",false,"factory");CameraPreview.apply(_session,"haze")
	_session.restored.emit();_session.changed.emit();await _frames()
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	var v:CustomerVisit=_session._day.state.visits[0];var fixed:=v.item.goods.duplicate(true)
	_check(CounterVisualCatalog.front("luxury.camera").resource_path == "res://assets/camera_desk/camera_counter_painted.png", "inventory and resale camera image")
	_check(CounterVisualCatalog.images({"item_asset":"luxury.camera"})[0].path == "res://assets/camera_desk/camera_counter_painted.png", "camera inspection image")
	_check(CounterVisualCatalog.front("luxury.embroidery").resource_path.ends_with("embroidery.svg"), "legacy embroidery image preserved")
	await _capture("counter")
	await _click_button(screen._counter_view.get_hotspot(&"item"));await _click("鉴定")
	_check(_session.counter_model().appraisal.buttons.size()==2,"only exterior and apparatus entries")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk:=root.get_node_or_null("CameraDeskOverlay") as CameraDeskView
	_check(desk!=null,"camera desk routed");if desk==null:quit(1);return
	await _capture("identity")
	var saved_facts:Dictionary=v.item.goods.camera_value.duplicate(true)
	for variant in CameraEconomy.ENGRAVINGS:
		v.item.goods.camera_value.identity="imitation";v.item.goods.camera_value["engraving"]=variant
		desk.refresh();await _capture("imitation_"+variant)
		_check(desk.object_image.texture!=desk.reference_image.texture,"counterfeit and reference have distinct images")
	v.item.goods.camera_value=saved_facts;desk.refresh()
	await _click_button(desk.canvas.find_child("group_lens",true,false))
	await _click_button(desk.canvas.find_child("lens_2",true,false))
	_check(desk.data().light=="right","lens control works")
	await _capture("lens")
	await _click_button(desk.canvas.find_child("group_aperture",true,false))
	var before:Rect2=(desk.object_image.texture as AtlasTexture).region
	await _click_button(desk.canvas.find_child("aperture_0",true,false))
	_check((desk.object_image.texture as AtlasTexture).region!=before,"aperture image visibly changes")
	await _capture("aperture_open")
	await _click_button(desk.canvas.find_child("aperture_2",true,false));await _capture("aperture_narrow")
	await _click_button(desk.canvas.find_child("group_shutter",true,false))
	await _click_button(desk.canvas.find_child("shutter_3",true,false))
	_check(not desk.shutter.wound,"unwound does not open curtain")
	await _click_button(desk.canvas.find_child("shutter_0",true,false))
	var original_store:=_session._save;var failed_store:=FailingStore.new();failed_store.origin=_session._day.state.ghost_origin.duplicate(true);_session._save=failed_store
	var tests_before:Array=desk.data().tests.duplicate()
	await _click_button(desk.canvas.find_child("shutter_3",true,false))
	_check(desk.data().tests==tests_before and not desk.shutter.wound,"failure prevents playback / record")
	_session._save=original_store
	await _click_button(desk.canvas.find_child("shutter_3",true,false))
	_check(desk.shutter.wound and "wound/slow" in desk.data().tests,"click records and animates")
	await _capture("shutter")
	await _click_button(desk.canvas.find_child("guide",true,false));var guide:=root.get_node("CameraGuide") as CameraGuideView
	for i in 3:await _capture("guide_"+str(i));await _click_button(guide.canvas.find_child("next",true,false))
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	await _click_button(desk.canvas.find_child("notes",true,false));await choose(desk.choices.lens,2)
	_check(not desk.seal_button.disabled,"partial notes can seal");await _capture("notes")
	await _click_button(desk.seal_button)
	_check(root.get_node_or_null("CameraDeskOverlay")==null and not screen.get_node("%Drawer").visible,"seal returns counter")
	screen._route_from_customer(&"trade");await _click("商量价钱")
	var claims:=_main.find_child("CameraClaimForm",true,false) as WatchClaimForm
	_check(claims!=null,"camera claims form");if claims==null:quit(1);return
	_check(claims.payload()=={"lens":"haze"},"default from partial notes")
	await _capture("claims");await _click_button(claims.submit_button);await _capture("reply")
	_check(_session._day.state.visits[0].item.goods==fixed,"actions preserve value")
	screen._close_drawer();PrecisionPreview.apply(_session,2,"camera");CameraPreview.apply(_session,"guide")
	_session.restored.emit();_session.changed.emit();await _frames();screen._close_drawer();screen._close_menu();screen._counter_view.dismiss_contexts()
	_check(screen.facilities.enter("",false),"enter cabinets");await _frames()
	await _click_button(screen.facilities.room.hotspots["knowledge/luxury_textile"])
	guide=root.get_node_or_null("CameraGuide") as CameraGuideView;_check(guide!=null,"camera cabinet opens guide");if guide==null:quit(1);return
	var prep:=PreparationService.count(_session._day.state);await _click_button(guide.study)
	_check(guide.study.disabled and PreparationService.count(_session._day.state)==prep+1,"study once");await _capture("learned")
	print("CAMERA UI: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)

func _capture(label:String) -> void:
	await _frames();await RenderingServer.frame_post_draw
	var folder:="res://docs/qa/camera-v43/";DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png")==OK,"capture "+label)
