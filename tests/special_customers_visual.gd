extends "res://tests/integrated_ui_smoke.gd"

const OUTPUT := "res://artifacts/special-customers-20260916/in-game/"
const PEOPLE := [
	["customer_bookkeeper", "familiar/bookkeeper", "asset.customer_bookkeeper", "xu_wenheng", "许文衡"],
	["customer_seamstress", "familiar/seamstress", "asset.customer_seamstress", "jiang_suyun", "姜素云"],
	["mirror_husband", "", "asset.customer_hawker", "mirror_husband", "丈夫"],
	["mirror_medicine", "", "asset.customer_hawker", "mirror_medicine", "药费客"],
	["ghost_closed_bundle", "", "asset.customer_hawker", "ghost_closed_bundle", "抱包的夜客"],
	["ghost_swap_guest", "", "asset.customer_hawker", "ghost_swap_guest", "提匣的夜客"],
]

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("SPECIAL PORTRAITS TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/special_portraits_%d.json" % Time.get_ticks_usec()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "production scene loads")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/special_portraits_library_%d.json" % Time.get_ticks_usec()
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
	var before := _session.read_state()
	var opening := _session.counter_model().duplicate(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _frames()
		for person in PEOPLE:
			# Isolated presentation fixture through the shipped scene and renderers.
			var model := opening.duplicate(true)
			model.visual.customer_id = person[0]
			model.visual.person_id = person[1]
			model.visual.portrait_asset = person[2]
			model.visual.customer_name = person[4]
			var definition := driver.catalog.get_definition("customers", person[0]) as CustomerDefinition
			model.visual.introduction = definition.terms.introduction
			model.visual.speech = []
			model.visual.intent = ""
			model.dialogue.visual = model.visual.duplicate(true)
			view.render(model)
			dialogue.render(model.dialogue)
			await _frames()
			var texture := view._portrait.texture
			_check(texture.resource_path == CounterVisualCatalog.SPECIAL_ROOT + person[3] + ".png", "correct named identity: " + person[3])
			_check(texture.get_size() == Vector2(1024, 1536), "approved source dimensions")
			_check(dialogue._portrait.texture == texture, "dialogue and counter share identity")
			_check(view._portrait.material.get_shader_parameter("chroma_key"), "magenta backing removed")
			_check(view._portrait.material.get_shader_parameter("clean_chroma_edges"), "hair and sleeves have clean edges")
			_check(not view._portrait.material.get_shader_parameter("hand_contact_shadow"), "raised hands do not cast false table shadow")
			_check(dialogue._portrait.material.get_shader_parameter("source_bottom") == 1.0, "counter crop does not leak into dialogue")
			_check(Rect2(Vector2.ZERO, view.size).encloses(view._portrait.get_rect()), "portrait in scene bounds")
			var cut: float = view._portrait.material.get_shader_parameter("source_bottom")
			_check(is_equal_approx((view._portrait.position.y + view._portrait.size.y * cut) / view.size.y, 445.0 / 941.0 / 0.9), "counter edge occludes lower body")
			_check(view._portrait.size.x / view._portrait.size.y >= 2.0 / 3.0, "source fits height without stretching")
			await _shot("%d_%s" % [dimensions.x, person[3]])
			screen._route_from_customer(&"dialogue")
			await _frames()
			dialogue.render(model.dialogue)
			await _shot("%d_%s_dialogue" % [dimensions.x, person[3]])
			screen._close_drawer()
		# The ticket panel keeps its functional body and the familiar face together.
		var ticket_model: Dictionary = opening.dialogue.duplicate(true)
		ticket_model.visual = opening.visual.duplicate(true)
		ticket_model.visual.customer_id = "customer_seamstress"
		ticket_model.visual.person_id = "familiar/seamstress"
		ticket_model.visual.customer_name = "姜素云"
		ticket_model.visual.attitude = "持票回访"
		ticket_model.visual.deadline = "验票办结"
		ticket_model.preserve_ticket_body = true
		ticket_model.body = "当票 001 · 银簪\n本金 25 银元 · 约定赎金 28 银元"
		ticket_model.buttons = []
		ticket_model.visual.introduction = ticket_model.body
		var ticket_counter := opening.duplicate(true)
		ticket_counter.visual = ticket_model.visual.duplicate(true)
		view.render(ticket_counter)
		screen._route_from_customer(&"dialogue")
		await _frames()
		dialogue.render(ticket_model)
		_check(dialogue._body.text == ticket_model.body, "portrait preserves ticket body")
		_check(dialogue._portrait.texture.resource_path.ends_with("jiang_suyun.png"), "return dialogue retains Jiang")
		await _shot("%d_ticket_dialogue" % dimensions.x)
		screen._close_drawer()
	for profession in ["bookkeeper", "seamstress"]:
		var ordinary := CounterVisualCatalog.portrait("asset.customer_" + profession, "customer_" + profession, "ordinary/review")
		_check(CounterVisualCatalog.is_ordinary_portrait(ordinary), "ordinary profession remains separate")
	_check(CounterVisualCatalog.portrait("asset.customer_hawker", "mirror_moving").resource_path.ends_with("hawker.svg"), "unrequested story people retain fallback")
	view.render(opening)
	_check(view._portrait.texture.resource_path == CounterVisualCatalog.NEIGHBOR_PORTRAIT, "neighbor preserved")
	_check(view._portrait.material.get_shader_parameter("source_bottom") == 1.0, "occlusion resets after special guest")
	_check(_session.read_state() == before, "presentation changes no gameplay or save state")
	var visit := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "normal trade still completes")
	await _frames()
	_check(not view._portrait.visible, "departure clears portrait")
	print("SPECIAL PORTRAITS: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _shot(label: String) -> void:
	root.gui_release_focus()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK, "rendered screenshot: " + label)
