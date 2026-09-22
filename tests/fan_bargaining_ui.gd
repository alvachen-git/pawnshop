extends "res://tests/shop_appraisal_ui.gd"

func install(stage: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/fan-bargaining/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(payload,_session.definition,28,_session._counter.catalog,true)
	_check(state != null,"v28 UI fixture " + codec.error_message)
	if state == null: return
	_session._day.state=state; _session.message=""
	_session.restored.emit(); _session.changed.emit()

func command_button(panel: TradePanel, command: String) -> Button:
	for child in panel._buttons.get_children():
		if child is Button and child.get_meta("trade_command", "") == command: return child
	return null

func visible_copy(node: Node) -> String:
	var result := ""
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is RichTextLabel): result += str(node.text)
	for child in node.get_children(): result += visible_copy(child)
	return result

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("FAN BARGAINING UI TIMEOUT"); quit(1))
	_capture_prefix="fan_bargaining_1600" if "wide" in OS.get_cmdline_user_args() else "fan_bargaining_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size=root.size
	_main=load("res://scenes/start_v28.tscn").instantiate()
	_main.get_node("Bootstrap").save_path="user://tests/bargaining_ui/auto.json"
	root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	var store:=DraftUIStore.new(); store.origin=_session._day.state.ghost_origin; _session._save=store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version==28 and _session.definition.id=="fan_bargaining_ten","unified v28 new game")
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	for kind in ["informed","ordinary","urgent"]:
		await receipts(); install(kind + "-ready"); await _frames()
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"trade"); await _frames()
		var panel:=_find_trade_panel(_main)
		_check(panel._body.visible and panel._body.text.contains("自己的判断：顾砚生真迹") and panel._body.text.contains("对客说法"),"private and public distinct")
		await _click_button(panel._bargain_toggle)
		var button:=command_button(panel,"fan_pressure")
		_check(button != null and not button.disabled,"pressure available after appraisal")
		_check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(panel._bargain_popup.paper.get_global_rect()),"dialog fits viewport")
		await _capture(kind + "_before")
		var visit:=CustomerManager.new().active(_session._day.state)
		var start:=_session._day.state.game_minutes
		if kind=="ordinary":
			var before:=_session.read_state()
			store.fail=true; await _click_button(button)
			_check(_session.read_state()==before,"mouse pressure save failure rolls back")
			store.fail=false
			if not panel._bargain_popup.visible: await _click_button(panel._bargain_toggle)
			button=command_button(panel,"fan_pressure")
		await _click_button(button)
		_check(_session._day.state.game_minutes==start+5,"real mouse pressure costs five minutes")
		_check(command_button(panel,"fan_pressure").disabled and command_button(panel,"belittle").disabled,"shared opportunity exhausted")
		if panel._bargain_popup.visible: await _click_button(panel._bargain_popup.close_button)
		_check(panel._body.text.contains(FanBargainingService.WORDS),"public words persisted independently")
		_check(not visible_copy(root).contains("商誉"),"no hidden reputation visible")
		_check(panel._content_scroll.get_global_rect().encloses(panel._ask_value.get_global_rect()),"current asking fully visible without scrolling")
		await _capture(kind + "_response")
		var current:=CustomerManager.new().active(_session._day.state)
		panel._price.value=FanBargainingService.asking(_session._day.state,current)
		await _click_button(panel._submit)
		_check(current.item.ownership_state=="owned","real mouse purchase")
		_check(not visible_copy(root).contains("商誉"),"receipt does not leak reputation")
		await _capture(kind + "_receipt")
	await receipts(); install("ordinary"); await _frames()
	var visit:=CustomerManager.new().active(_session._day.state)
	var view:=FanAppraisalView.open(screen,_session,visit.item.instance_id)
	await _frames()
	for points in [[Vector2(.72,.32),Vector2(.38,.245)],[Vector2(.74,.69),Vector2(.80,.355)]]:
		await desk_select(view.book,points[0]); await desk_select(view.fan,points[1]); await _click_button(view.note_buttons.same)
	await _click_button(view.stamp)
	_check(view.choice_buttons.sound.text.contains("顾砚生真迹") and view.choice_buttons.mended.text.contains("临摹画") and view.choice_buttons.flawed.text.contains("假画"),"plain judgement labels")
	_check(not visible_copy(view).contains("后添名款"),"old term and explanation absent")
	await _click_button(view.choice_buttons.flawed); await _capture("judgement")
	await _click_button(view.confirm_button)
	_check(visit.item.goods.fan_claim=="flawed","private fake choice works")
	print("FAN BARGAINING UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures==0 else 1)
