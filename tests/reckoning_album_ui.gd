extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("OLD SHOP UI TIMEOUT"); quit(1))
	aqi_manifest = "res://data/first_debt_reckoning_manifest.json"
	aqi_version = 29
	aqi_fixture_dir = "res://.godot/qa/v29/"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.always_on_top = true
	root.title = "旧当铺 · 册页验收"
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/first_debt_reckoning_manifest.json"
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v29/album-unused.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v29/album-library-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var album := screen.old_shop
	await restore_stage("seller")
	var before := _session.read_state()
	await _click("账本")
	await _click("旧当铺")
	_check(album.visible and not screen.get_node("Drawer").visible, "dedicated album from ledger")
	_check(before == _session.read_state(), "open album does not observe or advance")
	_check(not _has_doc("fd_receipt") and not _has_doc("fd_family"), "unseen receipt and family absent")
	_check(_has_doc("fd_ticket"), "retained unread ticket visible")
	await shot("ticket-only")
	await _click("旧凭据")
	await _click("铺中旧物")
	await _click("旧当票")
	_check(before == _session.read_state(), "switch categories is read-only")
	_check(screen._bell_blocked(), "album blocks bell")
	for i in 18:
		await key(KEY_TAB)
		_check(album.is_ancestor_of(root.gui_get_focus_owner()), "keyboard focus stays in album")
	_session._save.library.fail_write = true
	await _click_button(album._content.get_node("DocumentHit"))
	_check(before == _session.read_state() and album.mode == "album", "failed first read rolls back without showing transcript")
	_check("重试" in album._message.text, "write error visible and retryable")
	_session._save.library.fail_write = false
	await _click_button(album._content.get_node("DocumentHit"))
	_check(FirstDebt.flag(_session._day.state, "fd_ticket_read"), "clicking document records first reading")
	_check(_session.read_state().game_minutes == before.game_minutes, "reading costs zero minutes")
	var saved := _session._save.library.read_entry("auto/first_debt_reckoning")
	_check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), _session.read_state()), "first read persisted and fully replayed")
	await shot("ticket-detail")
	await _click("展开原件")
	_check(album.mode == "image", "original image can be enlarged")
	await shot("original")
	var original_scroll := album._content.get_child(1) as ScrollContainer
	_check(original_scroll != null, "original has scroll access")
	if original_scroll != null:
		await wheel(original_scroll.get_global_rect().get_center(), 8)
		_check(original_scroll.scroll_vertical > 0, "mouse wheel reveals lower ticket")
		await shot("original-clue")
	await _click("返回册页")
	_check(album.mode == "album", "mouse returns from original straight to album")
	before = _session.read_state()
	await key(KEY_ENTER)
	_check(album.mode == "detail" and before == _session.read_state(), "keyboard rereading free without duplicate history")
	await _click("展开原件")
	await _click_button(album._close)
	_check(album.mode == "album", "top return button also returns directly to album")
	await key(KEY_ENTER)
	await _click("展开原件")
	await key(KEY_ESCAPE)
	_check(album.mode == "album", "Esc from original also returns directly to album")
	_check(before == _session.read_state(), "all return paths leave gameplay unchanged")
	await key(KEY_ESCAPE)
	_check(not album.visible and root.gui_get_focus_owner() == screen._counter_view.get_hotspot(&"ledger"), "close restores counter focus")
	await restore_stage("before-fd_settle")
	before = _session.read_state()
	await _click_button(screen.get_node("MenuButton"))
	await _click("旧当铺")
	_check(album.visible, "menu entry works")
	await shot("album")
	_check(before == _session.read_state(), "album browsing does not add knowledge or advance")
	for label in album.find_children("*", "Label", true, false):
		_check(label.text not in ["随票夹存", "同册收存"], "no duplicate document grouping")
	for button in album.find_children("*", "Button", true, false):
		_check(button.text not in ["放大细看", "并排查看"], "no redundant footer actions")
	await _click("旧凭据")
	await shot("receipts")
	await _click("翻查与托话")
	await shot("actions")
	var spending := _find_any_button(album, "翻看背页")
	if spending != null:
		await _click_button(spending)
		_check(FirstDebt.flag(_session._day.state, "fd_spending_read"), "back-page observation remains reachable")
		before = _session.read_state()
		await key(KEY_ESCAPE)
		await _click("翻查与托话")
	await key(KEY_ESCAPE)
	await _click("铺中旧物")
	await shot("objects")
	for button in album.find_children("*", "Button", true, false):
		if button.is_visible_in_tree(): _check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "visible option within window " + button.text)
	await key(KEY_ESCAPE)
	_check(before == _session.read_state(), "album navigation leaves entire state intact")
	await restore_stage("after-fd_settle")
	await _click("账本"); await _click("旧当铺")
	await _click("旧凭据"); await _click("翻查与托话")
	await _click("翻看背页")
	await key(KEY_ESCAPE)
	await _click("翻查与托话")
	await _click("翻看驻军往来的夹页")
	await shot("protection-detail")
	await key(KEY_ESCAPE)
	await _click("旧当票")
	for step in 4:
		if album.selected == "fd_customer_ticket": break
		await _click("下一档")
	_check(album.selected == "fd_customer_ticket", "customer original has separate ticket file")
	await _click_button(album._content.get_node("DocumentHit")); await shot("customer-ticket-detail")
	await key(KEY_ESCAPE)
	await _click("铺中旧物")
	for step in 5:
		if album.selected == "ledger": break
		await _click("下一档")
	_check(album.selected == "ledger", "existing Yin ledger reachable")
	before = _session.read_state()
	await _click_button(album._content.get_node("DocumentHit"))
	_check(FirstDebt.flag(_session._day.state, "fd_yin_link_read") and not FirstDebt.flag(_session._day.state, "fd_yin_echo_seen"), "first find correspondence")
	await shot("yin-link")
	await key(KEY_ESCAPE)
	_session._save.library.fail_write = true
	var ink_before := _session.read_state()
	await _click_button(album._content.get_node("DocumentHit"))
	_check(_session.read_state() == ink_before and "重试" in album._message.text, "failed echo shows retry and rolls back")
	_session._save.library.fail_write = false
	await _click_button(album._content.get_node("DocumentHit"))
	_check(FirstDebt.flag(_session._day.state, "fd_yin_echo_seen"), "visible first echo")
	_check(_session.read_state().cash == before.cash and _session.read_state().game_minutes == before.game_minutes, "ledger reveal costs no cash or time")
	await shot("yin-clear")
	await key(KEY_ESCAPE)
	before = _session.read_state()
	await _click_button(album._content.get_node("DocumentHit"))
	_check(before == _session.read_state(), "echo review never repeats event")
	print("OLD SHOP UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _has_doc(id: String) -> bool:
	return _session.old_shop_model().documents.any(func(d: Dictionary) -> bool: return d.id == id)

func shot(stage: String) -> void:
	await create_timer(0.2).timeout
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(("res://docs/qa/first-debt-v29/") + ("%d-%s.png" % [root.size.x, stage])) == OK, "capture " + stage)

func wheel(point: Vector2, steps: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for i in steps:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.position = point
			event.pressed = pressed
			root.push_input(event, true)
		await _frames()
