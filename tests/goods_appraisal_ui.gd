extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("GOODS APPRAISAL TIMEOUT"); quit(1))
	_capture_prefix = "goods_appraisal_1600" if "wide" in OS.get_cmdline_user_args() else "goods_appraisal_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720); root.content_scale_size = root.size
	var catalog := JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	for id in ["item_silver_ring", "item_silver_lock", GoodsExpertise.FAN, GoodsExpertise.CUP]:
		var chosen := -1; var target := ""
		for seed_value in 512:
			var state := RunState.create(run_def); state.run_seed = seed_value
			for row in OpeningPreparation.plan(state, run_def, catalog):
				if row.night == 1 and row.item_id == id: chosen = seed_value; target = row.visit_id; break
			if chosen >= 0: break
		_check(chosen >= 0, "new item natural seed " + id)
		_main = load("res://scenes/goods_expertise_start.tscn").instantiate(); root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		_session._save.library.path = "res://.godot/qa/goods/appraisal_%d.json" % Time.get_ticks_usec()
		_session.definition._randomize_seed = false; _session.definition._seed = chosen
		_main.title_menu.configure(true, false)
		driver.check = _check; driver.catalog = _session._counter.catalog
		narrative = _main.get_node("CounterScreen/NarrativeScene")
		await _frames(); await _click_button(_main.title_menu.buttons[0]); driver.drain(_session)
		driver.action(_session, "open_shop"); driver.drain(_session)
		var visit: CustomerVisit
		for step in 120:
			driver.drain(_session); visit = _session._counter.customers.active(_session._day.state)
			if visit != null and visit.visit_id == target: break
			if visit != null: _session.counter_command("reject", visit.visit_id)
			else: _session.execute("short_task")
		_check(visit != null and visit.visit_id == target, "actual appraisal caller")
		await receipts(); await _click("鉴定")
		await _capture(id + "_front")
		for action in ["observe", "inspect", "crosscheck"]:
			for entry in _session.counter_model().appraisal.buttons:
				if entry.command == "appraise" and entry.detail == action: await _click(entry.label); break
		_check(visit.item.revealed_clue_ids.size() == 3, "three real appraisal actions")
		if id == GoodsExpertise.CUP: await _click("纹样式样")
		await _capture(id + "_evidence")
		_main.queue_free(); await process_frame
	print("GOODS APPRAISAL UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
