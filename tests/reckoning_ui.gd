extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("FIRST DEBT UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_reckoning_manifest.json"; aqi_version = 29; aqi_fixture_dir = "res://.godot/qa/v29/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v29/ui-unused.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null and _session.content_version == 29, "production v29 default")
	_session._save.library.path = "res://.godot/qa/v29/ui-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen.get_node("CounterView") as CounterView
	await restore_stage("seller")
	view._customer_hotspot.grab_focus()
	await key(KEY_ENTER)
	_check(_find_button(_main, "对话") != null, "keyboard opens customer menu")
	await _click("对话")
	var original := _session.read_state()
	await _click("展开旧包纸")
	_check(_session.read_state().game_minutes == original.game_minutes, "free receipt observation")
	_check(FirstDebt.owned(_session._day.state, FirstDebt.PHOENIX) == null, "receipt without acquisition")
	await shot("receipt-without-purchase")
	await key(KEY_ESCAPE)
	for stage in ["seller", "chen", "before-fd_family", "before-fd_settle", "after-fd_settle"]:
		await restore_stage(stage)
		screen._close_drawer()
		await _frames()
		await shot(stage + "-counter")
		if stage in ["before-fd_family", "before-fd_settle"]:
			_check(view._portrait.visible, "Chen actually appears in counter")
			await _click_button(view._customer_hotspot)
			await _click("说说话")
			for b in _session.counter_model().dialogue.buttons:
				var option := _find_any_button(_main, b.label)
				_check(option != null and option.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(option.get_global_rect()), "choice fits window " + b.label)
			await shot(stage + "-dialogue")
			var before := _session.read_state()
			await key(KEY_ESCAPE)
			_check(before == _session.read_state(), "Esc is free")
			_check(root.gui_get_focus_owner() != null, "Esc restores an accessible focus")
	await restore_stage("before-fd_settle")
	await _click("账本")
	await _click("旧当铺")
	await _frames(); await shot("old-papers")
	var before := _session.read_state()
	await _click_button(screen.old_shop._content.get_node("DocumentHit"))
	await _frames(); await shot("paper-transcript")
	_check(before == _session.read_state(), "document review is read-only")
	_check(screen.old_shop.visible and screen.old_shop.mode == "detail", "document transcript displayed")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await restore_stage("before-fd_settle")
	await _click_button(view._customer_hotspot)
	await _click("说说话")
	var buttons: Array = _session.counter_model().dialogue.buttons
	for b in buttons: _check(not b.label.contains("清") and not b.label.ends_with("· 和"), "no outcome stamp before choice")
	# Play the visible decisions with actual viewport input after authentic replay.
	await restore_stage("before-fd_family")
	await _click_button(view._customer_hotspot); await _click("说说话")
	var minute: int = _session.read_state().game_minutes
	await _click("同她核对旧记 · 5分钟")
	_check(FirstDebt.flag(_session._day.state, "fd_family_read") and _session.read_state().game_minutes == minute + 5, "visible family verification")
	await shot("family-read-result")
	for route in ["return", "pay", "late25"]:
		await restore_stage(("pay-" if route == "pay" else "late25-" if route == "late25" else "") + "before-fd_settle")
		await _click_button(view._customer_hotspot); await _click("说说话")
		var cash: int = _session.read_state().cash
		await _click("交付300银元，立和解字据 · 5分钟" if route == "pay" else "将两只金镯交还陈家 · 5分钟")
		_check(FirstDebt.flag(_session._day.state, "fd_peace" if route == "pay" else "fd_clear"), "visible resolution " + route)
		_check(_session.read_state().cash == cash - (300 if route == "pay" else 0), "visible cash " + route)
		if route == "late25": _check(_session.read_state().current_night_index >= 25, "late authentic restored case")
		await shot("played-" + route)
	await restore_stage("summary18")
	await _frames(); await shot("summary18")
	_check(_session.can_execute("finish_trial") and _session.can_execute("continue_run"), "two continuation choices")
	print("FIRST DEBT UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := "res://docs/qa/first-debt-v29/%d-%s.png" % [root.size.x, stage]
	_check(root.get_texture().get_image().save_png(path) == OK, "screenshot " + stage)
