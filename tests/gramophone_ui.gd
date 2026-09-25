extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func()->void:push_error("GRAMOPHONE UI TIMEOUT");quit(1))
	_capture_prefix="gramophone_1600" if "wide" in OS.get_cmdline_user_args() else "gramophone_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720);root.content_scale_size=root.size
	_main=load("res://scenes/start.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/gramophone-ui/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0]);_check(_session.content_version==44,"v44 default")
	PrecisionPreview.apply(_session,2,"gramophone","sound","intact",false,"antique");GramophonePreview.apply(_session,"wavering")
	_session.restored.emit();_session.changed.emit();await _frames()
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	var v:CustomerVisit=_session._day.state.visits[0];var fixed:=v.item.goods.duplicate(true)
	_check(CounterVisualCatalog.front("luxury.gramophone").resource_path.ends_with("counter_painted.png"),"inventory art")
	await _capture("counter")
	await _click_button(screen._counter_view.get_hotspot(&"item"));await _click("鉴定")
	_check(_session.counter_model().appraisal.buttons.size()==2,"exterior and apparatus only")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk:=root.get_node_or_null("GramophoneDeskOverlay") as GramophoneDeskView
	_check(desk!=null,"gramophone routed");if desk==null:quit(1);return
	await _capture("identity")
	await _click_button(desk.canvas.find_child("zoom",true,false));await _click_button(desk.canvas.find_child("zoom",true,false))
	await _click_button(desk.canvas.find_child("group_soundbox",true,false));await _capture("soundbox")
	await _click_button(desk.canvas.find_child("group_playback",true,false))
	await _click_button(desk.canvas.find_child("play_0",true,false))
	await _click_button(desk.canvas.find_child("disc_reference",true,false))
	var original_store:=_session._save;var fail:=FailingStore.new();fail.origin=_session._day.state.ghost_origin.duplicate(true);_session._save=fail
	var before:Array=desk.data().tests.duplicate()
	await _click_button(desk.canvas.find_child("play_4",true,false))
	_check(not desk.playback.playing and desk.data().tests==before,"failed save prevents playback")
	_session._save=original_store
	await _click_button(desk.canvas.find_child("play_4",true,false))
	_check(desk.playback.playing and "wound/reference/nominal" in desk.data().tests,"immediate record plus real playback")
	var actual_tests:Array=desk.data().tests.duplicate()
	await _click_button(desk.canvas.find_child("normal_sample",true,false))
	_check(desk.normal_player.playing and not desk.playback.playing,"normal reference is separate and stops real audio")
	_check(desk.data().tests==actual_tests,"normal teaching sample does not create evidence")
	await _click_button(desk.canvas.find_child("play_4",true,false))
	_check(desk.playback.playing and not desk.normal_player.playing,"real specimen stops normal sample")
	await _capture("playback")
	await _click_button(desk.canvas.find_child("play_5",true,false));_check(not desk.playback.playing,"stop")
	await _click_button(desk.canvas.find_child("group_identity",true,false));await _click_button(desk.canvas.find_child("group_playback",true,false))
	_check(desk.data().record=="reference" and desk.data().wound,"setup preserved")
	await _click_button(desk.canvas.find_child("guide",true,false));var guide:=root.get_node("GramophoneGuide") as GramophoneGuideView
	for i in 3:
		await _capture("guide_"+str(i))
		if i>0:
			await _click_button(guide.canvas.find_child("sample_1",true,false));_check(guide.sample_player.playing,"guide sample plays")
		await _click_button(guide.canvas.find_child("next",true,false))
	await _click_button(guide.canvas.find_child("close_guide",true,false))
	await _click_button(desk.canvas.find_child("notes",true,false));await choose(desk.choices.motor,2)
	_check(not desk.seal_button.disabled,"partial notes seal");await _capture("notes");await _click_button(desk.seal_button)
	_check(root.get_node_or_null("GramophoneDeskOverlay")==null and not screen.get_node("%Drawer").visible,"seal returns counter")
	screen._route_from_customer(&"trade");await _click("商量价钱")
	var claims:=_main.find_child("GramophoneClaimForm",true,false) as WatchClaimForm
	_check(claims!=null,"claims form");if claims==null:quit(1);return
	_check(claims.payload()=={"motor":"wavering"},"defaults from note");await _capture("claims");await _click_button(claims.submit_button);await _capture("reply")
	_check(_session._day.state.visits[0].item.goods==fixed,"fixed value preserved")
	screen._close_drawer();PrecisionPreview.apply(_session,2,"gramophone");GramophonePreview.apply(_session,"guide")
	_session.restored.emit();_session.changed.emit();await _frames();screen._close_drawer();screen._close_menu();screen._counter_view.dismiss_contexts()
	_check(screen.facilities.enter("",false),"cabinet entrance");await _frames()
	await _click_button(screen.facilities.room.hotspots["knowledge/luxury_watch"])
	var watch:=root.get_node("WatchGuide") as WatchGuideView
	await _click_button(watch.canvas.find_child("gramophone_guide",true,false))
	guide=root.get_node_or_null("GramophoneGuide") as GramophoneGuideView;_check(guide!=null,"second cabinet guide")
	var prep:=PreparationService.count(_session._day.state);await _click_button(guide.study)
	_check(guide.study.disabled and PreparationService.count(_session._day.state)==prep+1,"shared learning once");await _capture("learned")
	print("GRAMOPHONE UI: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)

func _capture(label:String) -> void:
	await _frames();await RenderingServer.frame_post_draw
	var folder:="res://docs/qa/gramophone-v44/";DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png")==OK,"capture "+label)
