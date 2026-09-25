extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("DRAGON UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_dragon_search_manifest.json"; aqi_version = 31; aqi_fixture_dir = "res://.godot/qa/v31/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.title = "龙镯追查 · 本地验收"
	root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v31/ui-unused.json"
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_check(_session != null and _session.content_version == 31, "default v31")
	_session._save.library.path = "res://.godot/qa/v31/ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	_session.definition._initial_cash = 2000 # Funded UI fixtures, separate from authored default300.
	_session._save.library.register_catalog(aqi_manifest, _session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view
	var dialogue := screen.first_debt_conversation
	for stage in ["before-fd_search_motive", "search-ready", "invite-ready", "lu", "quoted", "letter"]:
		await restore_stage(stage)
		screen._close_drawer(); await _frames()
		if stage in ["search-ready", "invite-ready"]:
			screen._flow.show_panel(&"day"); await _frames()
			await shot(stage)
			var label := "托人寻找龙镯 · 1行动点" if stage == "search-ready" else "约陆掌眼带龙镯来 · 1行动点"
			var old_count := PreparationService.count(_session._day.state)
			await _click(label)
			_check(PreparationService.count(_session._day.state) == old_count + 1, "mouse preparation " + stage)
			await shot(stage + "-done")
		elif stage == "letter":
			_check(view.story.visible, "letter visible after accounts")
			await shot(stage)
			await key(KEY_ESCAPE)
			_check(not view.story.visible, "letter Esc")
			await _click_button(view._item_hotspot)
			_check(view.story.visible, "letter reopens on counter")
			await key(KEY_ENTER)
			_check(FirstDebt.flag(_session._day.state, "fd_search_message"), "letter acknowledged")
			await shot("letter-kept")
		else:
			await _click_button(view._customer_hotspot)
			await _click("验看与谈价" if stage in ["lu", "quoted"] else "说说话")
			_check(dialogue.visible, "RPG conversation " + stage)
			while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
			for b in dialogue._choices.get_children(): _check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(b.get_global_rect()), "choice within viewport")
			await shot(stage)
			await key(KEY_ESCAPE)
			_check(not dialogue.visible, "Esc dismisses")
			await _click_button(view._customer_hotspot)
			await _click("验看与谈价" if stage in ["lu", "quoted"] else "说说话")
			while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
			if stage == "before-fd_search_motive":
				await _click("我替你打听另一只")
				_check(FirstDebt.flag(_session._day.state, "fd_search_promised"), "promise writes choice")
			elif stage == "lu":
				await _click("验看龙镯，问问价钱")
				_check(DragonSearch.quoted(_session._day.state), "mouse quote")
			else:
				var cash := _session._day.state.cash
				await _click("付150银元收下龙镯 · 5分钟")
				_check(_session._day.state.cash == cash - 150, "mouse purchase150")
				_check(dialogue.visible and view._active_id.ends_with("/lu"), "Lu held through reply")
				await shot("purchase-reply")
			var before := _session.read_state()
			# Background clicks cannot ring the bell through the reply.
			var point: Vector2 = view.bell.get_global_rect().get_center()
			for pressed in [true, false]:
				var input := InputEventMouseButton.new(); input.button_index = MOUSE_BUTTON_LEFT; input.pressed = pressed; input.position = point; root.push_input(input, true)
			await _frames()
			_check(before == _session.read_state(), "dialogue blocks click-through")
			while dialogue.visible and dialogue._next.visible: await _click_button(dialogue._next)
			if stage != "lu":
				_check(not dialogue.visible, "reply closes on completion")
				_check(not view._active_id.ends_with("/lu") if stage == "quoted" else not view._active_id.ends_with("/chen"), "speaker departs")
				await shot(stage + "-departed")
			else: await key(KEY_ESCAPE)
	print("DRAGON UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await create_timer(.3).timeout
	RenderingServer.force_draw()
	var directory := "res://docs/qa/dragon-search-v31/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
