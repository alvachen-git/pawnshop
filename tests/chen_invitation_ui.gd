extends "res://tests/dragon_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("CHEN UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_dragon_search_manifest.json"; aqi_version = 31; aqi_fixture_dir = "res://.godot/qa/chen-invitation/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size; root.title = "陈小满预约修复验收"; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").save_path = "res://.godot/qa/chen-invitation/ui-unused.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/chen-invitation/ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	_session.definition._initial_cash = 2000
	_session._save.library.register_catalog(aqi_manifest, _session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view; var dialogue := screen.first_debt_conversation
	for stage in ["help-preparation", "help-uninvited", "later-uninvited", "help-meeting", "later-meeting", "return-meeting"]:
		await restore_stage(stage); screen._close_drawer(); await _frames()
		if stage == "help-preparation":
			screen._flow.show_panel(&"day"); await _frames(); await shot(stage)
			await _click("约陈小满来谈 · 准备1次")
			_check(PreparationService.count(_session._day.state) == 1, "mouse invitation one preparation")
		elif stage.ends_with("uninvited"):
			_check(not view._active_id.ends_with("/chen") and not dialogue.visible, "uninvited no portrait or dialogue")
			await shot(stage)
		else:
			_check(view._active_id.ends_with("/chen"), "invited portrait")
			await _click_button(view._customer_hotspot); await _click("说说话")
			_check(dialogue.visible, "RPG opens")
			while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
			await shot(stage)
			if stage == "help-meeting": await _click("这笔旧账，我眼下不愿承担")
			elif stage == "later-meeting": await _click("我替你打听另一只")
			else: await _click("将两只金镯交还陈家 · 5分钟")
			_check(dialogue._result and dialogue.visible, "result shown before departure")
			_check(view._active_id.ends_with("/chen"), "portrait held during reply")
			if stage == "help-meeting": await key(KEY_ESCAPE)
			else:
				while dialogue.visible and dialogue._next.visible: await _click_button(dialogue._next)
			await _frames()
			_check(not dialogue.visible and not view._active_id.ends_with("/chen"), "response done leaves counter")
			_check(not FirstDebt.chen_waiting(_session._day.state), "no immediate repeat visit")
			await shot(stage + "-departed")
	print("CHEN UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await create_timer(.3).timeout; RenderingServer.force_draw()
	var directory := "res://docs/qa/chen-invitation-v31/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
