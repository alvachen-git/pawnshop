extends "res://tests/recovery_ui.gd"

var rendered_size := Vector2i(1280,720)

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("MERIT UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_merit_balance_manifest.json"; aqi_version = 43
	var requested := Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	rendered_size = requested
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.min_size = requested
	root.max_size = requested
	root.unresizable = true
	root.size = requested
	root.content_scale_size = requested; root.title = "香炉回应 · v43验收"; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v43/ui-unused.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v43/ui-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true,false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	_session.definition._initial_cash = 2000
	_session._save.library.register_catalog(aqi_manifest,_session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view; var dialogue := screen.first_debt_conversation
	var presenter := screen.merit_presenter; var stage := presenter.stage
	for mode in ["return","pay"]:
		aqi_fixture_dir = "res://.godot/qa/v43" + ("-pay" if mode == "pay" else "") + "/"
		await restore_stage("before-fd_compensation" if mode == "pay" else "before-fd_settle"); screen._close_drawer(); await _frames()
		await _click_button(view._customer_hotspot); await _click("说说话")
		while dialogue._next.visible and dialogue._page < dialogue._pages.size()-1: await _click_button(dialogue._next)
		if mode == "pay":
			var proposal_state := _session.read_state()
			await _click("与她商量300银元赔偿")
			_check(dialogue._result and not FirstDebt.settled(_session._day.state), "proposal is not settlement")
			_check(_session._day.state.cash == proposal_state.cash and _session._day.state.hidden_merit == 0, "proposal neither pays nor rewards")
			while dialogue._result: await _click_button(dialogue._next)
			while dialogue._next.visible and dialogue._page < dialogue._pages.size()-1: await _click_button(dialogue._next)
			_check(dialogue.visible, "proposal continues directly to payment choices")
			# Isolated display boundary: no fabricated cash is written to a save.
			var real_cash := _session._day.state.cash
			for cash in [299,300]:
				_session._day.state.cash = cash; _session._emit_changed(); dialogue.refresh(); dialogue.reopen()
				while dialogue._next.visible and dialogue._page < dialogue._pages.size()-1: await _click_button(dialogue._next)
				var button: Button = dialogue._choices.get_node("Case_fd_settle_pay")
				_check(button.disabled == (cash < 300), "payment enabled boundary " + str(cash))
				if cash == 299:
					_check(button.text.contains("现银不足300银元"), "insufficient cash reason visible without hover")
					var before_click := _session.read_state()
					for pressed in [true,false]:
						var mouse := InputEventMouseButton.new()
						mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = pressed
						mouse.position = button.get_global_rect().get_center()
						root.push_input(mouse,true)
					await _frames()
					_check(before_click == _session.read_state(), "disabled payment cannot debit or advance")
				await shot("pay-cash-" + str(cash))
			_session._day.state.cash = real_cash; _session._emit_changed(); dialogue.refresh(); dialogue.reopen()
			while dialogue._next.visible and dialogue._page < dialogue._pages.size()-1: await _click_button(dialogue._next)
		await shot(mode + "-before")
		await _click("交付300银元，立和解字据 · 5分钟" if mode == "pay" else "将两只金镯交还陈家 · 5分钟")
		_check(dialogue._result and _session._day.state.hidden_merit == (5 if mode == "pay" else 10),"reward saved during result " + mode)
		_check(stage.merit_elapsed < 0 and _session.merit_feedback_model().pending,"no animation over dialogue")
		var cash := _session._day.state.cash; var minute := _session._day.state.game_minutes
		if mode == "pay":
			# An actual disk failure when the last page releases the counter.
			_session._save.library.fail_write = true
			await key(KEY_ESCAPE)
			await create_timer(.15).timeout
			_check(presenter.retry.visible and _session.merit_feedback_model().pending and stage.merit_elapsed < 0,"failed ack offers retry without animation")
			_session._save.library.fail_write = false
			presenter.retry.get_ok_button().grab_focus()
			await key(KEY_ENTER)
		else:
			while dialogue.visible and dialogue._result:
				_check(dialogue._text.get_content_height() <= dialogue._text.size.y+1,"short paragraph fits")
				await _click_button(dialogue._next)
		await create_timer(.60).timeout
		_check(not dialogue.visible and not view.conversation_held,"Chen leaves and focus released")
		_check(stage.merit_strength > .8 and not _session.merit_feedback_model().pending,"warm echo starts after durable ack")
		await shot(mode + "-glow")
		_check(_session._day.state.cash == cash and _session._day.state.game_minutes == minute,"animation costs nothing")
		_check(stage.mouse_filter == Control.MOUSE_FILTER_IGNORE,"effect never captures mouse")
		await create_timer(2.6).timeout
		_check(stage.merit_elapsed < 0 and stage.merit_strength == 0,"returns to normal in three seconds")
		await shot(mode + "-after")
		var committed := _session.read_state()
		await _frames(); _session._emit_changed(); await _frames()
		_check(stage.merit_elapsed < 0 and committed == _session.read_state(),"refresh never replays")
		_check(root.gui_get_focus_owner() != null,"keyboard focus retained")
		# A restored pending reward must wait behind an open ledger.
		presenter.set_process(false)
		aqi_fixture_dir = "res://.godot/qa/v43/"
		await restore_stage("merit-pending-" + mode)
		screen._flow.show_panel(&"ledger"); await _frames()
		presenter.set_process(true); await _frames()
		_check(_session.merit_feedback_model().pending and stage.merit_elapsed < 0,"restored pending waits behind panel")
		await key(KEY_ESCAPE); await create_timer(.65).timeout
		_check(stage.merit_strength > .8,"pending restores once panel closes")
		_session._day.state.risk_pending = "test-interrupt"; await _frames()
		_check(stage.merit_strength == 0 and stage.merit_elapsed < 0,"crisis cancels warm echo immediately")
		# Restore exact, legal seen state; interrupted echo does not recur.
		await restore_stage("merit-seen-" + mode)
		await create_timer(.15).timeout
		_check(stage.merit_elapsed < 0 and not _session.merit_feedback_model().pending,"seen restore does not replay")
		var active := _session._counter.customers.active(_session._day.state)
		_check(active == null or active.customer_id != "fd_chen","Chen no longer occupies ordinary counter")
		if _session.bell_model().enabled:
			_check(_session.bell_command("wait").ok,"next guest reception available")
	print("WINDOW ",root.size," requested ",requested," texture ",root.get_texture().get_size()," native ",DisplayServer.window_get_size())
	_check(root.get_texture().get_size() == Vector2(requested),"rendered game viewport keeps requested dimensions")
	print("MERIT UI %d: %d assertions, %d failures" % [requested.x,_assertions,_failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await process_frame; RenderingServer.force_draw()
	var directory := "res://docs/qa/first-debt-merit-balance/ui/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory+str(rendered_size.x)+"-"+stage+".png") == OK,"capture " + stage)
