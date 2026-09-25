extends "res://tests/ui_smoke.gd"

func restore_fixture(name: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/lu-v44/" + name + ".json"))
	var codec := SaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var state := codec.decode(payload, _session.definition, 44, _session._counter.catalog, true)
	_check(state != null, "fixture loads " + name + " " + codec.error_message)
	if state == null: quit(1); return
	_session._day.state = state
	_session._save = GhostReplayStore.new()
	_session.restored.emit(); _session.changed.emit()
	await _frames()

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: quit(1))
	_main = load("res://scenes/start_lu_trade_v44.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var view := screen._counter_view
	var music := _main.get_node("ShopBgmPlayer") as ShopBgmPlayer
	var dialogue := screen.first_debt_conversation
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "lu_v44_%d" % dimensions.x
		await restore_fixture("first-night")
		screen._close_drawer(); await _frames()
		_check(not screen._market_notice.visible, "first-night letter absent")
		_check(not music.music_enabled and not music.playing, "background music remains off during business")
		await _capture("01_first_night")
		await restore_fixture("speech-0")
		screen._close_drawer(); await _frames()
		_check(view._portrait.texture.resource_path == CounterVisualCatalog.LU_ELDERLY_PORTRAIT, "elderly Lu on actual counter")
		_check(view._portrait.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "real transparent portrait")
		_check(not view._item_hotspot.visible, "visit has no merchandise")
		await _capture("02_arrival")
		_check(dialogue.visible, "arrival opens existing RPG dialogue")
		_check(not screen.get_node("%CloseDrawerButton").is_visible_in_tree(), "story never opens functional drawer")
		_check(dialogue._speaker.text == "柜前", "arrival narration has its own speaker")
		var before := _session.read_state()
		dialogue.collapse(); await _frames()
		await _click_button(view.get_hotspot(&"customer")); await _click("交谈")
		_check(dialogue.visible and _session.read_state() == before, "reopen story without changing game state")
		await _capture("03_dialogue")
		for step in 3:
			var model := _session.counter_model()
			_check(not screen._market_notice.visible, "letter remains hidden during introduction")
			before = _session.read_state()
			for page_guard in 12:
				_check(dialogue._text.get_content_height() <= dialogue._text.size.y + 1, "RPG page fits without scrolling")
				if dialogue._page == dialogue._pages.size() - 1: break
				_check(dialogue._choices.get_child_count() == 0, "choices wait for final page")
				await create_timer(0.20).timeout
				await _click_button(dialogue._next)
			_check(_session.read_state() == before, "reading pages does not advance time or story")
			_check(dialogue._speaker.text == "陆掌眼", "quoted dialogue credits Lu including continued pages")
			_check(dialogue._choices.get_child_count() == 1, "RPG response available")
			_check(not screen.get_node("%CloseDrawerButton").is_visible_in_tree(), "all story steps use RPG layout")
			await _capture("03_choice_%d" % step)
			var label: String = model.case_dialogue.buttons[0].label
			await _click(label)
			_check(dialogue.visible and dialogue._result, "response stays in RPG dialogue")
			_check(view._portrait.texture.resource_path == CounterVisualCatalog.LU_ELDERLY_PORTRAIT, "portrait retained while reply is read")
			for reply_guard in 12:
				if not dialogue._result: break
				await create_timer(0.20).timeout
				await _click_button(dialogue._next)
			if step < 2: await _capture("04_speech_%d" % (step + 1))
		_check(not dialogue.visible and not view.conversation_held, "farewell closes dialogue and releases counter")
		_check(LuIntroduction.unlocked(_session._day.state, _session.definition), "mouse dialogue unlocks letters")
		_check(_session._day.state.current_night_index == 2 and _session._day.state.game_minutes == 0, "pre-opening talk takes no time")
		await _frames()
		_check(screen._market_notice.visible, "first letter available immediately before opening")
		await _click_button(screen._market_notice)
		_check(screen.lu_sale.visible and screen.lu_sale._buyer.id == "buyer_lu", "first letter opens dedicated Lu tray")
		await _capture("05_pre_open_letter")
		await _click_button(screen.lu_sale._close)
		_check(_session.execute("open_shop").ok, "open after farewell")
		screen._close_drawer(); await _frames()
		_check(screen._market_notice.visible, "letter visible after farewell and opening")
		_check(not music.playing, "music still off after opening")
		await _capture("05_letters_unlocked")
		await _click_button(screen._market_notice)
		_check(screen.lu_sale.visible, "letter opens actual stock and buyer tray")
		await _capture("06_letter_open")
		await _click_button(screen.lu_sale._close)
	_check(CounterVisualCatalog.portrait("fd.lu", "fd_lu").resource_path == CounterVisualCatalog.LU_PORTRAIT, "v42 original portrait preserved")
	print("LU INTRODUCTION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
