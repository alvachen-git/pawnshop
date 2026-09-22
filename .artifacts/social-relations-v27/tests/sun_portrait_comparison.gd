extends "res://tests/social_ui.gd"

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	_capture_prefix = "sun_proportion_reference"
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/portrait_comparison/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	install("introduction")
	await create_timer(.4).timeout
	var view: CounterView = _main.get_node("CounterScreen")._counter_view
	var model: Dictionary = _session.counter_model()
	await _capture("01_sun")
	# Render existing customer art at its production placement in the same scene.
	model.visual.portrait_asset = "asset.customer_citizen"
	model.visual.customer_id = "citizen"
	model.visual.customer_name = "普通客人（比例对照）"
	view.render(model); await _frames(); await _capture("02_citizen")
	model.visual.customer_id = "intro_neighbor"
	model.visual.customer_name = "街坊妇人（比例对照）"
	view.render(model); await _frames(); await _capture("03_neighbor")
	print("PORTRAIT COMPARISON: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)
