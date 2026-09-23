extends "res://tests/dragon_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("LU ART TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_dragon_search_manifest.json"; aqi_version = 31; aqi_fixture_dir = "res://.godot/qa/v31/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size; root.title = "陆掌眼与龙凤镯 · 美术检查"; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate(); _main.get_node("Bootstrap").save_path = "res://.godot/qa/v31/art-unused.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v31/art-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	_session.definition._initial_cash = 2000; _session._save.library.register_catalog(aqi_manifest, _session._counter.catalog)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view; var dialogue := screen.first_debt_conversation
	for stage in ["seller", "lu"]:
		await restore_stage(stage); screen._close_drawer(); await _frames()
		var before := _session.read_state()
		var sprite := view._item_image
		_check(sprite.texture.resource_path.ends_with("/phoenix.png" if stage == "seller" else "/dragon.png"), "original item identity " + stage)
		_check(sprite.size.x <= root.size.x * .051 and sprite.size.y <= root.size.y * .091, "bangle wrist scale")
		_check(view._item_hotspot.size.x >= root.size.x * .10, "usable click target")
		_check(sprite.material != null and sprite.material.get_shader_parameter("contact_mode") == 1, "contact shadow")
		if stage == "lu":
			_check(view._portrait.texture.resource_path == CounterVisualCatalog.LU_PORTRAIT, "dedicated Lu portrait")
			_check(view._portrait.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "transparent portrait")
			_check(CounterVisualCatalog.portrait("asset.customer_bookkeeper", "customer_bookkeeper").resource_path != CounterVisualCatalog.LU_PORTRAIT, "ordinary bookkeeper unchanged")
			# Same state/viewport before-after for visual comparison, only temporary draw properties.
			var art := view._portrait.texture
			var material := view._portrait.material
			view._portrait.texture = load("res://assets/first_debt/lu_zhangyan.png") if "stocky" in OS.get_cmdline_user_args() else CounterVisualCatalog.portrait("asset.customer_bookkeeper", "customer_bookkeeper")
			var hem := 445.0 / 941.0 / 0.9
			view._bounds(view._portrait, .3175, hem - .50, .6825, hem)
			view._portrait.material = CounterVisualCatalog.portrait_material(view._portrait.texture)
			if "stocky" not in OS.get_cmdline_user_args():
				view._bounds(sprite, .425, .62, .595, .81); sprite.material = null
			await shot("before")
			view._portrait.texture = art; view._portrait.material = material
			_session.changed.emit(); await _frames()
		await shot(stage + "-counter")
		_check(before == _session.read_state(), "visual changes free and no history")
		if stage == "seller":
			await _click_button(view._item_hotspot); await _click("鉴定")
			var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
			_check(panel._image.texture == sprite.texture, "appraisal original source retained")
			_check(panel._image.size.x > sprite.size.x * 2, "appraisal remains large enough")
			_check(before == _session.read_state(), "view does not reveal evidence")
			await shot("phoenix-appraisal"); await key(KEY_ESCAPE)
		else:
			await _click_button(view._item_hotspot); await _click("验看与谈价")
			_check(dialogue.visible, "small bangle still opens trading dialogue")
			if not dialogue.visible: quit(1); return
			while dialogue._next.visible and dialogue._page < dialogue._pages.size() - 1: await _click_button(dialogue._next)
			await _click("验看龙镯，问问价钱")
			while dialogue._next.visible: await _click_button(dialogue._next)
			_check(DragonSearch.quoted(_session._day.state), "quote commits normally")
			await shot("quote")
			await _click("今天先缓缓")
			_check(view._portrait.texture.resource_path == CounterVisualCatalog.LU_PORTRAIT and dialogue.visible, "new portrait held through reply")
			await shot("reply")
			while dialogue.visible and dialogue._next.visible: await _click_button(dialogue._next)
			_check(not view._active_id.ends_with("/lu"), "Lu departs normally")
			await shot("departed")
	# Render-only lighting check; no game clock or save mutation.
	await restore_stage("lu"); screen._close_drawer(); await _frames()
	view.set_night_lighting(2); view.get_node("Room").night_band = 2; view.get_node("Room").queue_redraw()
	await shot("night")
	print("LU BANGLE ART %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(2, 2); root.push_input(motion, true)
	await create_timer(.35).timeout; RenderingServer.force_draw()
	var directory := "res://docs/qa/lu-stocky-v31/" if "stocky" in OS.get_cmdline_user_args() else "res://docs/qa/lu-bangle-art-v31/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
