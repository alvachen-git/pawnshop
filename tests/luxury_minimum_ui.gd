extends "res://tests/gramophone_ui.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func()->void:push_error("MINIMUM UI TIMEOUT");quit(1))
	_capture_prefix="minimum_1600" if "wide" in OS.get_cmdline_user_args() else "minimum_1280"
	root.size=Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size=root.size
	_main=load("res://scenes/start.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/minimum-ui/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0])
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	for kind in ["camera","gramophone"]:
		PrecisionPreview.apply(_session,2,kind,"sound","intact",false,"antique")
		var v:CustomerVisit=_session._day.state.visits[0]
		var n:=CameraNegotiation.data(_session._day.state,v) if kind=="camera" else GramophoneNegotiation.data(_session._day.state,v)
		n.personality="easy"
		for part in n.rolls:n.rolls[part]=0
		_check(_session.fan_command("luxury_begin",v.item.instance_id,"2").ok,"apparatus")
		if kind=="gramophone":
			_check(_session.fan_command("luxury_gramophone",v.item.instance_id,'{"op":"listen"}').ok,"listening")
		else:
			_session.fan_command("luxury_camera",v.item.instance_id,'{"op":"group","group":"lens"}')
			_session.fan_command("luxury_camera",v.item.instance_id,'{"op":"shutter"}')
		var claims:Dictionary={"identity":"imitation","lens":"scratched","mechanism":"stuck"} if kind=="camera" else {"identity":"imitation","sound":"muffled","motor":"stopping"}
		var result:=_session.counter_command(kind+"_claim",v.visit_id,JSON.stringify(claims))
		_check(result.ok and result.message.contains("最低"),"minimum reached")
		_session.restored.emit();_session.changed.emit();await _frames()
		screen._route_from_customer(&"trade");await _frames()
		var panel := _main.find_child("TradePanel",true,false) as TradePanel
		_check(panel._feedback.text.contains("最低"),"visible trade feedback carries floor reply")
		panel._content_scroll.scroll_vertical = int(panel._content_scroll.get_v_scroll_bar().max_value)
		await _capture(kind+"_floor")
		_check(v.trade.asking_price==(120 if kind=="camera" else 100),"shown floor")
		screen._close_drawer()
	print("MINIMUM UI: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)
