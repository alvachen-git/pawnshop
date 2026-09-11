extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("LIGHTING TIMEOUT"); quit(1))
	_capture_prefix = "lighting_1600" if "wide" in OS.get_cmdline_user_args() else "lighting_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/lighting-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false; _session.definition._seed = 0
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	driver.open(_session); await receipts()
	var screen: CounterScreen = _main.get_node("CounterScreen")
	screen._close_drawer()
	var stage: CounterStage = screen.get_node("CounterView/Room")
	var original := _session._day.state.game_minutes
	# Lighting refresh must preserve the arrival/handoff animation alpha.
	var counter := screen._counter_view
	await create_timer(0.4).timeout
	counter._portrait.modulate.a = 0.35
	counter._item_image.modulate.a = 0.45
	counter.set_atmosphere(0, false, false, false, false)
	counter.set_night_lighting(3)
	_check(is_equal_approx(counter._portrait.modulate.a, 0.35) and is_equal_approx(counter._item_image.modulate.a, 0.45), "lighting preserves feedback fade")
	counter._portrait.modulate.a = 1.0
	counter._item_image.modulate.a = 1.0
	var images: Array[Image] = []
	for pair in [[175,0], [180,1], [355,1], [360,2], [475,2], [480,3]]:
		_session._day.state.game_minutes = pair[0]
		var before := SaveLibrary.fingerprint(_session._day.state)
		screen.atmosphere_presenter.refresh(); await _frames()
		_check(stage.night_band == pair[1], "21 / 00 / 02 boundary follows game clock")
		_check(before == SaveLibrary.fingerprint(_session._day.state), "lighting does not mutate progress")
		if pair[0] in [175,180,360,480]:
			await _capture(str(pair[0]))
			images.append(root.get_texture().get_image())
	for i in 3:
		_check(brightness(images[i], Rect2(.65,.025,.035,.09)) > brightness(images[i+1], Rect2(.65,.025,.035,.09)) * 1.35, "street visibly darkens")
		_check(brightness(images[i], Rect2(.03,.21,.10,.08)) > brightness(images[i+1], Rect2(.03,.21,.10,.08)) * 1.35, "shop shelves visibly darken")
	_check(brightness(images[1], Rect2(.739,.412,.014,.014)) > brightness(images[0], Rect2(.739,.412,.014,.014)) * 1.5, "desk bulb off before 21 and on after")
	_check(brightness(images[2], Rect2(.65,.63,.07,.10)) > brightness(images[2], Rect2(.65,.025,.035,.09)) * 4, "warm desk remains visible after midnight")
	_check(_main.find_child("AmbientMute", true, false) == null and _main.find_child("AmbientVolume", true, false) == null, "ambient controls removed")
	_check(not FileAccess.file_exists("res://ui/counter/night_ambient_audio.gd"), "ambient player removed")
	await _click("鉴定"); await _capture("appraisal")
	_check(screen.get_node("%Drawer").visible, "appraisal remains available in darkness")
	await _click("收起 · Esc")
	await _click("菜单"); await _capture("menu")
	_check(screen.get_node("%SessionMenu").get_global_rect().end.y < screen.get_node("%ShopStatusView").global_position.y, "menu fits above status")
	_session._day.state.game_minutes = original
	print("NIGHT LIGHTING UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func brightness(img: Image, rect: Rect2) -> float:
	var sum := 0.0
	var count := 0
	for y in range(int(rect.position.y * img.get_height()), int(rect.end.y * img.get_height()), 2):
		for x in range(int(rect.position.x * img.get_width()), int(rect.end.x * img.get_width()), 2):
			var c := img.get_pixel(x,y)
			sum += c.r * .2126 + c.g * .7152 + c.b * .0722; count += 1
	return sum / maxf(count, 1)
