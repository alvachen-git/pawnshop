extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("GOODS APPRAISAL TIMEOUT"); quit(1))
	_capture_prefix = "ring_1600" if "wide" in OS.get_cmdline_user_args() else "ring_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720); root.content_scale_size = root.size
	var catalog := JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	for id in ["item_silver_ring"]:
		var chosen := -1; var target := ""
		for seed_value in 512:
			var state := RunState.create(run_def); state.run_seed = seed_value
			for row in OpeningPreparation.plan(state, run_def, catalog):
				if row.night == 1 and row.item_id == id: chosen = seed_value; target = row.visit_id; break
			if chosen >= 0: break
		_check(chosen >= 0, "new item natural seed " + id)
		_main = load("res://scenes/goods_expertise_start.tscn").instantiate()
		_main.get_node("Bootstrap").save_path = "user://tests/ring_%d.json" % Time.get_ticks_usec()
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		if _session._save.library != null: _session._save.library.path = "res://.godot/qa/goods/appraisal_%d.json" % Time.get_ticks_usec()
		_session.definition._randomize_seed = false; _session.definition._seed = chosen
		_session.new_run()
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
			await create_timer(0.6).timeout
			await receipts()
		_check(visit != null and visit.visit_id == target and visit.item.definition_id == id, "actual ring appraisal caller")
		await receipts()
		var view := _main.get_node("CounterScreen/CounterView") as CounterView
		var sprite := view.get_node("CounterItemImage") as TextureRect
		_main.get_node("CounterScreen")._close_drawer()
		_session.changed.emit()
		await create_timer(0.4).timeout
		_check(sprite.texture.resource_path == "res://assets/art10/items/silver_ring_front.png", "ring uses new alpha artwork")
		_check(is_equal_approx(sprite.anchor_left, 0.475) and is_equal_approx(sprite.anchor_right, 0.545), "ring counter uses small tabletop bounds")
		var final_texture := sprite.texture
		var final_bounds := Vector4(sprite.anchor_left, sprite.anchor_top, sprite.anchor_right, sprite.anchor_bottom)
		view._bounds(sprite, 0.425, 0.62, 0.595, 0.81)
		sprite.texture = load("res://assets/goods_v21/silver_ring_front.svg")
		await _capture("before_counter")
		sprite.texture = final_texture
		view._bounds(sprite, final_bounds.x, final_bounds.y, final_bounds.z, final_bounds.w)
		await _capture("after_counter")
		var before := _session.read_state()
		await _click_button(view.get_hotspot(&"item"))
		await _click("鉴定")
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._image.texture == final_texture, "appraisal uses same ring")
		_check(_session.read_state() == before, "opening appraisal does not change gameplay state")
		_check(CounterVisualCatalog.front("goods.silver_ring", [{"id": "front", "path": "res://assets/goods_v21/silver_ring_back.svg"}]).resource_path.ends_with("silver_ring_back.svg"), "explicit custom art is preserved")
		await _capture(id + "_front")
		for action in ["observe", "inspect", "crosscheck"]:
			for entry in _session.counter_model().appraisal.buttons:
				if entry.command == "appraise" and entry.detail == action: await _click(entry.label); break
		_check(visit.item.revealed_clue_ids.size() == 3, "three real appraisal actions")
		if id == GoodsExpertise.CUP: await _click("纹样式样")
		await _capture(id + "_evidence")
		_main.queue_free(); await process_frame
	print("SILVER RING UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "res://docs/qa/silver-ring/" + _capture_prefix + "_" + label + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "saved actual window render " + label)
