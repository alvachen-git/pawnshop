extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("SMOKE TIMEOUT"); quit(1))
	_capture_prefix = "smoke_1600" if "wide" in OS.get_cmdline_user_args() else "smoke_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/smoke-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false; _session.definition._seed = 0
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	driver.open(_session); await receipts()
	var screen: CounterScreen = _main.get_node("CounterScreen")
	screen._close_drawer()
	_session._day.state.game_minutes = 360
	screen.atmosphere_presenter.refresh()
	var stage: CounterStage = screen.get_node("CounterView/Room")
	var before := SaveLibrary.fingerprint(_session._day.state)
	stage._smoke_material.set_shader_parameter("preview_time", 0.0)
	stage._smoke.hide(); await _frames()
	var background := root.get_texture().get_image()
	stage._smoke.show(); await _frames()
	var normal := root.get_texture().get_image()
	await _capture("normal")
	stage._smoke_material.set_shader_parameter("preview_time", 4.0)
	await _frames()
	var moving := root.get_texture().get_image()
	_check(smoke_region(normal).get_data() != smoke_region(moving).get_data(), "smoke slowly changes shape and density")
	stage.smoke_wrong = true
	await create_timer(1.5).timeout; await _frames()
	var wrong := root.get_texture().get_image()
	_check(centroid(wrong, background) > centroid(normal, background) + root.size.x * 0.004, "abnormal smoke drifts toward the counter")
	await _capture("wrong")
	stage.smoke_wrong = false
	await create_timer(1.5).timeout; await _frames()
	_check(stage._smoke_drift == 0.0, "normal upward flow restores")
	stage._smoke_material.set_shader_parameter("preview_time", -1.0)
	_check(stage._smoke.mouse_filter == Control.MOUSE_FILTER_IGNORE, "smoke cannot block mouse interaction")
	_check(before == SaveLibrary.fingerprint(_session._day.state), "animation and direction preview do not mutate gameplay")
	# A changing pixel alone is not sufficient: smoke must be visible at game size.
	stage._smoke_material.set_shader_parameter("preview_time", 0.0)
	for minute in [0, 180, 360, 480]:
		_session._day.state.game_minutes = minute
		screen.atmosphere_presenter.refresh()
		stage._smoke.hide(); await _frames()
		var bare := root.get_texture().get_image()
		stage._smoke.show(); await _frames()
		var visible := root.get_texture().get_image()
		var count := visible_smoke_pixels(visible, bare)
		print("SMOKE VISIBLE PIXELS at %d: %d" % [minute, count])
		_check(count >= int(150.0 * root.size.x * root.size.y / (1280.0 * 720.0)), "smoke has readable contrast in band %d" % minute)
		await _capture("visibility_%d" % minute)
	print("INCENSE SMOKE UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func smoke_region(img: Image) -> Image:
	return img.get_region(Rect2i(int(img.get_width() * 0.05), int(img.get_height() * 0.4), int(img.get_width() * 0.14), int(img.get_height() * 0.2)))

func visible_smoke_pixels(img: Image, background: Image) -> int:
	var count := 0
	for y in range(int(img.get_height() * 0.4), int(img.get_height() * 0.6)):
		for x in range(int(img.get_width() * 0.05), int(img.get_width() * 0.19)):
			var a := img.get_pixel(x, y)
			var b := background.get_pixel(x, y)
			var contrast := (a.r-b.r)*0.2126 + (a.g-b.g)*0.7152 + (a.b-b.b)*0.0722
			if contrast >= 0.06: count += 1
	return count

func centroid(img: Image, background: Image) -> float:
	var total := 0.0
	var moment := 0.0
	for y in range(int(img.get_height() * 0.4), int(img.get_height() * 0.6)):
		for x in range(int(img.get_width() * 0.05), int(img.get_width() * 0.19)):
			var weight := maxf(0.0, img.get_pixel(x,y).r - background.get_pixel(x,y).r)
			total += weight; moment += weight * x
	return moment / maxf(total, 0.0001)
