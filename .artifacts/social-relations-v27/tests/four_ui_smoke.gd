extends "res://tests/bargaining_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "four_1600" if "wide" in OS.get_cmdline_user_args() else "four_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	var loaded := JsonContentProvider.new("res://data/four_night_manifest.json").load_catalog()
	var run: RunDefinition = loaded.catalog.get_definition("runs", "ordinary_four")
	for target in ["foot", "bowl", "hairpin", "pawn"]:
		var selected_seed := -1
		for seed_value in 512:
			var first := VarietyService.plan(run, loaded.catalog, seed_value)[0]
			var role: String = first.get("sample_role", "")
			if (target == "foot" and role == "invalid") or (target == "bowl" and role == "flaw" and first.item_id == "item_blue_bowl") or (target == "hairpin" and role == "flaw" and first.item_id == "item_silver_hairpin") or (target == "pawn" and role == "pawn"):
				selected_seed = seed_value
				break
		_check(selected_seed >= 0, "reproducible UI seed for " + target)
		_main = load("res://scenes/four_night.tscn").instantiate()
		_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + "_" + target + ".json"
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		_session._day.state.run_seed = selected_seed
		_session._day.state.ordinary_selections.clear()
		_session._day.state.scenario_selections.clear()
		_session._counter.customers.prepare_night(_session._day.state, _session.definition, loaded.catalog)
		_session.changed.emit()
		await _frames()
		await _click("营业")
		await _capture(target + "_opening")
		await _click("开铺")
		var visit := _session._counter.customers.active(_session._day.state)
		if target == "pawn":
			await _click("交易")
			_check(not _session.counter_model().trade.can_offer and _session.counter_model().trade.can_pawn, "pawn-only clearly disables buy")
			_find_trade(_main)._pawn_price.value = 40
			await _click("正式报价并活当")
			_check(_session.read_state().pawn_tickets.size() == 1, "mouse creates one ticket")
			await _capture("pawn_receipt")
			# Four full room cycles, with the original owner at the front of night four.
			for night in range(1, 5):
				if night > 1:
					await _click("进入下一夜")
					await _click("营业")
					await _click("开铺")
				if night == 4:
					await _click_button((_main.get_node("CounterScreen/CounterView") as CounterView).get_hotspot(&"customer"))
					await _click("办理赎当")
					await _capture("fourth_return")
					await _click("验票收赎，交还原物")
					_check(_session.read_state().pawn_tickets[0].status == "redeemed", "mouse original-owner redemption")
				await _click("营业")
				await _click("关门（本夜不可重开）")
				await _click("等到封铺（消耗全部剩余时间）")
				await _click("合上今夜的账册")
				await _click("回房")
				await _click("床 · 就寝")
				await _click_button((_main.find_child("PrivateRoom", true, false) as PrivateRoomView)._confirm.get_ok_button())
				await _click("等到天明")
			await _click("合卷")
			_check(_session.read_state().phase == "run_ended", "mouse completes fourth night")
			await _capture("fourth_summary")
		else:
			await _click("鉴定")
			_check(not _session.counter_model().appraisal.images.any(func(row: Dictionary) -> bool: return row.id in ["seam", "foot_wear"]), "evidence hidden before inspection")
			var item: ItemDefinition = loaded.catalog.get_definition("items", visit.item.definition_id)
			for action in item.appraisal_actions:
				for entry in _session.counter_model().appraisal.buttons:
					if entry.command == "appraise" and entry.detail == action.id: await _click(entry.label); break
			await _click("底足磨损" if target == "foot" else ("釉面接缝" if target == "bowl" else "簪身接缝"))
			await _capture(target + "_evidence")
			await _click("交易")
			var clue := "mark" if target == "foot" else ("repair" if target == "bowl" else "condition_mended")
			var button := _command_button("pressure", clue)
			button.grab_focus()
			await _frames()
			_check(button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and not button.text.contains("…"), "full bargaining wording wraps")
			var evidence := _find_trade(_main).find_child("Evidence_" + clue, true, false) as Label
			_check(evidence != null and evidence.text == "已知线索：" + item.find_clue(clue).text, "full evidence visible")
			await _click_button(button)
			await _capture(target + "_bargaining")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
		_main.queue_free()
		await _frames()
	print("FOUR UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
