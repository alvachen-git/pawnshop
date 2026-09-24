extends "res://tests/recovery_ui.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("DETAIL UI TIMEOUT"); quit(1))
	aqi_manifest = recovery_manifest(); aqi_version = recovery_version()
	aqi_fixture_dir = "res://docs/qa/first-debt-v%d/fixtures/" % aqi_version
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size; root.title = "凤镯实物鉴定 · 验收"; root.always_on_top = true
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = aqi_manifest
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/v40/detail-unused.json"
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/v40/detail-%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false); await _frames(); await _click_button(_main.title_menu.buttons[0])
	await restore_stage("seller")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
	screen._flow.show_panel(&"appraisal"); await _frames()
	var before := _session.read_state()
	var seller_id: String = _session.counter_model().active_id
	_check(not FirstDebt.flag(_session._day.state, "fd_mark_read"), "fixture has not inspected physical detail")
	_check(panel._detail_model.is_empty(), "unread inspection not exposed by rendering")
	_session._save.library.fail_write = true
	await _click("看看内圈与凤尾")
	_check(not panel._detail.visible and not screen.old_shop.visible, "write failure opens neither detail nor album")
	_check(_session.read_state() == before, "failed discovery fully rolls back")
	_check(panel._body.text.contains("保存") or panel._body.text.contains("写"), "failure is visible and retryable")
	_session._save.library.fail_write = false
	await _click("看看内圈与凤尾"); await _frames()
	_check(panel._detail.is_visible_in_tree() and not screen.old_shop.visible, "detail stays inside appraisal")
	_check(screen._flow.get_active_panel_id() == &"appraisal", "appraisal remains active")
	_check(panel._detail_image.texture != null and panel._detail_text.text.contains("瑞丰"), "physical image and observed description")
	var after := _session.read_state()
	var gained: Array = after.narrative_flags.filter(func(f: String) -> bool: return f not in before.narrative_flags)
	_check(gained == ["fd_mark_read"], "only physical mark knowledge granted")
	_check(after.event_history.size() == before.event_history.size() + 1, "one discovery only")
	_check(after.cash == before.cash and after.game_minutes == before.game_minutes, "free observation unchanged")
	_check(_session.counter_model().active_id == seller_id, "seller unchanged")
	_check(panel._detail_text.get_minimum_size().y <= panel._detail_text.size.y, "description not clipped")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel._detail_back.get_global_rect()), "return within viewport")
	await shot("appraisal-detail")
	await key(KEY_ESCAPE)
	_check(not panel._detail.visible and panel.is_visible_in_tree(), "Esc returns to appraisal")
	_check(root.gui_get_focus_owner() == panel._detail_entry, "focus returns to detail tab")
	await key(KEY_ENTER); await _frames()
	_check(panel._detail.visible, "keyboard reopens physical detail")
	await _click("返回鉴定")
	_check(not panel._detail.visible and panel.is_visible_in_tree(), "return button stays in appraisal")
	_check(_session.read_state() == after, "repeat inspection no action or duplicate record")
	await _click("内圈与凤尾")
	await _click_button(screen.get_node("%CloseDrawerButton"))
	_check(not panel._detail.visible and panel.is_visible_in_tree(), "header close returns one level")
	await key(KEY_ESCAPE)
	_check(not screen.get_node("Drawer").visible, "second Esc closes drawer")
	screen._flow.show_panel(&"appraisal"); await _frames()
	_check(not panel._detail.visible, "reopened appraisal starts with ordinary item")
	var saved := _session._save.library.read_entry("auto/" + String(_session.definition.id))
	_check(not saved.is_empty(), "discovery persisted with replay validation")
	_check(_session._save.library.adopt(saved, _session), "restore saved discovery")
	screen._flow.show_panel(&"appraisal"); await _frames()
	_check(panel._detail_entry != null, "saved detail available for local reinspection")
	await _click("内圈与凤尾"); await key(KEY_ESCAPE)
	await _click("观察纹样 · 5分钟")
	before = _session.read_state()
	await _click("细看内圈与接缝 · 5分钟")
	_check(_session._day.state.game_minutes == before.game_minutes + 5, "ordinary paid appraisal still takes five minutes")
	_check(not screen.old_shop.visible, "normal appraisal never opens story album")
	await shot("appraisal-return")
	screen._flow.show_panel(&"trade"); await _frames()
	_check(screen._flow.get_active_panel_id() == &"trade", "continue normal trade")
	# The dialogue shortcut uses the same physical presentation, never the album.
	await restore_stage("seller"); screen._flow.show_panel(&"dialogue"); await _frames()
	await _click("看看内圈与凤尾")
	_check(panel._detail.is_visible_in_tree() and not screen.old_shop.visible, "dialogue shortcut also routes to physical appraisal")
	print("RECOVERY ITEM DETAIL UI %d: %d assertions, %d failures" % [root.size.x, _assertions, _failures])
	_main.queue_free(); await process_frame; quit(0 if _failures == 0 else 1)

func shot(stage: String) -> void:
	await create_timer(.12).timeout; RenderingServer.force_draw()
	var directory := "res://docs/qa/first-debt-recovery-release/ui/" if aqi_version == 41 else "res://docs/qa/first-debt-recovery/ui/"
	_check(root.get_texture().get_image().save_png(directory + str(root.size.x) + "-" + stage + ".png") == OK, "capture " + stage)
