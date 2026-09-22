extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("SOCIAL UI TIMEOUT"); quit(1))
	_capture_prefix = "social_1600" if "wide" in OS.get_cmdline_user_args() else "social_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/social_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 27 and _session.definition.id == SocialRules.RUN, "independent default new game")
	install("preparation")
	await receipts()
	_main.get_node("CounterScreen")._close_drawer()
	await _capture("00_counter_book")
	var before := JSON.stringify(_session.read_state())
	await service()
	var book: SocialPanel = _main.get_node("CounterScreen/SocialPanel")
	_check(book._name.text == "孙大元", "representative renamed")
	_check(book._roster.get_child_count() == 1, "only discovered faction shown")
	_check(_find_button(_main, "查看军方往来") == null and _find_button(_main, "军方往来") == null, "old text entrances removed")
	_check(JSON.stringify(_session.read_state()) == before, "viewing does not spend cash time or change score")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(not book.visible, "Esc closes book")
	_check(_main.get_node("CounterScreen/%CounterView").get_hotspot(&"social").has_focus(), "Esc returns keyboard focus to booklet")
	await service()
	_check(book._right.get_global_rect().end.y < 630 if root.size.x == 1280 else book._right.get_global_rect().end.y < 788, "book content stays above status bar")
	await _capture("01_contact")
	_check(not book._scroll.get_v_scroll_bar().visible, "procurement fits without scrollbar")
	_check(not book._body.text.contains("送礼") and _find_button(_main, "托人送礼") == null, "gift does not crowd procurement")
	var accept := _find_button(_main, "接下采购单")
	_check(accept.size.x < book._right.size.x * .65 and accept.size.y <= (43 if root.size.x == 1600 else 35), "compact action size")
	await _click("打点")
	await _capture("01b_gift")
	_check(not book._scroll.get_v_scroll_bar().visible, "gift fits without scrollbar")
	_check(_find_button(_main, "接下采购单") == null, "gift view shows one task")
	_check(JSON.stringify(_session.read_state()) == before, "tab switches remain read only")
	await _click("采购")
	await _click("接下采购单")
	_check(not _session._day.state.social.contract.is_empty() and book._title.text.ends_with("已接"), "compact procurement action accepts and refreshes")
	await _click("打点")
	var cash := _session._day.state.cash
	await _click("托人送礼")
	_check(_session._day.state.cash == cash - 20 and _session._day.state.social.military == 8, "UI gift applies once")
	await _click("旧事"); await _capture("02_record")
	await _click("采购")
	install("closure"); await service(); await _capture("03_closure")
	_check(book.section == 1, "closure opens the relevant tab")
	await _click("采购")
	await _click("翻到打点")
	_check(book.section == 1, "pending letter remains reachable from procurement")
	await _click("收下停业令，今夜守铺")
	_check(SocialRules.closed(_session._day.state), "UI accepts closure")
	await _capture("04_suspended")
	install("supply"); await service(); await _capture("05_supply")
	var offer: Dictionary = _session._day.state.social.pending.offers[0]
	await _click("约看" + offer.title)
	_check(_session._day.state.social.pending.is_empty() and _session._day.state.social.supplies.size() > 0, "UI selects one supply")
	install("claim"); await service(); await _capture("06_claim")
	await _click("协调退还原物，取回货款")
	_check(_session._day.state.social.pending.is_empty(), "UI resolves ownership claim")
	await _capture("07_claim_resolved")
	_check(book._scroll.size.y >= 65, "letter keeps readable scroll region with claim actions")
	_check(book._actions.get_parent() == book._body.get_parent(), "body and actions share one scrolling document")
	# Isolate the presenter overlap case: an existing counter result must not
	# intercept clicks on the open book, then becomes reachable after closing.
	var screen := _main.get_node("CounterScreen") as CounterScreen
	_session._day.state.phase = &"open"
	screen._recent = {"id":"book-ui-overlap-probe"}
	screen._recent_collapsed = false
	screen._refresh_recent_visibility()
	_check(not screen._recent_bar.visible, "counter result hidden while reading book")
	screen._close_drawer()
	_check(screen._recent_bar.visible, "counter result returns after book closes")
	print("SOCIAL UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func service() -> void:
	await receipts()
	var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	_main.get_node("CounterScreen")._close_drawer()
	await _click_button(_main.get_node("CounterScreen/%CounterView").get_hotspot(&"social"))
	await create_timer(0.4).timeout

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/social-relations/" + stage + ".json"))
	var catalog: ContentCatalog = _session._counter.catalog
	var run := catalog.get_definition("runs", data.run_definition_id) as RunDefinition
	var codec := SaveCodec.new()
	var state := codec.decode(data, run, 27, catalog, true)
	_check(state != null, "validated UI fixture " + stage + " " + codec.error_message)
	if state == null: return
	_session._switch_content(run, 27, catalog)
	_session._day.state = state
	_session.message = ""
	_session.restored.emit(); _session.changed.emit()
