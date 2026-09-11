extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(420).timeout.connect(func() -> void: push_error("NIGHT UI TIMEOUT"); quit(1))
	_capture_prefix = "night_1600" if "wide" in OS.get_cmdline_user_args() else "night_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/night-ui-%s-%d.json" % [_capture_prefix, Time.get_ticks_usec()]
	_session.definition._randomize_seed = false
	_session.definition._seed = 0
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	_check(_main.find_child("AmbientVolume", true, false) == null, "no ambient controls")
	await _click_button(_main.title_menu.buttons[0])
	var captured := {}
	for night in range(1, 5):
		driver.open(_session)
		await receipts()
		for step in 125:
			driver.drain(_session)
			if _session._day.state.game_minutes >= 530 or _session._day.state.phase != &"open": break
			var visit := _session._counter.customers.active(_session._day.state)
			if visit == null:
				_session.execute("short_task")
				continue
			if not visit.night_policy.is_empty() and not captured.has(visit.night_policy):
				await receipts()
				await _click("交易")
				var trade := _find_trade(_main)
				_check(not trade._forms[2].visible and not trade._forms[3].visible, "night sellers have no pawn form")
				_check(trade._body.text.contains("只报一回") if visit.night_policy == "one_quote" else trade._body.text.contains("来处莫问"), "rule visible before quote")
				await _capture(visit.night_policy)
				captured[visit.night_policy] = true
				if visit.night_policy == "one_quote":
					_check(trade._buttons.get_children().all(func(b: Node) -> bool: return not b is Button or b.get_meta("trade_command", "") not in ["pressure", "belittle", "concession"]), "no secondary price-pressure buttons")
					trade._price.value = 1
					await _click("正式报价并收购")
					_check(visit.status == "rounds_exhausted", "single rejected price leaves")
				else:
					await _click("对话")
					var origin: Array = _session.counter_model().dialogue.buttons.filter(func(b: Dictionary) -> bool: return b.command == "question" and b.detail == "origin")
					_check(origin.size() == 1, "origin question available")
					if not origin.is_empty(): await _click(origin[0].label)
					_check(NightMarketRisk.lamp_level(_session._day.state) == 1, "forbidden question has actual personal consequence")
					await _capture("taboo")
					await _click("交易")
					trade._price.value = visit.trade.asking_price
					await _click("正式报价并收购")
					await _capture("wet_receipt")
				await receipts()
			elif visit.status == "active":
				_session.counter_command("reject", visit.visit_id)
			await receipts()
		if _session._day.state.phase == &"open": driver.action(_session, "close_shop")
		if _session._day.state.phase == &"closed_processing": driver.action(_session, "wait_until_seal")
		driver.action(_session, "resolve_night")
		driver.action(_session, "enter_room"); driver.drain(_session)
		await receipts(); await _frames()
		if captured.has("wet_cloth"):
			var room: PrivateRoomView = _main.get_node("CounterScreen")._room
			_check(int(room._state_material.get_shader_parameter("lamp_grade")) == NightMarketRisk.lamp_level(_session._day.state), "new bedroom receives actual lamp consequence")
			await _click_button(_main.get_node("CounterScreen")._room._lamp)
			await _capture("blue_lamp")
			break
		driver.action(_session, "sleep"); driver.drain(_session)
		driver.action(_session, "finish_sleep"); driver.drain(_session)
		driver.action(_session, "continue_run")
	_check(captured.has("one_quote") and captured.has("wet_cloth"), "both actual sellers captured")
	await _click_button(_main.get_node("CounterScreen")._room._menu)
	_check(_main.find_child("AmbientMute", true, false) == null, "removed mute control")
	await _capture("menu")
	print("NIGHT MARKET UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
