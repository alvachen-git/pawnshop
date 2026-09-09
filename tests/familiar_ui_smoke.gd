extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("FAMILIAR UI TIMEOUT"); quit(1))
	_capture_prefix = "familiar_1600" if "wide" in OS.get_cmdline_user_args() else "familiar_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	for seed_value in ([508] if "funded" in OS.get_cmdline_user_args() else [507, 511]):
		_main = load("res://scenes/start.tscn").instantiate()
		_main.get_node("Bootstrap").manifest_path = "res://data/familiar_manifest.json"
		_main.get_node("Bootstrap").save_path = "res://.godot/qa/familiar/ui_auto_%d.json" % seed_value
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		_session._save.library.path = "res://.godot/qa/familiar/ui_library_%d.json" % Time.get_ticks_usec()
		_main.title_menu.configure(true, false)
		_session.definition._randomize_seed = false
		_session.definition._seed = seed_value
		driver.check = _check
		driver.catalog = _session._counter.catalog
		narrative = _main.get_node("CounterScreen/NarrativeScene")
		await _frames()
		await _click_button(_main.title_menu.buttons[0])
		_check(_session.definition.id == "familiar_seven", "new entry uses v17")
		for night in range(1, 8):
			driver.drain(_session)
			if night >= 2: driver.action(_session, "prep_finish")
			driver.action(_session, "open_shop")
			driver.drain(_session)
			while not PawnReturnService.current(_session._day.state).is_empty():
				await receipts()
				await _click_button(_main.get_node("CounterScreen/CounterView").get_hotspot(&"customer"))
				await _click("办理赎当")
				await _capture("%d_redemption" % seed_value)
				await _click("验票收赎，交还原物")
				await receipts()
			for step in 150:
				if _session._day.state.game_minutes >= 470: break
				driver.drain(_session)
				var v := _session._counter.customers.active(_session._day.state)
				if v == null: driver.action(_session, "short_task"); continue
				var row := VarietySaveCodec.selection(_session._day.state, v.visit_id)
				if not row.has("familiar_id"):
					_check(_session.counter_command("reject", v.visit_id).ok, "ordinary reception")
					continue
				await receipts()
				await _click("对话")
				if row.get("familiar_id") == "seamstress" and row.get("familiar_stage") == "follow" and seed_value == 508:
					var body: String = _session.counter_model().dialogue.body
					_check(body.contains("赎簪的钱留好了") and body.contains("针线") and not body.contains("还差0"), "funded caller explains a separate reason to sell")
				await _capture("%d_%s_%s" % [seed_value, row.familiar_id, row.familiar_stage])
				_check(_session.counter_model().visual.customer_name.contains(v.person.name), "fixed name visible")
				await _click("交易")
				var trade := _find_trade(_main)
				if row.familiar_id == "bookkeeper" and row.familiar_stage == "first":
					await _click("鉴定")
					_check(_session.counter_command("appraise", v.visit_id, "observe").ok, "inspect pen form")
					_check(_session.counter_command("appraise", v.visit_id, "inspect").ok, "inspect pen condition")
					await _click("交易")
					await _click_trade_intent("pressure", "flaw" if v.item.selected_variant_id == "flawed" else "condition_replacement_nib")
					trade._price.value = v.trade.reserve_price
					await _click("正式报价并收购")
				elif row.familiar_id == "seamstress" and row.familiar_stage == "first":
					trade._pawn_price.value = maxi(25, roundi(v.trade.reserve_price * 0.5))
					await _click("正式报价并活当")
				elif row.familiar_id == "seamstress":
					trade._price.value = v.trade.reserve_price
					await _click("正式报价并收购")
				else:
					await _capture("%d_candid_price" % seed_value)
					await _click_trade_intent("reject", "")
				await receipts()
			driver.action(_session, "close_shop")
			driver.action(_session, "wait_until_seal")
			for ticket in _session._commerce.pawns.maturities(_session._day.state): _session.choose_pawn_disposal(ticket.ticket_id, "keep")
			driver.action(_session, "resolve_night")
			for command in ["enter_room", "sleep", "finish_sleep"]:
				driver.drain(_session); driver.action(_session, command)
			driver.action(_session, "continue_run")
			await receipts()
		await _click("铺中记事")
		await _capture("%d_known_notes" % seed_value)
		await _click("夜间结算")
		await _capture("%d_final" % seed_value)
		_check(_session._day.state.phase == &"run_ended", "seven-night chapter closes")
		_main.queue_free(); await process_frame
	print("FAMILIAR UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
