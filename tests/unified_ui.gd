extends "res://tests/fan_condition_ui.gd"

func install(stage: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/unified/" + stage + ".json"))
	var codec := SaveCodec.new()
	var restored := codec.decode(payload,_session.definition,30,_session._counter.catalog,true)
	_check(restored != null, "combined UI save " + codec.error_message)
	if restored == null: return
	_session._day.state = restored; _session.message = ""
	_session.restored.emit(); _session.changed.emit()

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("UNIFIED UI TIMEOUT"); quit(1))
	_capture_prefix = "unified_1600" if "wide" in OS.get_cmdline_user_args() else "unified_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/unified_ui/auto.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	var store := DraftUIStore.new(); store.origin = _session._day.state.ghost_origin; _session._save = store
	await _frames(); await _capture("00_title")
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.definition.id == "unified_ten" and _session.content_version == 30, "default title starts complete game")
	_check(_session._day.state.current_night_index == 1 and _session._day.state.cash == 300 and not _session._day.state.pending_event_id.is_empty(), "new game starts at beginning")
	await _capture("01_opening")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	install("introduction"); await receipts(); await create_timer(.5).timeout
	var view := screen._counter_view
	_check(view._portrait.visible and view._portrait.texture.resource_path == CounterVisualCatalog.SUN_PORTRAIT, "Sun portrait in default game")
	_check(not view._item_hotspot.visible and not screen.facilities.available(), "itemless introduction cannot enter facilities")
	await _capture("02_military_arrival")
	await _click_button(view._customer_hotspot); await _click_button(view._dialogue_action)
	for step in 3:
		await _click(MilitaryIntroduction.CHOICES[step])
		_check(_session._day.state.social.intro_step == step + 1, "military dialogue click " + str(step))
	await create_timer(.35).timeout
	await _click_button(view.get_hotspot(&"social"))
	var book := screen._social_panel
	_check(book.visible and book._roster.get_child_count() == 1, "physical book opens discovered faction")
	await _capture("03_procurement")
	await _click("接下采购单")
	_check(not _session._day.state.social.contract.is_empty(), "mouse accepts procurement")
	screen._close_drawer(); await _frames()
	await _click_button(screen.facilities.entry); await create_timer(.3).timeout
	var room := screen.facilities.room
	_check(screen.facilities.in_room, "same default game enters facilities")
	await _click_button(room.hotspots["knowledge/gu_yansheng"])
	await _click("学习顾砚生知识 · 准备1次")
	_check(ShopKnowledgeService.mastered(_session._day.state,"gu_yansheng"), "same game learns cabinet knowledge")
	await _capture("04_knowledge")
	screen.facilities.leave(false)
	install("fan-before"); await receipts(); screen._close_drawer(); await _frames()
	screen._flow.show_panel(&"appraisal"); await _frames()
	var visit := _session._counter.customers.active(_session._day.state)
	await _click("检查破损 · 5分钟")
	_check(FanConditionService.checked(visit.item), "fan condition click in combined game")
	await _click("送上鉴物台 · 辨认真假")
	var desk := root.get_node_or_null("FanAppraisalOverlay") as FanAppraisalView
	_check(desk != null, "fan desk reachable from normal default game")
	if desk == null: quit(1); return
	await _frames(); await _capture("05_desk")
	for points in [[Vector2(.72,.32),Vector2(.38,.245)], [Vector2(.74,.69),Vector2(.80,.355)]]:
		await desk_select(desk.book, points[0]); await desk_select(desk.fan, points[1]); await _click_button(desk.note_buttons.same)
	await _click_button(desk.stamp); await _click_button(desk.choice_buttons.sound); await _click_button(desk.confirm_button)
	_check(not FanAppraisalService.record(_session._day.state,visit.item.instance_id).is_empty(), "mouse commits appraisal")
	await _click_button(desk.close_button)
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(_session._day.state,30),_session.definition,30,_session._counter.catalog,true)
	_check(restored != null and restored.social.introduced and ShopKnowledgeService.mastered(restored,"gu_yansheng"), "UI changes save together")
	print("UNIFIED UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)
