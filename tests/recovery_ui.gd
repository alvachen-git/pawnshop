extends "res://tests/dragon_ui.gd"

func recovery_manifest() -> String:
	return "res://data/first_debt_recovery_manifest.json"

func recovery_version() -> int:
	return 40

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("RECOVERY UI TIMEOUT"); quit(1))
	aqi_manifest = recovery_manifest(); aqi_version = recovery_version(); aqi_fixture_dir = "res://.godot/qa/v%d/" % aqi_version
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size; root.title = "第一账补救与和解 · v%d验收" % aqi_version; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate()
	if aqi_version == 41: _check(_main.get_node("Bootstrap").manifest_path == aqi_manifest, "release default manifest41")
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	_main.get_node("Bootstrap").save_path = aqi_fixture_dir + "ui-unused.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = aqi_fixture_dir + "ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == aqi_version, "requested content version")
	_session.definition._initial_cash = 2000
	_session._save.library.register_catalog(aqi_manifest, _session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view; var dialogue := screen.first_debt_conversation
	# Drive a real refusal, rather than opening a standalone dialogue mockup.
	await restore_stage("first-seller"); screen._close_drawer(); await _frames()
	var seller := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("reject", seller.visit_id).ok, "decline actual seller")
	await _frames(); await create_timer(1.0).timeout
	if screen._feedback.visible: screen._feedback.hide(); view.release_feedback()
	if screen._departure.visible: screen._departure.dismiss("")
	dialogue.refresh(); await _frames()
	var companion := view.companion
	_check(not dialogue.visible and not companion.dialogue.visible, "event never auto-opens dialogue")
	_check(companion.attention.is_visible_in_tree(), "Aqi has subtle exclamation marker")
	_check(not view._portrait.visible and not view.get_node("Room").has_customer, "empty counter remains empty")
	_check(_session.bell_model().enabled, "optional reminder does not block business")
	await shot("aqi-marker")
	var hover_before := _session.read_state()
	var motion := InputEventMouseMotion.new()
	motion.position = companion.hotspot.get_global_rect().get_center()
	root.warp_mouse(motion.position)
	root.push_input(motion, true); await create_timer(.30).timeout
	_check(float(companion._portrait_light.get_shader_parameter("hover_amount")) > .95, "pointer hover lights silhouette")
	_check(not companion.dialogue.visible and companion.attention.visible and hover_before == _session.read_state(), "hover never opens or consumes reminder")
	await shot("aqi-hover")
	motion = InputEventMouseMotion.new(); motion.position = Vector2(700, 500)
	root.warp_mouse(motion.position)
	root.push_input(motion, true); await create_timer(.30).timeout
	_check(float(companion._portrait_light.get_shader_parameter("hover_amount")) < .01, "pointer exit restores scene lighting")
	var before := _session.read_state()
	_session._save.library.fail_write = true
	await _click_button(companion.hotspot)
	_check(companion.attention.visible and companion.dialogue.visible, "failed save keeps marker and retry message")
	_check(before == _session.read_state(), "click failure rolls back discovery")
	_session._save.library.fail_write = false
	await _click("重试"); await _frames()
	_check(not companion.attention.visible and FirstDebt.flag(_session._day.state, "fd_phoenix_hint_seen"), "successful click consumes marker once")
	_check(companion.dialogue.visible and not dialogue.visible, "event lives in companion's own panel")
	_check(companion.dialogue._text.text.contains("应该挺值钱"), "authored Aqi impression retained")
	_check(before.game_minutes == _session._day.state.game_minutes and before.cash == _session._day.state.cash, "reminder free")
	await shot("aqi-hint")
	var read := _session.read_state()
	await _click("聊点别的")
	_check(companion.dialogue._choices.get_child_count() == 3, "return to everyday companion topics")
	await key(KEY_ESCAPE); await _frames()
	_check(not companion.dialogue.visible and not companion.attention.visible, "Esc closes without restoring marker")
	await _click_button(companion.hotspot)
	_check(companion.dialogue._text.text.contains("朝你笑"), "next click opens usual topics")
	_check(read == _session.read_state(), "reading and closing never duplicate history")
	await key(KEY_ESCAPE)
	var saved := _session._save.library.read_entry("auto/" + String(_session.definition.id))
	_check(not saved.is_empty() and _session._save.library.adopt(saved, _session), "read notification restores through full replay")
	await _frames()
	_check(not companion.attention.visible, "restore does not resurrect read marker")
	await shot("hint-dismissed")
	await restore_stage("phoenix-prep"); screen._flow.show_panel(&"day"); await _frames()
	await shot("phoenix-preparation")
	var used := PreparationService.count(_session._day.state)
	await _click("约卖镯人带凤镯来 · 准备1次")
	_check(PreparationService.count(_session._day.state) == used + 1, "real prep button consumes one")
	await key(KEY_ESCAPE)
	for spec in [["before-fd_truth", "", "把日期与出货记录说清楚", "truth"], ["before-fd_compensation", "-pay", "与她商量300银元赔偿", "offer"], ["before-fd_settle", "-pay", "交付300银元，立和解字据 · 5分钟", "pay"]]:
		aqi_fixture_dir = "res://.godot/qa/v%d" % aqi_version + spec[1] + "/"
		await restore_stage(spec[0]); screen._close_drawer(); await _frames()
		await _click_button(view._customer_hotspot); await _click("说说话")
		while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
		before = _session.read_state()
		await _click(spec[2]); await _frames()
		_check(dialogue._result, "result conversation " + spec[3])
		_check(dialogue._pages.size() >= 5, "expanded short paragraphs " + spec[3])
		var committed := _session.read_state()
		_check(committed.cash == before.cash - (300 if spec[3] == "pay" else 0), "only payment debits")
		_check(committed.game_minutes == before.game_minutes + (5 if spec[3] == "pay" else 0), "only payment takes time")
		while dialogue.visible and dialogue._result and dialogue._next.visible:
			_check(dialogue._text.get_content_height() <= dialogue._text.size.y + 1, "paragraph readable " + spec[3])
			_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(dialogue._next.get_global_rect()), "advance within viewport")
			await shot(spec[3] + "-%02d" % dialogue._page)
			await click_background(view.bell.get_global_rect().get_center())
			_check(committed == _session.read_state(), "no click through " + spec[3])
			await _click_button(dialogue._next)
		_check(committed == _session.read_state(), "reading no extra actions")
		if spec[3] == "pay":
			_check(not dialogue.visible and not view._active_id.ends_with("/chen"), "payment final page auto departure")
			_check(not FirstDebt.flag(_session._day.state, "fd_yin_echo_seen"), "hint no premature ledger knowledge")
			await shot("paid-departed")
		else: await key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() != null, "focus returns")
	print("RECOVERY UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func click_background(point: Vector2) -> void:
	for pressed in [true, false]:
		var input := InputEventMouseButton.new(); input.button_index = MOUSE_BUTTON_LEFT; input.pressed = pressed; input.position = point; root.push_input(input, true)
	await _frames()

func shot(stage: String) -> void:
	await create_timer(.12).timeout; RenderingServer.force_draw()
	var retained := stage in ["aqi-marker", "aqi-hover", "aqi-hint", "phoenix-preparation", "truth-02", "truth-04", "offer-04", "pay-04", "paid-departed"]
	var directory := ("res://docs/qa/first-debt-recovery-release/ui/" if aqi_version == 41 else "res://docs/qa/first-debt-recovery/ui/") if retained else "res://.godot/qa/v%d/ui-full/" % aqi_version
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
