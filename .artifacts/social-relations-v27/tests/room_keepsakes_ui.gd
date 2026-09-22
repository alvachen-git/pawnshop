extends "res://tests/bedroom_art_ui_smoke.gd"

func _shot_directory() -> String:
	return "res://docs/qa/room-keepsakes/"

func _review_extra(room: PrivateRoomView) -> void:
	if _keep_open:
		print("KEEPSAKES PREVIEW READY: use the photograph and desk; isolated saves")
		return
	var panel := room._keepsakes
	var before := session.read_state()
	var library := session._save.library
	if library == null:
		library = SaveLibrary.new("user://tests/keepsakes-ui-%d.json" % Time.get_ticks_usec())
		session._save.library = library
		check(library.write_entry("auto/life_lamp_seven", session._day.state, session.definition, 22, session._counter.catalog), "initialize isolated native save library")
	check(library != null, "native game uses actual save library")
	var old_bytes := FileAccess.get_file_as_bytes(library.path)
	await click(room._desk)
	check(panel.visible and panel.page == "desk" and panel.letter_buttons.size() == 1, "desk opens only the received private letter")
	await shot("letters")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel.paper.get_global_rect()), "panel stays inside viewport")
	await click(panel.letter_buttons[0])
	check(panel.page == "letter" and panel.body.text == tr("opening.letter.permanent"), "read complete existing letter")
	await shot("letter_top")
	await _key(KEY_END)
	check(panel.scroll.scroll_vertical > 0, "long letter scrolls with keyboard")
	check(panel.paper.get_global_rect().encloses(panel.back.get_global_rect()), "back button stays visible outside scroll")
	await shot("letter_end")
	for i in 8:
		await _key(KEY_TAB)
		check(panel.is_ancestor_of(root.gui_get_focus_owner()), "Tab remains inside panel")
	await _key(KEY_ESCAPE)
	check(panel.page == "desk" and panel.letter_buttons[0].has_focus(), "Esc returns to letter list and original focus")
	await click(panel.letter_buttons[0])
	await click(panel.back)
	check(panel.page == "desk", "put letter back returns to list")
	await _key(KEY_ESCAPE)
	check(not panel.visible and room._desk.has_focus(), "close drawer returns focus to desk")
	check(before == session.read_state() and old_bytes == FileAccess.get_file_as_bytes(library.path), "repeated reading performs no state or disk writes")
	await click(room._photo)
	check(panel.page == "photo" and panel.primary.text == "收进抽屉", "photo provides store action")
	await shot("photo_on_desk")
	# Clicking the visible bed behind the full-window modal must not open sleep.
	await click(room._bed)
	check(panel.visible and (room._confirm == null or not room._confirm.visible) and session.read_state() == before, "modal blocks bed click through")
	library.fail_write = true
	await click(panel.primary)
	check(panel.visible and panel.error_label.visible and room._photo.visible, "failed save retains photo and displays retryable error")
	check(session.read_state() == before and old_bytes == FileAccess.get_file_as_bytes(library.path), "native failure rolls back journal and preserves disk")
	await shot("save_error")
	library.fail_write = false
	await click(panel.primary)
	check(not panel.visible and not room._photo.visible and room._desk.has_focus(), "successful store removes hotspot and focuses desk")
	check(not room._state_material.get_shader_parameter("photo_placed"), "photo artwork removed with hotspot")
	await _pointer(Vector2(width - 35, 100))
	await shot("photo_stored")
	await click(room._desk)
	check(panel.photo_button != null, "drawer retains access to stored photo")
	await click(panel.photo_button)
	check(panel.primary.text == "摆回桌上", "stored photo can be placed again")
	await _key(KEY_ESCAPE)
	check(panel.page == "desk" and panel.photo_button.has_focus(), "stored photo back restores drawer focus")
	await click(panel.photo_button)
	await shot("photo_in_drawer")
	await click(panel.primary)
	check(room._photo.visible and not panel.visible, "place photo updates art and closes panel")
	await click(room._desk)
	check(session.load_checkpoint().ok, "native current save loads")
	await frames()
	check(not panel.visible and room._photo.visible, "loading closes private panel and preserves position")
	await click(room._desk)
	session._save.library = null
	check(session._save.save_state(session._day.state, session.definition, 22), "standalone checkpoint saves")
	check(session.load_checkpoint().ok, "standalone checkpoint loads")
	await frames()
	check(not panel.visible, "standalone load also dismisses private panel")
	session._save.library = library
	var after := session.read_state()
	for key in before:
		if key not in ["room_photo_position", "action_journal", "run_token"]: check(after[key] == before[key], "room interaction does not change " + key)
	var live := room._model.duplicate(true)
	var no_letter := live.duplicate(true)
	no_letter.keepsakes.letters = []
	room.render(no_letter)
	await click(room._desk)
	check(panel.letter_buttons.is_empty() and not panel.body.text.contains("贤侄"), "unreceived letter has neither title nor body")
	await shot("empty_drawer")
	room.close_private_panels()
	room.render(live)
	await click(room._desk)
	var blocked := live.duplicate(true)
	blocked.keepsakes.available = false
	room.render(blocked)
	check(not panel.visible and room._desk.disabled and room._photo.disabled, "pending story disables and dismisses keepsakes")
	room.render(live)
	await _pointer(Vector2(width - 35, 100))
	print("KEEPSAKES NATIVE: %d assertions, %d failures" % [checks, failures])
