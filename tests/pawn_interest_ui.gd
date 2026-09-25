extends "res://tests/ui_smoke.gd"

func restore_fixture(label: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/pawn-v45/" + label + ".json"))
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var state := codec.decode(payload, _session.definition, 45, _session._counter.catalog, true)
	_check(state != null, "fixture " + label + " " + codec.error_message)
	if state == null: quit(1); return
	_session._day.state = state; _session._save = GhostReplayStore.new()
	_session.restored.emit(); _session.changed.emit()
	await _frames()

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("PAWN UI TIMEOUT"); quit(1))
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var panel := screen.get_node("%TradePanel") as TradePanel
	var talk := screen.first_debt_conversation
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "pawn_v45_%d" % dimensions.x
		await restore_fixture("night-one")
		screen._flow.show_panel(&"trade"); await _frames()
		_check(not panel._pawn_mode.visible and not panel._interest_row.visible, "first night hides pawn controls")
		screen._close_drawer()
		await restore_fixture("tutorial")
		_check(talk.visible and not screen.get_node("%Drawer").visible, "third night uses RPG")
		_check(screen._counter_view._portrait.texture.resource_path == CounterVisualCatalog.LU_ELDERLY_PORTRAIT, "elder Lu portrait")
		await _capture("01_tutorial")
		var before := _session.read_state()
		talk.collapse(); await _frames()
		await _click_button(screen._counter_view.get_hotspot(&"customer")); await _click("交谈")
		_check(talk.visible and _session.read_state() == before, "teaching collapses and reopens without effects")
		for step in 3:
			for page_guard in 20:
				_check(talk._text.get_content_height() <= talk._text.size.y + 1, "RPG page fits")
				if talk._page == talk._pages.size() - 1: break
				_check(talk._choices.get_child_count() == 0, "choices after speech")
				await create_timer(0.20).timeout; await _click_button(talk._next)
			_check(talk._choices.get_child_count() == 1, "teaching response")
			if step == 1: await _capture("02_rates_speech")
			await _click_button(talk._choices.get_child(0))
			for reply_guard in 20:
				if not talk._result: break
				await create_timer(0.20).timeout; await _click_button(talk._next)
		_check(PawnInterestPolicy.unlocked(_session._day.state, _session.definition) and not talk.visible, "farewell unlock through actual dialogue buttons")
		_check(_session._day.state.game_minutes == 0 and PreparationService.count(_session._day.state) == 0, "teaching costs no time or AP")
		_check(screen._market_notice.visible, "Lu letter remains available")
		await restore_fixture("pawn-visit")
		var visitor := _session._counter.customers.active(_session._day.state)
		var timing_cue := PawnInterestPolicy.cue(_session._day.state, visitor)
		_check(not _session.counter_model().trade.visual.pawn_terms.contains(timing_cue), "trade hides unsolicited timing cue")
		screen._flow.show_panel(&"dialogue"); await _frames()
		await _click("问：这笔钱何时要用？ · 5分钟")
		var dialogue := screen.get_node("%DialoguePanel")
		_check(dialogue._body.text.contains(timing_cue), "timing answer appears after actual question click")
		await _capture("06_timing_dialogue")
		screen._flow.show_panel(&"trade"); await _frames()
		if panel._mode != "pawn": await _click_button(panel._pawn_mode)
		_check(panel._interest_row.is_visible_in_tree() and panel._interest_tier == "medium", "new visitor defaults medium")
		var model_before := _session.read_state()
		panel._pawn_price.value = 21; await _frames()
		for tier in ["low", "medium", "high"]:
			await _click_button(panel._interest_buttons[tier])
			var fee := PawnInterestPolicy.fee(21, tier)
			_check(panel._interest_preview.text.contains("息费 %d" % fee) and panel._interest_preview.text.contains("赎金 %d" % (21 + fee)), "preview ceil " + tier)
			_check(not panel._interest_buttons[tier].disabled, "high not blocked by hidden knowledge")
			for control in [panel._interest_row, panel._interest_preview, panel._pawn_submit]:
				_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(control.get_global_rect()), "contract control fits viewport")
		_check(model_before == _session.read_state(), "browsing rates has no mutations")
		await _capture("03_high_quote")
		screen._close_drawer(); screen._flow.show_panel(&"trade"); await _frames()
		_check(panel._interest_tier == "high", "same visitor retains draft after reopen")
		var v := _session._counter.customers.active(_session._day.state)
		var refused := PawnInterestPolicy.refuses_high(_session._day.state, v)
		panel._pawn_price.value = _session.counter_model().trade.pawn_asking
		if refused:
			await _click_button(panel._pawn_submit)
			_check(PawnInterestPolicy.high_recorded(_session._day.state, v.visit_id) and v.status == "active", "actual high refusal and reputation record")
			_check(panel._content_scroll.get_global_rect().encloses(panel._feedback.get_global_rect()), "customer refusal visible without scrolling")
			await _capture("04_refusal")
		await _click_button(panel._interest_buttons.low)
		var principal := int(panel._pawn_price.value)
		await _click_button(panel._pawn_submit)
		_check(_session._day.state.pawn_tickets.size() == 1, "UI submits pawn")
		var ticket := _session._day.state.pawn_tickets[0]
		_check(ticket.interest_tier == "low" and ticket.redemption_amount == principal + PawnInterestPolicy.fee(principal, "low"), "selected tier issued")
		await _capture("05_receipt")
	print("PAWN INTEREST UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
