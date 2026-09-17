extends "res://tests/aqi_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("AQI V24 UI TIMEOUT"); quit(1))
	_capture_prefix = "aqi_v24_1600" if "wide" in OS.get_cmdline_user_args() else "aqi_v24_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.title = "AQI v24 acceptance " + str(root.size)
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/aqi_investigation_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v24/ui.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_check(_session != null, "default catalog loaded")
	if _session == null: quit(1); return
	_session._save.library.path = "res://.godot/qa/v24/ui-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	driver.check = _check; driver.catalog = _session._counter.catalog
	counter_story = _main.get_node("CounterScreen")._counter_view.story
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 24 and _session.definition.total_nights == 10, "default v24 ten nights")
	await restore_stage("aq-room-2")
	var room: PrivateRoomView = _main.get_node("CounterScreen")._room
	await _click_button(room.get_node("RoomWardrobe"))
	_check(room._illustration.visible and "aq_coat_seen" in _session.read_state().narrative_flags, "coat discovery")
	await key(KEY_ESCAPE)
	_check(not room._observation.visible and root.gui_get_focus_owner() == room.get_node("RoomWardrobe"), "wardrobe Esc focus")
	await restore_stage("aq-room-5")
	await _click_button(room.get_node("RoomDesk"))
	_check(room._keepsakes.visible, "current keepsakes desk retained")
	await _click_button(room._keepsakes.letter_buttons[0])
	var paper: Button = room._keepsakes.contents.get_node("RoomPaper")
	_check(paper.visible, "paper inside Gu letter")
	await _click_button(paper)
	_check(room._illustration.visible and not room._keepsakes.visible and "aq_paper_seen" in _session.read_state().narrative_flags, "paper saved from new letter panel")
	await _capture("paper")
	await key(KEY_ESCAPE)
	await restore_stage("aq-example-aq_arrival")
	var counter: CounterView = _main.get_node("CounterScreen")._counter_view
	_check(counter_story.visible and counter._portrait.visible and counter._story_contact_shadow.visible, "Aqi at counter with complete hands and shadow")
	_check(not _main.get_node("CounterScreen/NarrativeScene").visible and not room.visible, "no separate story page")
	await _capture("arrival")
	await key(KEY_ESCAPE)
	_check(not counter_story.visible and counter._portrait.visible, "collapse leaves character")
	counter._customer_hotspot.release_focus()
	await _frames()
	await _capture("portrait")
	if "hold" in OS.get_cmdline_user_args():
		root.title = "AQI v24 acceptance"
		await create_timer(55).timeout
	await _click_button(counter._customer_hotspot)
	await _click_button(_main.get_node("CounterScreen/MenuButton"))
	_check(_main.get_node("CounterScreen")._session_menu.visible, "menu above story")
	await key(KEY_ESCAPE)
	await _click_button(counter._customer_hotspot)
	await narrative_choice("name")
	_check(_session.read_state().pending_event_id == "aq_name", "name route")
	await narrative_choice()
	await narrative_choice()
	await _capture("repaired")
	await narrative_choice("paper")
	await narrative_choice()
	await narrative_choice()
	await narrative_choice()
	await narrative_choice()
	await narrative_choice()
	_check(_session.read_state().pending_event_id.is_empty(), "chapter completes")
	await _click("回房")
	_check(room.visible and _session.read_state().phase == "private_room", "room navigation")
	await _capture("room")
	var current := _session._counter.catalog
	var old := JsonContentProvider.new("res://data/mirror_investigation_manifest.json").load_catalog().catalog
	var old_run := old.get_definition("runs", old.default_run_id) as RunDefinition
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/ending.json"))
	var old_state := SaveCodec.new().decode(raw, old_run, 23, old)
	_check(old_state != null, "v23 checkpoint accepted")
	_check(_session._save.library.adopt({"state": old_state, "run": old_run, "catalog": old}, _session), "old catalog adopted")
	_check(_session.content_version == 23 and _session.room_observation_model("aq_paper").is_empty(), "v23 remains frozen")
	_main._leave("title")
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 24 and _session._counter.catalog == current, "return title new game restores v24")
	print("AQI V24 UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func restore_stage(stage: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v24/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 24, _session._counter.catalog, true)
	_check(state != null, "stage restore " + stage + ": " + codec.error_message)
	if state == null: return
	_check(_session._save.library.adopt({"state": state, "run": _session.definition, "catalog": _session._counter.catalog}, _session), "adopt replayed checkpoint")
	await _frames()
