extends "res://tests/integrated_ui_smoke.gd"

var counter_story: CounterStoryView

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("AQI UI TIMEOUT"); quit(1))
	_capture_prefix = "aqi_hands_1600" if "wide" in OS.get_cmdline_user_args() else "aqi_hands_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/aqi_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/aqi/ui.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "default scene catalog loaded")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/aqi/ui_library_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	counter_story = _main.get_node("CounterScreen")._counter_view.story
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 22 and _session.definition.id == "aqi_seven", "normal title new game v22")
	await restore_stage("paper-2-room")
	var room: PrivateRoomView = _main.get_node("CounterScreen")._room
	await _click_button(room.get_node("RoomWardrobe"))
	_check(room._illustration.visible and "aq_coat_seen" in _session.read_state().narrative_flags, "wardrobe first observation saves discovery")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(room._close_observation.get_global_rect()), "coat close button fits window")
	await _capture("coat")
	await key(KEY_ESCAPE)
	_check(not room._observation.visible and root.gui_get_focus_owner() == room.get_node("RoomWardrobe"), "Esc observation returns wardrobe focus")
	await restore_stage("paper-5-room")
	await _click_button(room.get_node("RoomDesk"))
	_check(room._paper_button.visible, "paper offered inside old letter")
	await _click_button(room._paper_button)
	_check(room._illustration.visible and "aq_paper_seen" in _session.read_state().narrative_flags, "paper discovery visible and saved")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(room._close_observation.get_global_rect()), "paper close button fits window")
	await _capture("paper")
	await _click_button(room._close_observation)
	await restore_stage("shop_retreat-7-seal")
	_check(not counter_story.visible and _main.get_node("CounterScreen")._flow.get_active_panel_id() == &"risk", "shop crisis shown before queued Aqi")
	await _capture("shop_crisis")
	await _click("低头退开，将红布覆上")
	_check(counter_story.visible and _session.read_state().pending_event_id == "aq_arrival", "risk response reveals waiting Aqi")
	await restore_stage("paper-7-seal")
	_check(counter_story.visible and not room.visible, "Aqi at actual counter after seal")
	_check(not narrative.visible, "Aqi never opens separate narrative page")
	var counter: CounterView = _main.get_node("CounterScreen")._counter_view
	_check(counter._portrait.visible and counter._item_image.visible and counter._active_id.is_empty(), "Aqi and toy use ordinary stage without customer visit")
	_check(counter._portrait.anchor_top > 0.15 and is_equal_approx(counter._item_image.anchor_top, 0.62), "child sits lower while pinwheel remains on counter")
	_check(counter._story_contact_shadow.visible and counter._customer_hotspot.anchor_bottom >= 0.60, "complete resting hands have contact shadow and remain clickable")
	await _capture("arrival")
	var history: int = _session.read_state().event_history.size()
	await key(KEY_ESCAPE)
	_check(not counter_story.visible and counter._portrait.visible, "Esc collapses dialogue and leaves Aqi at counter")
	await _capture("counter_collapsed")
	counter._customer_hotspot.release_focus()
	await _frames()
	await _capture("portrait")
	await _click_button(counter._customer_hotspot)
	_check(counter_story.visible and not counter._customer_context.visible, "click Aqi resumes story without trade actions")
	await _click_button(_main.get_node("CounterScreen").get_node("MenuButton"))
	_check(_main.get_node("CounterScreen")._session_menu.visible and not counter_story.visible, "ordinary menu opens above story")
	await key(KEY_ESCAPE)
	_check(not _main.get_node("CounterScreen")._session_menu.visible and history == _session.read_state().event_history.size(), "Esc closes menu without advancing")
	await _click_button(counter.get_hotspot(&"ledger"))
	_check(_main.get_node("CounterScreen").get_node("Drawer").visible, "ledger remains available during story")
	await _click_button(counter._item_hotspot)
	_check(not _main.get_node("CounterScreen").get_node("Drawer").visible, "resuming story closes ordinary drawer")
	_check(counter_story.visible, "click pinwheel resumes same dialogue")
	counter_story._choices.get_child(1).grab_focus()
	await key(KEY_ENTER)
	_check(_session.read_state().pending_event_id == "aq_name", "keyboard ask name")
	await _click_button(counter_story._close)
	_check(not counter_story.visible and root.gui_get_focus_owner() == counter._customer_hotspot, "collapse button restores customer focus")
	await _click_button(counter._customer_hotspot)
	await narrative_choice("help")
	await _capture("bent")
	await narrative_choice("repair")
	await _capture("fixed")
	await narrative_choice("paper")
	await _capture("paper_reply")
	await narrative_choice("bye")
	await narrative_choice("watch")
	_check(_session.read_state().pending_event_id == "aq_ledger", "Aqi leaves before ledger")
	_check(not counter._portrait.visible and not counter._story_contact_shadow.visible, "departed Aqi leaves no portrait or contact shadow")
	await narrative_choice("open")
	await _capture("ledger")
	await narrative_choice("look")
	await _capture("floorplan")
	await narrative_choice("put_away")
	_check(not counter_story.visible and _session.can_execute("enter_room"), "completed story unblocks upstairs")
	await _click("回房")
	_check(room.visible and root.gui_get_focus_owner() == room.get_node("RoomBed"), "return room bed focus")
	await _click_button(room.get_node("RoomDesk"))
	await _click_button(room._plan_button)
	_check(room._illustration.visible, "floorplan reread in room")
	await _capture("reread")
	await _click_button(room._close_observation)
	await _click_button(room.get_node("RoomBed"))
	await _click_button(room._confirm.get_ok_button())
	await _click_button(room._close_observation)
	_check(_session.read_state().current_night_index == 7 and _session.read_state().phase == "day_summary", "last sleep retains final summary no eighth night")
	await _capture("ending")
	await restore_stage("decline-7-seal")
	await narrative_choice("name"); await narrative_choice("decline")
	await _capture("decline")
	for i in 5:
		if not counter_story.visible: break
		await narrative_choice("skip" if _session.read_state().pending_event_id == "aq_drawer" else "")
	_check(_session.can_execute("enter_room") and "aq_helped" not in _session.read_state().narrative_flags, "decline route completes through real buttons")
	# Traverse the phase boundary through normal commands as well as restoring mid-story.
	await restore_stage("paper-6-room")
	for action in ["sleep", "finish_sleep", "continue_run"]: driver.action(_session, action)
	_check(_session.read_state().current_night_index == 7, "natural route reaches seventh opening")
	driver.open(_session)
	for step in 12:
		if not _session.counter_model().active_id.is_empty(): break
		driver.action(_session, "short_task")
	await _frames()
	_check(not counter.story_active and not counter._active_id.is_empty(), "ordinary customer remains ordinary before closing")
	_check(is_equal_approx(counter._portrait.anchor_top, 0.027) and is_equal_approx(counter._customer_hotspot.anchor_left, 0.325), "adult portrait and hotspot bounds restored after child scene")
	for action in ["close_shop", "wait_until_seal", "resolve_night"]: driver.action(_session, action)
	await _frames()
	_check(counter_story.visible and not narrative.visible and not _main.get_node("CounterScreen").get_node("Drawer").visible and _session.read_state().pending_event_id == "aq_arrival", "natural seal opens counter story after phase routing")
	var current := _session._counter.catalog
	var old := JsonContentProvider.new("res://data/night_market_manifest.json").load_catalog().catalog
	var old_run := old.get_definition("runs", "night_market") as RunDefinition
	var old_session := RunSession.new(old_run, 21, SaveManager.new("res://.godot/qa/aqi/old_ui.json"), old)
	var old_data := SaveCodec.new().encode(old_session._day.state, 21)
	var old_state := SaveCodec.new().decode(old_data, old_run, 21, old)
	_check(old_state != null, "decode representative v21 checkpoint")
	_check(_session._save.library.adopt({"state": old_state, "run": old_run, "catalog": old}, _session), "adopt old v21 through library")
	_check(_session.content_version == 21 and _session.room_observation_model("aq_paper").is_empty(), "old content stays old")
	_main._leave("title")
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 22 and _session._counter.catalog == current, "return title new game restores default v22")
	print("AQI UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func restore_stage(stage: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/aqi/process/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 22, _session._counter.catalog)
	_check(state != null, "stage restore " + stage + ": " + codec.error_message)
	if state == null: return
	_check(_session._save.library.adopt({"state": state, "run": _session.definition, "catalog": _session._counter.catalog}, _session), "adopt replayed checkpoint")
	await _frames()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.pressed = pressed
		root.push_input(event, true)
	await _frames()

func narrative_choice(id := "") -> void:
	await _frames()
	_check(counter_story._choices.get_child_count() <= 3, "at most three story options")
	for button in counter_story._choices.get_children():
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "story option fits window")
	_check(counter_story._text.get_v_scroll_bar().max_value <= counter_story._text.get_v_scroll_bar().page + 1, "short dialogue fits screen")
	var button: Button = counter_story._choices.get_child(0) if id.is_empty() else counter_story._choices.get_node("Choice_" + id)
	await _click_button(button)
	await _frames()
