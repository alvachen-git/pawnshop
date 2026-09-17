extends "res://tests/integrated_ui_smoke.gd"

const OUTPUT := "res://artifacts/ordinary-customers-20260915/standees/"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("ORDINARY PORTRAITS TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/ordinary_portraits_%d.json" % Time.get_ticks_usec()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "production scene loads")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/ordinary_portraits_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	driver.check = _check
	driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._close_drawer()
	var view := screen.get_node("CounterView") as CounterView
	var dialogue := screen.get_node("%DialoguePanel") as DialoguePanel
	_check(view._portrait.texture.resource_path == CounterVisualCatalog.NEIGHBOR_PORTRAIT, "opening neighbor retains her identity")
	var before := _session.read_state()
	var opening := _session.counter_model().duplicate(true)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/goods_expertise/customers.json")).records
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _frames()
		for row in rows:
			# Presentation fixture: production scene and renderer, isolated from the live visit.
			var model := opening.duplicate(true)
			model.visual.customer_id = row.id
			model.visual.person_id = "ordinary/review/" + row.id
			model.visual.portrait_asset = row.portrait_asset_id
			model.visual.customer_name = row.counter_terms.display_name
			model.visual.introduction = row.counter_terms.introduction
			model.visual.speech = []
			model.visual.intent = ""
			model.dialogue.visual = model.visual.duplicate(true)
			view.render(model)
			dialogue.render(model.dialogue)
			await _frames()
			_check(CounterVisualCatalog.is_ordinary_portrait(view._portrait.texture), "%s uses ordinary art" % row.id)
			_check(dialogue._portrait.texture == view._portrait.texture, "%s dialogue and counter share identity" % row.id)
			_check(not dialogue._portrait.material.get_shader_parameter("hand_contact_shadow"), "raised hands do not cast a table shadow")
			_check(Rect2(Vector2.ZERO, view.size).encloses(view._portrait.get_rect()), "portrait stays inside scene at %d" % dimensions.x)
			_check(view._portrait.size.x >= view._portrait.size.y, "square portrait fits without letterbox above or below")
			await _shot("%d_%s" % [dimensions.x, CounterVisualCatalog.ORDINARY_CUSTOMERS[row.id]])
		# Material tint belongs to the same ordinary sprite in all atmosphere states.
		for mode in 3:
			view.set_atmosphere(mode, true, false, false, false)
			await _shot("%d_atmosphere_%d" % [dimensions.x, mode])
		view.set_atmosphere(0, false, false, false, false)
	for special_id in ["mirror_husband", "mirror_medicine", "ghost_closed_bundle", "ghost_swap_guest"]:
		var special := CounterVisualCatalog.portrait("asset.customer_hawker", special_id)
		_check(CounterVisualCatalog.is_special_portrait(special), "special identity stays distinct from ordinary templates: " + special_id)
	for familiar in ["bookkeeper", "seamstress"]:
		var old := CounterVisualCatalog.portrait("asset.customer_" + familiar, "customer_" + familiar, "familiar/" + familiar)
		_check(CounterVisualCatalog.is_special_portrait(old), "familiar retains separate appearance: " + familiar)
	view.render(opening)
	_check(_session.read_state() == before, "portrait review does not change gameplay or saves")
	await _shot("1600_opening_preserved")
	# Real departure still clears the portrait, including its material.
	var visit := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "real trade still completes")
	await _frames()
	_check(not view._portrait.visible, "departure removes portrait")
	print("ORDINARY PORTRAITS: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _shot(label: String) -> void:
	root.gui_release_focus()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK, "rendered screenshot: " + label)
