extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("CHEN UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_reckoning_manifest.json"; aqi_version = 29; aqi_fixture_dir = "res://.godot/qa/v29/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.always_on_top = true
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v29/chen-ui-unused.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v29/chen-ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view
	var dialogue := screen.first_debt_conversation
	for route in ["reject", "buy", "failed", "later"]:
		await restore_stage("chen-uncontacted")
		screen._close_drawer(); await _frames()
		var visit := _session._counter.customers.active(_session._day.state)
		if "queued" in OS.get_cmdline_user_args():
			while _session._day.state.game_minutes < 80: _check(_session.execute("short_task").ok, "real queued arrival")
			_check(_session._day.state.visits.any(func(v: CustomerVisit) -> bool: return v.status == "waiting"), "next guest already waiting")
		_check(not view._first_debt_relic.visible and not dialogue.visible, "one item and no story before trade " + route)
		await shot(route + "-ordinary")
		# Read a document, then return to ordinary dialogue: the paper must not leak.
		_session.observe_document("fd_ticket")
		await _click_button(view._customer_hotspot); await _click("对话")
		_check(not "瑞字四十七" in screen.get_node("%DialoguePanel")._body.text, "no old ticket leak")
		_check(not "凤尾" in screen.get_node("%DialoguePanel")._body.text, "no premature recognition")
		await shot(route + "-ordinary-dialogue")
		await key(KEY_ESCAPE)
		if route == "buy": _check(_session.counter_command("offer", visit.visit_id, "", visit.trade.asking_price).ok, "buy succeeds")
		elif route in ["reject", "later"]: _check(_session.counter_command("reject", visit.visit_id).ok, "reject succeeds")
		else:
			for i in 3:
				if _session._counter.customers.active(_session._day.state) != visit: break
				_check(_session.counter_command("offer", visit.visit_id, "", 1).ok, "low quote")
		await _frames(); await create_timer(0.4).timeout
		if screen._receipt.visible:
			_check(not dialogue.visible, "receipt comes before case")
			await _click("收好凭据")
			await _frames()
		_check(dialogue.visible, "automatic post-trade scene " + route)
		_check(not view._first_debt_relic.visible, "no bracelet sprite during story")
		_check("当铺柜子里的凤镯" in dialogue._pages[0], "cabinet recognition copy")
		_check(_session.counter_model().visual.customer_id == "fd_chen", "Chen stays after trade without another guest appearing")
		_check(not _session.bell_model().enabled, "cannot ring away hidden next guest")
		await shot(route + "-transition")
		var before := _session.read_state()
		while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1:
			await _click_button(dialogue._next)
		_check(_session.read_state() == before, "reading doesn't spend time")
		_check(dialogue._choices.get_child_count() == 2, "two recognition choices")
		for b in dialogue._choices.get_children(): _check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(b.get_global_rect()), "choice on-screen")
		await shot(route + "-choices")
		await key(KEY_ESCAPE)
		_check(not dialogue.visible and root.gui_get_focus_owner() == view._customer_hotspot, "Esc to Chen")
		await key(KEY_ENTER); await _click("说说话")
		while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
		await _click_button(dialogue._choices.get_child(1 if route == "later" else 0))
		_check(FirstDebt.flag(_session._day.state, "fd_chen_requested") == (route != "later"), "chosen invitation state saved")
		_check(dialogue.visible and dialogue._result, "response shown")
		await shot(route + "-response")
		while dialogue.visible and dialogue._next.visible: await _click_button(dialogue._next)
		_check(not dialogue.visible, "response closes")
		_check(view._active_id != "first_debt/12/chen", "Chen leaves immediately without bell or time advance")
		_check(_session.counter_model().get("case_dialogue", {}).is_empty(), "no completed recognition lingering")
		_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "focus returns to visible control")
		await shot(route + "-departed")
		if _session._counter.customers.active(_session._day.state) == null:
			_check(_session.bell_command("wait").ok, "ordinary business resumes")
		else: _check(true, "cross-time guest retained")
		await _frames()
		_check(not dialogue.visible and not view._first_debt_relic.visible, "no story left over next guest")
		if "queued" in OS.get_cmdline_user_args():
			var next := _session._counter.customers.active(_session._day.state)
			_check(next != null and next.customer_id != "fd_chen", "next ordinary guest resumes")
			_check(_session.counter_command("reject", next.visit_id).ok, "next guest departs")
			await _frames()
			_check(not dialogue.visible and not _session.counter_model().get("case_dialogue", {}).get("auto_open", false), "Chen does not return after next guest")
			await shot(route + "-after-next-guest")
	# Existing later meetings use the same staged dialogue, with readable choices.
	for stage in ["before-fd_family", "before-fd_settle", "pay-before-fd_compensation"]:
		await restore_stage(stage)
		screen._close_drawer(); await _frames()
		await _click_button(view._customer_hotspot); await _click("说说话")
		while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
		_check(dialogue.visible, "later meeting RPG layout")
		for b in dialogue._choices.get_children(): _check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(b.get_global_rect()), "later choice on-screen")
		await shot(stage)
		if stage == "before-fd_family":
			_check("原当票" in _session.counter_model().visual.introduction, "delivery introduction names ticket")
			await _click_button(dialogue._choices.get_child(0))
			_check(dialogue.visible and dialogue._result, "delivery reply shown before departure")
			while dialogue.visible and dialogue._next.visible: await _click_button(dialogue._next)
			_check(not dialogue.visible and not FirstDebt.chen_waiting(_session._day.state), "delivery reply automatically ends visit")
			_check(not view._active_id.ends_with("/chen"), "delivery portrait leaves immediately")
			await shot("delivery-departed")
		else:
			await key(KEY_ESCAPE)
	await restore_stage("seller")
	await _click_button(view._customer_hotspot); await _click("对话")
	await _click("展开旧包纸")
	_check(screen.old_shop.visible and screen.old_shop.selected == "fd_receipt", "seller paper opens its own album record")
	await shot("seller-paper")
	await key(KEY_ESCAPE); await key(KEY_ESCAPE)
	_check(not screen.old_shop.visible, "paper can return")
	print("CHEN TRADE UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	print("CAPTURE ", stage)
	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png("res://docs/qa/chen-trade-dialogue/%s%d-%s.png" % ["queued-" if "queued" in OS.get_cmdline_user_args() else "", root.size.x, stage]) == OK, "capture " + stage)
