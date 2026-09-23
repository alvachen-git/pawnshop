extends "res://tests/integrated_ui_smoke.gd"

const CASES := [["item_blue_bowl", "sound"], ["item_blue_bowl", "repaired"], ["item_silver_hairpin", "mended"], ["item_silver_ring", "sound"], ["item_silver_ring", "flawed"], ["item_silver_ring", "mended"], ["item_silver_lock", "sound"], ["item_silver_lock", "flawed"], ["item_silver_lock", "mended"]]

func _run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("ITEM ART UI TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_capture_prefix = "1600" if "wide" in OS.get_cmdline_user_args() else "1280"
	var manifest := "res://data/unified_manifest.json" if "v30" in OS.get_cmdline_user_args() else "res://data/named_wealthy_manifest.json"
	_capture_prefix = ("v30_" if "v30" in OS.get_cmdline_user_args() else "v37_") + _capture_prefix
	var catalog := JsonContentProvider.new(manifest).load_catalog().catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	for case in CASES:
		var id: String = case[0]
		var variant: String = case[1]
		if "detail-feedback" in OS.get_cmdline_user_args() and (id not in ["item_silver_ring", "item_silver_lock"] or variant == "mended"): continue
		var chosen := -1
		var target := ""
		var night := 1
		for seed_value in 512:
			var state := RunState.create(run_def)
			state.run_seed = seed_value
			for row in OpeningPreparation.plan(state, run_def, catalog):
				if row.item_id == id and row.variant_id == variant and row.night == 1:
					chosen = seed_value; target = row.visit_id; night = row.night; break
			if chosen >= 0: break
		_check(chosen >= 0, "natural schedule includes " + id + "/" + variant)
		if chosen < 0: continue
		print("ITEM ART VISIT ", id, " seed=", chosen, " night=", night, " target=", target)
		_main = load("res://scenes/start.tscn").instantiate()
		_main.get_node("Bootstrap").manifest_path = manifest
		_main.get_node("Bootstrap").save_path = "res://.godot/qa/item-art/runtime/auto_%d.json" % Time.get_ticks_usec()
		root.add_child(_main)
		_session = _main.get_node("Bootstrap").session
		if _session._save.library != null: _session._save.library.path = "res://.godot/qa/item-art/runtime/library_%d.json" % Time.get_ticks_usec()
		_session.definition._randomize_seed = false; _session.definition._seed = chosen
		_session.new_run()
		_main.title_menu.configure(true, false)
		driver.check = _check; driver.catalog = _session._counter.catalog
		narrative = _main.get_node("CounterScreen/NarrativeScene")
		await _frames(); await _click_button(_main.title_menu.buttons[0])
		for preceding in range(1, night):
			driver.open(_session)
			for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
				driver.action(_session, action); driver.drain(_session)
		driver.open(_session)
		var visit: CustomerVisit
		for step in 120:
			driver.drain(_session)
			visit = _session._counter.customers.active(_session._day.state)
			if visit != null and visit.visit_id == target: break
			if visit != null: _session.counter_command("reject", visit.visit_id)
			else: driver.action(_session, "short_task")
		_check(visit != null and visit.visit_id == target and visit.item.definition_id == id, "real visit " + id + "/" + variant)
		await receipts()
		var screen := _main.get_node("CounterScreen") as CounterScreen
		var view := screen._counter_view
		var sprite := view._item_image
		screen._close_drawer(); _session.changed.emit(); await create_timer(.35).timeout
		var asset: String = _session.counter_model().visual.item_asset
		_check(sprite.visible and sprite.texture.resource_path == CounterItemArt.front_path(asset), "mapped actual item " + id)
		_check(sprite.material != null and sprite.get_global_rect().size.y > 20, "grounded item visible " + id)
		if DisplayServer.get_name() != "headless": Input.warp_mouse(Vector2(640, 8))
		await _capture(id + "_counter")
		var before := _session.read_state()
		await _click_button(view.get_hotspot(&"item")); await _click("鉴定")
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._image.texture == sprite.texture and panel._image.material != null, "inspection shares front and keying " + id)
		_check(panel._images.size() == 2, "free pages contain only neutral front and back")
		for row in panel._images:
			_check(not row.path.is_empty() and ResourceLoader.exists(row.path), "no empty or invalid page " + row.id)
		if panel._images.any(func(row: Dictionary) -> bool: return row.id == "back"):
			await _click("背面"); _check(panel._image.material != null or not CounterItemArt.has_asset(asset), "back has correct cutout")
			await _capture(id + "_back"); await _click("正面")
		_check(_session.read_state() == before, "free image browsing never changes state " + id)
		await _capture(id + "_appraisal")
		for action in ["observe", "base", "light", "inspect", "crosscheck", "magnet", "scratch", "inscription"]:
			for entry in _session.counter_model().appraisal.buttons:
				if entry.command == "appraise" and entry.detail == action and entry.enabled:
					await _click(entry.label); break
		_check(not visit.item.revealed_clue_ids.is_empty(), "real evidence actions remain available " + id)
		var expected := ["front", "back", "sound", "foot_wear"] if id == "item_blue_bowl" and variant == "sound" else ["front", "back", "repaired", "seam", "foot_wear"] if id == "item_blue_bowl" else ["front", "back", "seam"] if id == "item_silver_hairpin" else ["front", "back", "detail_" + {"sound":"sound", "flawed":"flaw", "mended":"condition_mended"}[variant]]
		_check(panel._images.map(func(row: Dictionary) -> String: return row.id) == expected, "exact earned pages " + id + "/" + variant)
		for index in panel._images.size():
			var row: Dictionary = panel._images[index]
			await _click_button(panel._views.get_child(index))
			_check(panel._image.texture != null and panel._image.texture.resource_path.ends_with(".png"), "painted visible page " + row.id)
			_check(panel._image.texture.resource_path == row.path, "actual button selects correct page")
			await _frames()
			_check((panel._column.get_parent() as ScrollContainer).scroll_vertical == 0, "new study view stays visible")
			await _capture(id + "_" + variant + "_" + row.id)
			await _comparison(panel._image, id + "_" + variant + "_" + row.id)
		if "review" in OS.get_cmdline_user_args(): return
		var codec := SaveCodec.new()
		var state_data := codec.encode(_session._day.state, _session.content_version)
		var restored := codec.decode(state_data, _session.definition, _session.content_version, _session._counter.catalog, true)
		_check(restored != null, "replay save validation " + id + ": " + codec.error_message)
		if restored != null:
			_session._day.state = restored; _session.restored.emit(); _session.changed.emit(); await _frames()
			_check(sprite.texture.resource_path == CounterItemArt.front_path(asset), "restore retains art " + id)
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
		_main.queue_free(); await process_frame
	print("ITEM STUDIES UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := "res://.godot/qa/item-studies/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_check(root.get_texture().get_image().save_png(folder + _capture_prefix + "_" + label + ".png") == OK, "window capture " + label)

# Capture the original raster and the actual rendered study widget together,
# at equal size. This tests the real shader/crop rather than a recreated UI.
func _comparison(picture: TextureRect, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var screenshot := ImageTexture.create_from_image(root.get_texture().get_image())
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("292923"); bg.size = Vector2(root.size); layer.add_child(bg)
	var pair := HBoxContainer.new(); pair.position = Vector2(40,40); pair.size = Vector2(root.size) - Vector2(80,80); layer.add_child(pair)
	for original in [true, false]:
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pair.add_child(col)
		var caption := Label.new(); caption.text = ("SOURCE / " if original else "IN GAME / ") + label; col.add_child(caption)
		var im := TextureRect.new(); im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; im.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(im)
		if original:
			im.texture = picture.texture
			im.material = CounterVisualCatalog.study_material(im.texture) if im.texture.resource_path.ends_with("bowl_back.png") else null
		else:
			var crop := AtlasTexture.new(); crop.atlas = screenshot; crop.region = picture.get_global_rect(); im.texture = crop
	await _frames(); await _capture(label + "_comparison")
	layer.queue_free(); await _frames()
