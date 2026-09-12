extends "res://tests/bargaining_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "quote_deadline_1600" if "wide" in OS.get_cmdline_user_args() else "quote_deadline_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v9.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var helper := BargainingTests.new()
	helper.setup(_check)
	await _frames()
	var screen: CounterScreen = _main.get_node("CounterScreen")
	for accepted in [true, false]:
		_session.new_run()
		helper.open(_session)
		var v := helper.active(_session)
		_session._day.state.game_minutes = v.expires_at - 5
		_session.changed.emit()
		await _click("交易")
		var panel := _find_trade(_main)
		panel._price.value = v.trade.reserve_price if accepted else 1
		var cash := _session._day.state.cash
		await _click_button(panel._submit)
		await _frames()
		_check(_session._day.state.game_minutes == v.expires_at, "quote consumes five minutes")
		_check(v.status == ("bought" if accepted else "timed_out"), "outcome matches quote")
		if accepted:
			_check(screen._receipt.visible and _session._day.state.cash == cash - v.trade.reserve_price, "paid receipt at expiry")
			await _capture("accepted")
			await _click_button(screen._receipt._primary)
		else:
			_check(_session._day.state.cash == cash and not screen._receipt.visible, "no false paid receipt")
			var text := screen._recent_button.text
			_check(text.contains("这个价钱不成。") and text.contains(CustomerReplyModel.LINES.timed_out), "persistent reply shows refusal then departure")
			_check(text.find("这个价钱不成。") < text.find(CustomerReplyModel.LINES.timed_out), "reply sequence")
			_check(screen._recent_bar.get_global_rect().end.y <= screen._status_view.global_position.y, "reply does not cover status")
			await _capture("refused")
			var before := _session.read_state()
			await _click_button(screen._recent_button)
			var refusal := String(v.voice.get("refused", "对方拒绝了报价，提出新的要价。"))
			_check(screen._receipt.visible and screen._receipt._note.text.begins_with(refusal), "details retain original refusal and departure dialogue")
			await _capture("refused_details")
			await _click_button(screen._receipt._primary)
			_check(before == _session.read_state(), "reviewing result spends no time")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("QUOTE DEADLINE UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
