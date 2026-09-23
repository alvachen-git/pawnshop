extends "res://tests/watch_ui.gd"

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("NAMED WEALTHY UI TIMEOUT"); quit(1))
	_capture_prefix = "named_1600" if "wide" in OS.get_cmdline_user_args() else "named_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720); root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").save_path = "user://tests/named-wealthy-ui/auto.json"; root.add_child(_main)
	_session = _main.get_node("Bootstrap").session; await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 37,"default new game v37")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	for short in ["embroidery","gold_watch","pearl_necklace","porcelain_vase","repeater"]:
		PrecisionPreview.apply(_session,2,short)
		_session.restored.emit(); _session.changed.emit(); await _frames()
		var v: CustomerVisit = _session._day.state.visits[0]
		await _click_button(screen._counter_view.get_hotspot(&"customer")); await _click("交易")
		var panel := screen.get_node("%TradePanel") as TradePanel
		_check(panel._customer_heading.is_visible_in_tree() and panel._customer_heading.text.begins_with(WealthyCustomers.NAMES[v.customer_id]),"fixed name inside trade panel")
		_check(panel._customer_heading.get_global_rect().end.x <= root.size.x and panel._customer_heading.get_global_rect().position.y >= 0,"name stays onscreen")
		_check(panel._pawn_submit.is_visible_in_tree() and panel._pawn_submit.get_global_rect().end.y < root.size.y,"transaction control still onscreen")
		await _capture(short)
		await _click_button(panel._bargain_toggle)
		_check(panel._bargain_popup.context.text.begins_with(WealthyCustomers.NAMES[v.customer_id]),"bargaining shows same name")
		panel._bargain_popup.hide(); screen._close_drawer()
	PrecisionPreview.apply(_session,2,"gold_watch"); PrecisionPreview.watch_case(_session,"fake-fault")
	var v: CustomerVisit = _session._day.state.visits[0]; var id := v.item.instance_id
	_check(_session.fan_command("luxury_begin",id,"2").ok,"start apparatus")
	_check(_session.fan_command("luxury_watch",id,JSON.stringify({"op":"listen_start","clip":WatchAppraisal.key(WatchAppraisal.row(_session._day.state,id))})).ok,"listen click")
	_check(_session.fan_command("luxury_exterior",id).ok,"exterior")
	_check(_session.counter_command("watch_claim",v.visit_id,'{"identity":"imitation","running":"stopping","exterior":"observed"}').ok,"combined claims")
	_session.restored.emit(); _session.changed.emit(); await _frames()
	await _click_button(screen._counter_view.get_hotspot(&"customer")); await _click("交易")
	_check(v.trade.asking_price == 39 and v.item.goods.watch_value.actual == 500,"39 asked, actual stays 500")
	await _capture("39_price")
	print("NAMED WEALTHY UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var folder := "res://docs/qa/named-wealthy/"; DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+_capture_prefix+"_"+label+".png") == OK,"capture "+label)
