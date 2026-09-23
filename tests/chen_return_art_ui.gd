extends "res://tests/dragon_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("CHEN RETURN TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_dragon_search_manifest.json"; aqi_version = 31; aqi_fixture_dir = "res://.godot/qa/chen-invitation/"
	if "unified" in OS.get_cmdline_user_args():
		aqi_manifest = "res://data/first_debt_unified_manifest.json"; aqi_version = 39; aqi_fixture_dir = "res://.godot/qa/v39/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size; root.title = "陈小满归还收尾与立绘验收"; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").save_path = "res://.godot/qa/chen-invitation/return-unused.json"
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/chen-invitation/return-ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	_session.definition._initial_cash = 2000
	_session._save.library.register_catalog(aqi_manifest, _session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view; var dialogue := screen.first_debt_conversation
	await restore_stage("before-fd_settle" if aqi_version == 39 else "return-meeting"); screen._close_drawer(); await _frames()
	var before := _session.read_state()
	_check(view._portrait.texture.resource_path == CounterVisualCatalog.CHEN_PORTRAIT, "new Chen portrait")
	_check(view._portrait.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "transparent portrait")
	var old_art := load("res://assets/first_debt/chen_xiaoman.png") as Texture2D
	view._portrait.texture = old_art; view._portrait.material = null; view._bounds(view._portrait, .315, .027, .68, .592)
	await shot("before")
	_session.changed.emit(); await _frames(); await shot("counter")
	_check(absf(view._portrait.global_position.y + view._portrait.size.y * .95 - root.size.y * 445.0 / 941.0) < 2, "waist occlusion aligned to rear lip")
	_check(is_equal_approx(view._portrait.material.get_shader_parameter("source_bottom"), .95), "hands remain behind counter")
	_check(view._portrait.size.y <= root.size.y * .415, "petite uniform scale")
	_check(before == _session.read_state(), "visuals do not change state")
	await _click_button(view._customer_hotspot); await _click("说说话")
	while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
	# A failed write keeps the pair and all settlement state, then retry through UI.
	_session._save.library.fail_write = true
	await _click("将两只金镯交还陈家 · 5分钟")
	_check(not dialogue._result and before == _session.read_state(), "failed return rolls back")
	_session._save.library.fail_write = false
	await _click("将两只金镯交还陈家 · 5分钟")
	_check(dialogue._result and dialogue._pages.size() == 11, "extended return shown in eleven short pages")
	var committed := _session.read_state()
	_check(committed.cash == before.cash and committed.game_minutes == before.game_minutes + 5, "one five-minute return, no payment")
	_check(FirstDebt.owned(_session._day.state, FirstDebt.DRAGON) == null and FirstDebt.owned(_session._day.state, FirstDebt.PHOENIX) == null, "both real bangles handed back")
	_check(FirstDebt.flag(_session._day.state, "fd_clear") and not FirstDebt.flag(_session._day.state, "fd_yin_echo_seen"), "settled without revealing ledger echo")
	var saved := _session._save.library.read_entry("auto/" + str(_session.definition.id))
	_check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), committed), "saved full journal reloads")
	_check(not _session.counter_command("fd_event", "fd_settle", "return").ok, "duplicate cannot return twice")
	var all_text := "\n".join(dialogue._pages)
	_check(not all_text.contains("柜上的旧账记下") and all_text.contains("红黑账簿"), "quiet ledger hint replaces explicit account")
	while dialogue.visible and dialogue._next.visible:
		_check(view._active_id.ends_with("/chen"), "Chen retained while speaking")
		_check(dialogue._text.get_content_height() <= dialogue._text.size.y + 1, "paragraph fits without scroll")
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(dialogue._next.get_global_rect()), "advance inside viewport")
		if dialogue._pages[dialogue._page].begins_with("“"): _check(dialogue._speaker.text == "陈小满", "Chen's spoken lines attributed correctly")
		await shot("return-%02d" % dialogue._page)
		await _click_button(dialogue._next)
	await _frames()
	_check(not view._active_id.ends_with("/chen") and not dialogue.visible, "automatic departure after final hint")
	_check(committed == _session.read_state(), "reading free and no extra discoveries")
	await shot("departed")
	# Esc also completes presentation without stranding the visitor.
	await restore_stage("before-fd_settle" if aqi_version == 39 else "return-meeting"); screen._close_drawer(); await _frames()
	await _click_button(view._customer_hotspot); await _click("说说话")
	while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
	await _click("将两只金镯交还陈家 · 5分钟"); await key(KEY_ESCAPE)
	_check(not dialogue.visible and not view._active_id.ends_with("/chen"), "Esc releases finished visitor")
	_check(root.gui_get_focus_owner() != null, "focus restored")
	print("CHEN RETURN UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await create_timer(.2).timeout; RenderingServer.force_draw()
	var directory := "res://docs/qa/first-debt-release/ui/" if aqi_version == 39 else "res://docs/qa/chen-return-v31/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
