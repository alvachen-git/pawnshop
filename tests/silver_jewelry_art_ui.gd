extends "res://tests/integrated_ui_smoke.gd"

const ITEMS_TO_CHECK := ["item_silver_ring", "item_silver_lock"]

func _run() -> void:
	if not _review(): create_timer(300).timeout.connect(func() -> void: push_error("ITEM ART UI TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_capture_prefix = "1600" if "wide" in OS.get_cmdline_user_args() else "1280"
	var catalog := JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	for id in ITEMS_TO_CHECK:
		if _review() and id != ("item_silver_ring" if "review-ring" in OS.get_cmdline_user_args() else "item_silver_lock"): continue
		var chosen := -1
		var target := ""
		var night := 1
		for seed_value in 256:
			var state := RunState.create(run_def)
			state.run_seed = seed_value
			for row in OpeningPreparation.plan(state, run_def, catalog):
				if row.item_id == id and row.night == 1:
					chosen = seed_value; target = row.visit_id; night = row.night; break
			if chosen >= 0: break
		_check(chosen >= 0, "natural v21 schedule includes " + id)
		if chosen < 0: continue
		print("ITEM ART VISIT ", id, " seed=", chosen, " night=", night, " target=", target)
		_main = load("res://scenes/goods_expertise_start.tscn").instantiate()
		_main.get_node("Bootstrap").save_path = "res://.godot/qa/silver-jewelry/runtime/auto_%d.json" % Time.get_ticks_usec()
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		if _session._save.library != null: _session._save.library.path = "res://.godot/qa/silver-jewelry/runtime/library_%d.json" % Time.get_ticks_usec()
		_session.definition._randomize_seed = false; _session.definition._seed = chosen
		_session.new_run()
		_main.title_menu.configure(true, false)
		driver.check = _check; driver.catalog = _session._counter.catalog
		narrative = _main.get_node("CounterScreen/NarrativeScene")
		await _frames(); await _click_button(_main.title_menu.buttons[0])
		driver.open(_session)
		var visit: CustomerVisit
		for step in 120:
			driver.drain(_session)
			visit = _session._counter.customers.active(_session._day.state)
			if visit != null and visit.visit_id == target: break
			if visit != null: _session.counter_command("reject", visit.visit_id)
			else: driver.action(_session, "short_task")
		_check(visit != null and visit.visit_id == target and visit.item.definition_id == id, "real v21 visit " + id)
		await receipts()
		var screen := _main.get_node("CounterScreen") as CounterScreen
		var view := screen._counter_view
		var sprite := view._item_image
		screen._close_drawer(); _session.changed.emit(); await create_timer(.35).timeout
		var asset: String = _session.counter_model().visual.item_asset
		_check(sprite.visible and sprite.texture.resource_path == CounterItemArt.front_path(asset), "mapped actual item " + id)
		_check(sprite.material != null and sprite.get_global_rect().size.y > 20, "grounded item visible " + id)
		if DisplayServer.get_name() != "headless": Input.warp_mouse(Vector2(640, 8))
		var final_texture := sprite.texture
		var before_path: String = "res://assets/goods_v21/" + id.trim_prefix("item_") + "_front.svg"
		sprite.texture = load(before_path); sprite.material = null
		view._bounds(sprite, .425, .62, .595, .81)
		await _capture(id + "_before")
		view.render(_session.counter_model()); await _frames()
		_check(sprite.texture == final_texture, "old saved front path resolves to PNG")
		_check(view.get_hotspot(&"item").get_global_rect().size.x >= 80, "small jewelry retains easy click target")
		await _capture(id + "_counter")
		if _review(): return
		var before := _session.read_state()
		await _click_button(view.get_hotspot(&"item")); await _click("鉴定")
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._image.texture == sprite.texture and panel._image.material != null, "inspection shares front and keying " + id)
		for row in panel._images:
			_check(not row.path.is_empty() and ResourceLoader.exists(row.path), "no empty or invalid page " + row.id)
		if panel._images.any(func(row: Dictionary) -> bool: return row.id == "back"):
			await _click("背面"); _check(panel._image.material != null or not CounterItemArt.has_asset(asset), "back has correct cutout")
			await _capture(id + "_back"); await _click("正面")
		_check(_session.read_state() == before, "free image browsing never changes state " + id)
		await _capture(id + "_appraisal")
		for action in ["observe", "inspect", "crosscheck", "magnet", "scratch", "inscription"]:
			for entry in _session.counter_model().appraisal.buttons:
				if entry.command == "appraise" and entry.detail == action and entry.enabled:
					await _click(entry.label); break
		_check(not visit.item.revealed_clue_ids.is_empty(), "real evidence actions remain available " + id)
		await _capture(id + "_evidence")
		await _click("交易")
		var price: int = _session.counter_model().trade.asking_price
		var cash: int = _session._day.state.cash
		if price <= cash:
			_find_trade(_main)._price.value = price
			await _click("正式报价并收购")
			await _settle_feedback()
			_check(_session._day.state.cash == cash - price, "real purchase preserves price " + id)
			await receipts()
			_check(_session.counter_model().active_id != visit.visit_id, "purchased visit no longer owns counter/shadow " + id)
			if _session.counter_model().active_id.is_empty(): _check(not sprite.visible, "empty counter hides item and shadow")
			await _click("库存"); await _capture(id + "_inventory")
		# v21 accepts checkpoints after closing, not the v30 in-trade replay format.
		driver.action(_session, "close_shop"); driver.drain(_session)
		var codec := SaveCodec.new()
		var state_data: Variant = JSON.parse_string(JSON.stringify(codec.encode(_session._day.state, 21)))
		var restored := codec.decode(state_data, _session.definition, 21, _session._counter.catalog, true)
		_check(restored != null, "v21 closed checkpoint validation " + id + ": " + codec.error_message)
		if restored != null:
			_check(restored.inventory_instances.any(func(item: ItemInstance) -> bool: return item.definition_id == id), "checkpoint retains purchased jewelry")
			_session._day.state = restored; _session.restored.emit(); _session.changed.emit(); await _frames()
		_main.queue_free(); await process_frame
	print("SILVER JEWELRY UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := "res://.godot/qa/silver-jewelry-release/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_check(root.get_texture().get_image().save_png(folder + _capture_prefix + "_" + label + ".png") == OK, "window capture " + label)

func _review() -> bool:
	return "review-ring" in OS.get_cmdline_user_args() or "review-lock" in OS.get_cmdline_user_args()
