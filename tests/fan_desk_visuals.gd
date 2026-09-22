extends "res://tests/shop_appraisal_ui.gd"

func _run() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	_capture_prefix = "fan-desk-variants"
	_main = load("res://scenes/start_v27.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/fan_desk_visuals/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new()
	store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	for variant in ["sound", "mended", "flawed"]:
		install("fan-" + variant)
		await _frames()
		var item := CustomerManager.new().active(_session._day.state).item
		var view := FanAppraisalView.open(_main.get_node("CounterScreen"), _session, item.instance_id)
		await _frames()
		var before := _session.read_state()
		_check(view.fan.texture.resource_path.ends_with("fan-" + variant + ".png"), "visual belongs to current item " + variant)
		await desk_select(view.book, Vector2(.74,.69))
		await desk_select(view.fan, Vector2(.80,.355))
		await _click_button(_find_button(view, "放大"))
		await _capture(variant + "-inscription")
		_check(_session.read_state() == before, "looking never rewrites variant or records")
		await _click_button(_find_button(view, "收起放大"))
		await desk_select(view.book, Vector2(.72,.32))
		await desk_select(view.fan, Vector2(.38,.245))
		await _click_button(_find_button(view, "放大"))
		await _capture(variant + "-brush")
		await _click_button(_find_button(view, "收起放大"))
		await _click_button(view.close_button)
		await _frames()
	print("FAN DESK VARIANT VISUALS: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
