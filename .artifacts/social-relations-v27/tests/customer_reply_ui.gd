extends "res://tests/receipt_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "reply_1600" if "wide" in OS.get_cmdline_user_args() else "reply_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	await _boot("res://data/legacy/content_v9.json")
	var helper := RoomTests.new()
	helper._expect = _check; helper.catalog = _session._counter.catalog; helper.run_def = _session.definition
	var screen: CounterScreen = _main.get_node("CounterScreen")
	for style in ["satisfied", "reluctant", "refused", "timed_out", "rejected"]:
		print("REPLY CASE: ", style)
		_session.new_run(); helper.open(_session)
		var visit := helper.active(_session)
		var visual: Dictionary = _session.counter_model().visual
		var name := String(visual.customer_name)
		var cash: int = _session.read_state().cash
		await _click("交易")
		var trade := _find_trade(_main)
		if style in ["satisfied", "reluctant"]:
			trade._price.value = visit.trade.asking_price if style == "satisfied" else visit.trade.reserve_price
			await _click("正式报价并收购")
			_check(visit.status == "bought", "actual paid trade " + style)
		elif style == "refused":
			visit.trade.rounds_left = 1
			trade._price.value = 1
			await _click("正式报价并收购")
		elif style == "timed_out":
			visit.expires_at = _session._day.state.game_minutes + 5
			_session.execute("short_task")
		else:
			await _click_button(trade._reject)
		await _frames()
		_check(screen._recent_button.get_meta("reply_style") == style, "distinct real outcome " + style)
		_check(screen._recent_button.text.contains(name) and screen._recent_button.text.contains(CustomerReplyModel.LINES[style]), "reply names original guest " + style)
		if style in ["satisfied", "reluctant"]:
			_check(screen._receipt.visible and screen._receipt._stamp.visible, "successful trade shows stamped receipt " + style)
			await _click_button(screen._receipt._primary)
		_check(not screen._feedback.visible and screen._feedback.get_child_count() == 0 and not screen._receipt.visible, "no popup, sound or timed overlay " + style)
		_check(not screen._counter_view.feedback_held and not screen._status_view.cash_held, "no artificial reception or cash delay")
		if style not in ["satisfied", "reluctant"]: _check(_session.read_state().cash == cash, "unpaid departure never debits")
		var before := _session.read_state()
		var text := screen._recent_button.text
		await create_timer(1.2).timeout
		_check(screen._recent_button.is_visible_in_tree() and screen._recent_button.text == text and before == _session.read_state(), "reply stays after old popup timeout")
		_check(screen.get_global_rect().encloses(screen._recent_bar.get_global_rect()), "reply inside viewport")
		_check(screen._recent_bar.get_global_rect().end.y <= screen._status_view.global_position.y, "reply does not cover cash/status")
		await _capture(style)
		print("REPLY CAPTURED: ", style)
		_session.changed.emit(); await _frames()
		print("REPLY REFRESHED: ", style)
		_check(screen._recent_button.text == text and before == _session.read_state(), "refresh does not replay or erase reply")
		_check(not _session.counter_command("offer", visit.visit_id, "", 72).ok and before == _session.read_state(), "stale quote cannot charge twice")
		print("REPLY STALE CHECKED: ", style)
		await _click("库存")
		print("REPLY INVENTORY: ", style)
		_check(screen._recent_button.text == text and before == _session.read_state(), "browsing keeps reply and does not consume time")
	# A rejected quote without departure is not mislabeled as a departing guest.
	_session.new_run(); helper.open(_session)
	var visit := helper.active(_session)
	_session.counter_command("offer", visit.visit_id, "", 1)
	await _frames()
	_check(visit.status == "active" and screen._recent.is_empty() and not screen._feedback.visible, "failed quote continues negotiation without departure reply")
	# Classification uses public pawn asking, not purchase asking or hidden value.
	var operation := {"before": {"counter": {"visual": {"customer_name": "测试客", "asking": 100}, "trade": {"pawn_asking": 50}}}}
	_check(CustomerReplyModel.build({"kind": "pawn_loan", "amount": -50}, operation).style == "satisfied", "pawn compares with loan asking")
	_check(CustomerReplyModel.build({"kind": "pawn_loan", "amount": -40}, operation).style == "reluctant", "discounted pawn reply")
	print("CUSTOMER REPLY UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)
