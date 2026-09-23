extends "res://tests/watch_ui.gd"

class FailingStore extends GhostReplayStore:
	func save_state(_state: RunState, _run: RunDefinition, _version: int) -> bool:
		error_message = "测试写盘失败"; return false

func form() -> WatchClaimForm:
	return _main.find_child("WatchClaimForm",true,false) as WatchClaimForm

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("WATCH35 UI TIMEOUT"); quit(1))
	_capture_prefix = "watch35_1600" if "wide" in OS.get_cmdline_user_args() else "watch35_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").manifest_path = "res://data/watch_negotiation_manifest.json"; _main.get_node("Bootstrap").save_path = "user://tests/watch35-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 35,"default new game v35")
	PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,"fake-fault")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var v: CustomerVisit = _session._day.state.visits[0]
	await _click_button(screen._counter_view.get_hotspot(&"item")); await _click("鉴定")
	await _click(_session.counter_model().appraisal.buttons[1].label)
	var desk := root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
	_check(desk != null,"new watch desk")
	if desk == null: quit(1); return
	var original_store := _session._save; var failed_store := FailingStore.new(); failed_store.origin = _session._day.state.ghost_origin.duplicate(true)
	_session._save = failed_store
	await _click_button(desk.listen_button)
	_check(not desk.audio_player.playing and not desk.playing and desk.data().get("started",[]).is_empty(),"failed save prevents sound and record")
	_check(desk.helper.text.contains("失败"),"failed save cause visible")
	_session._save = original_store
	await _click_button(desk.listen_button)
	_check(desk.audio_player.playing and "arrival/flat" in desk.data().started,"click records before sound finishes")
	await create_timer(.2).timeout; await _click_button(desk.listen_button)
	_check(not desk.playing and desk.data().started == ["arrival/flat"],"early stop retains unwound observation")
	await _capture("early_stop")
	await _click_button(desk.listen_button)
	var after_click := _session.read_state()
	await create_timer(8.6).timeout; await _frames()
	_check(not desk.playing and not desk.audio_player.playing and _session.read_state() == after_click,"full finish neither duplicates evidence nor writes another action")
	await _click_button(desk.note_button); await choose(desk.running_choice,0)
	_check(not desk.seal_button.disabled,"partial note can seal")
	await _click_button(desk.seal_button)
	_check(root.get_node_or_null("WatchDeskOverlay") == null and not screen.get_node("%Drawer").visible,"successful partial seal returns counter")
	await _capture("sealed_counter")
	screen._route_from_customer(&"trade"); await _click("商量价钱")
	var claims := form(); _check(claims != null,"claim form in negotiation")
	if claims == null: quit(1); return
	_check(claims.payload() == {"running":"stable"},"defaults quote private notes; unsure items unselected")
	_check(claims.checks.exterior.disabled and not claims.checks.identity.disabled,"exterior gated; identity can be asserted without inspection")
	await _capture("claims")
	await choose(claims.selections.running,3)
	_check(claims.payload() == {"running":"stopping"},"editable spoken story")
	_check(WatchAppraisal.row(_session._day.state,v.item.instance_id).running == "stable","changing speech never edits sealed notes")
	_check(claims.submit_button.get_global_rect().end.y <= root.size.y,"submit within viewport")
	await _click_button(claims.submit_button)
	v = _session._day.state.visits[0]
	var d := WatchNegotiation.data(_session._day.state,v)
	_check(d.belief.running == "stopping" and v.item.goods.watch_value.actual == 500,"false fault believed without actual change")
	_check(v.trade.asking_price == 193,"believed condition price instead of fixed 15 percent")
	await _capture("believed_reply")
	await _click("商量价钱"); claims = form()
	_check(claims.checks.running.disabled and claims.submit_button.disabled,"used running is not repeatable")
	await choose(claims.selections.identity,2)
	_check(claims.payload() == {"identity":"imitation"},"next row edits independently")
	await _capture("used_claim")
	await _click("返回交易 · Esc")
	for scenario in ["firm","partial","exposed"]:
		screen._close_drawer(); PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,scenario)
		_session.restored.emit(); _session.changed.emit(); await _frames()
		v = _session._day.state.visits[0]
		if scenario != "exposed":
			_check(_session.fan_command("luxury_begin",v.item.instance_id,"2").ok,"scenario apparatus")
			_check(_session.fan_command("luxury_watch",v.item.instance_id,'{"op":"listen_start","clip":"arrival/flat"}').ok,"scenario single click")
		screen._route_from_customer(&"trade"); await _click("商量价钱"); claims = form()
		await choose(claims.selections.identity if scenario == "exposed" else claims.selections.running,2)
		await _click_button(claims.submit_button)
		_check(v.trade.asking_price == {"firm":385,"partial":347,"exposed":385}[scenario],"personality or disbelief "+scenario)
		_check(_session.counter_model().trade.reactions.size() == 1,"independent preview has only its own reply")
		await _capture(scenario+"_reply")
	print("WATCH NEGOTIATION UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/watch-v35/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture "+label)
