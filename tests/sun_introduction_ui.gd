extends "res://tests/lu_introduction_ui.gd"

func _capture(label: String) -> void:
	# Let the existing 0.18-second arrival fade settle before visual review.
	await create_timer(0.25).timeout
	await super._capture(label)

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: quit(1))
	_main = load("res://scenes/lu_v44.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view
	var dialogue := screen.first_debt_conversation
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "sun_rpg_%d" % dimensions.x
		await restore_fixture("sun-arrival")
		_check(dialogue.visible and dialogue._speaker.text == "柜前", "Sun arrives in RPG narration")
		_check(root.gui_get_focus_owner() == dialogue._next, "arrival keeps keyboard focus in dialogue")
		_check(not screen.get_node("%Drawer").visible, "no business-style drawer")
		_check(view._portrait.texture.resource_path == CounterVisualCatalog.SUN_PORTRAIT, "dedicated Sun identity retained")
		_check(view._portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "portrait retains source aspect ratio")
		_check(not view._item_hotspot.visible, "Sun carries no trade item")
		var sun_size := view._portrait.size
		await _capture("01_arrival")
		var before := _session.read_state()
		dialogue.collapse(); await _frames()
		await _click_button(view.get_hotspot(&"customer")); await _click("交谈")
		_check(dialogue.visible and _session.read_state() == before, "close and reopen without advancing story")
		for step in 3:
			_check(int(_session._day.state.social.intro_step) == step, "correct authored step")
			before = _session.read_state()
			for guard in 15:
				_check(dialogue._text.get_content_height() <= dialogue._text.size.y + 1, "short page fits without scrolling")
				_check(not dialogue._text.text.contains("陈小满"), "no unrelated empty-result fallback")
				if dialogue._page == dialogue._pages.size() - 1: break
				_check(dialogue._choices.get_child_count() == 0, "reply waits until speech ends")
				await create_timer(0.20).timeout; await _click_button(dialogue._next)
			_check(before == _session.read_state(), "reading is free and does not unlock faction")
			_check(dialogue._speaker.text == "孙大元", "continued quotes identify Sun")
			_check(dialogue._choices.get_child_count() == 1, "authored RPG reply visible")
			_check(not screen.get_node("%Drawer").visible, "all dialogue remains in RPG view")
			await _capture("02_reply_%d" % step)
			await _click(MilitaryIntroduction.CHOICES[step])
			_check(int(_session._day.state.social.intro_step) == step + 1, "reply commits once")
			_check(dialogue.visible, "continuous conversation")
			if step < 2:
				_check(not dialogue._result and dialogue._speaker.text == "柜前", "empty response proceeds to next authored page")
		_check(dialogue._result and view._portrait.texture.resource_path == CounterVisualCatalog.SUN_PORTRAIT, "Sun retained until farewell is read")
		_check(root.gui_get_focus_owner() == dialogue._next, "farewell keeps keyboard focus in dialogue")
		await _capture("03_farewell")
		for guard in 12:
			if not dialogue._result: break
			await create_timer(0.20).timeout; await _click_button(dialogue._next)
		_check(dialogue.visible and LuIntroduction.active(_session._day.state), "Lu follows Sun within the same RPG flow")
		_check(view._portrait.texture.resource_path == CounterVisualCatalog.LU_ELDERLY_PORTRAIT, "correct next visitor after farewell")
		_check(view._portrait.size.is_equal_approx(sun_size), "Sun and Lu use matching source display scale")
		_check(_session._day.state.social.introduced and not LuIntroduction.unlocked(_session._day.state, _session.definition), "faction unlocked but Lu letters still locked")
		_check(_session._day.state.current_night_index == 2 and _session._day.state.game_minutes == 0, "arrival chain remains before opening without time cost")
		await _capture("04_lu_arrives")
		# Cold-load the two actual intermediate checkpoints and resume in the same layout.
		for step in [1, 2]:
			await restore_fixture("sun-speech-" + str(step))
			_check(dialogue.visible and dialogue._model.key.ends_with("/" + str(step)), "loaded checkpoint resumes correct RPG speech")
	print("SUN INTRODUCTION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
