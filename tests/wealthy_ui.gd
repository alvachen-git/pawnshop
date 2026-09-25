extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("WEALTHY UI TIMEOUT"); quit(1))
	_capture_prefix = "wealthy_1600" if "wide" in OS.get_cmdline_user_args() else "wealthy_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/wealthy_manifest.json"
	_main.get_node("Bootstrap").save_path = "user://tests/wealthy-ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 31 and _session.definition.id == "wealthy_ten","default title starts wealthy unified v31")
	await install("ready")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var v := _session._counter.customers.active(_session._day.state)
	_check(v != null and WealthyCustomers.is_customer(v.customer_id),"real wealthy visitor fixture")
	_check(CounterVisualCatalog.is_wealthy_portrait(screen._counter_view._portrait.texture),"wealthy visitor uses dedicated art")
	_check(CounterVisualCatalog.front((_session._counter.catalog.get_definition("items",v.item.definition_id) as ItemDefinition).visual_asset_id) != null,"luxury prop has art")
	await _capture("counter")
	await _click_button(screen._counter_view.get_hotspot(&"item"))
	await _click("鉴定")
	var entrance: Dictionary = _session.counter_model().appraisal
	_check(entrance.body.length() < 100 and not entrance.body.contains("估价旧簿"),"short appraisal entrance keeps action visible")
	await _capture("entrance")
	await _click(entrance.buttons[0].label)
	var desk := root.get_node_or_null("LuxuryAppraisalOverlay") as LuxuryAppraisalView
	_check(desk != null,"actual counter clicks open luxury desk")
	if desk == null: quit(1); return
	var before := _session._day.state.game_minutes
	for index in 2:
		await _click_button(desk.tabs[index])
		await click_desk(desk,"luxury_check_" + str(index))
		await click_desk(desk,"luxury_match_%d_%s" % [index,LuxuryAppraisalService.expected_matches(v.item)[index]])
		_check(not desk.body.text.contains("估价旧簿") and not desk.body.text.contains("样例分栏") and desk.body.text.length() < 240,"one observation and relevant reference only")
		await _capture("detail_" + str(index))
		_check(desk.body.size.y <= desk.body.get_parent().size.y + 1,"observation and reference fit together without scrolling")
	await _click_button(desk.tabs[2])
	var book := LuxuryAppraisalService.info(_session._day.state,v.item)
	await click_desk(desk,"luxury_identity_" + String(book.identity[v.item.selected_variant_id]))
	await click_desk(desk,"luxury_condition_" + String(book.condition[v.item.selected_variant_id]))
	_check(_session._day.state.game_minutes == before+20,"UI two checks cost twenty minutes")
	await _capture("evidence")
	await click_desk(desk,"luxury_commit_")
	_check(LuxuryAppraisalService.record(_session._day.state,v.item.instance_id).committed,"UI commits both judgments")
	await _capture("committed")
	desk.queue_free(); await _frames()
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"trade")
	await _frames()
	var model := _session.counter_model()
	_check(model.trade.pawn_asking == v.trade.asking_price,"pawn UI does not halve luxury quote twice")
	_check(model.trade.buttons.any(func(b: Dictionary) -> bool: return b.command == "luxury_pressure" and b.enabled),"evidence negotiation available")
	_check(model.visual.clues.size() == 2,"counter remembers both observed clues")
	var trade := _find_trade_panel(_main)
	await _click_button(trade._bargain_toggle)
	await _click("拿鉴定记录谈价 · 5分钟 / 1轮")
	_check(WealthyCustomers.trade(_session._day.state,v).evidence_used and _session._day.state.game_minutes == before+25,"UI evidence reprices in one five-minute round")
	if trade._bargain_popup.visible: await _click_button(trade._bargain_popup.close_button)
	await _capture("trade")
	var cash := _session._day.state.cash
	trade._pawn_price.value = v.trade.reserve_price
	await _frames(); await _click_button(trade._pawn_submit)
	_check(_session._day.state.cash == cash-v.trade.reserve_price and _session._day.state.pawn_tickets.size() == 1,"actual UI pawn pays principal and creates ticket")
	await install("advertisement-closed")
	_check(SocialReadModels.notice(_session._day.state).contains("口碑") or SocialReadModels.notice(_session._day.state).contains("好名声"),"closing ad feedback describes its effect")
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"day")
	await _frames(); await _capture("advertisement")
	print("WEALTHY UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func click_desk(desk: LuxuryAppraisalView, id: String) -> void:
	var button := desk._root.find_child(id,true,false) as Button
	if button.get_parent() == desk.actions: (desk.actions.get_parent() as ScrollContainer).ensure_control_visible(button)
	await _frames()
	await _click_button(button)

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/wealthy/"+stage+".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data,_session.definition,31,_session._counter.catalog,true)
	_check(state != null,"verified UI fixture " + stage + " " + codec.error_message)
	if state == null: return
	_session._day.state = state; _session.message = ""
	_session.restored.emit(); _session.changed.emit()
	await _frames(); await create_timer(.3).timeout

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/wealthy-v31/"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture " + label)
