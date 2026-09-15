extends "res://tests/integrated_ui_smoke.gd"

const Fixture = preload("res://tests/living_fixture.gd")

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("V22 UI TIMEOUT"); quit(1))
	_capture_prefix = "living_1600" if "wide" in OS.get_cmdline_user_args() else "living_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/v22_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save = GhostReplayStore.new()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 22, "default entrance v22")
	var catalog := _session._counter.catalog
	_check(_session.risk_model().records.is_empty(), "unknown items and empty death archive hidden")
	install(Fixture.before(catalog, func(_s: RunSession, row: Dictionary) -> bool: return row.method == "study_command" and row.args[0] == "wm_notes"))
	await receipts()
	await _click("物品记事")
	await _click("翻查顾先生的用镜短记 · 5分钟")
	var notes := _session.risk_model()
	var prose: String = notes.body + notes.history
	_check(prose.count("短记上写着") == 1, "short note shown exactly once after reading")
	_check(not prose.contains("《绝当录》") and not prose.contains("鬼货") and not prose.contains("复看不耗时") and not prose.contains("免费复看"), "no premature book, ghost goods label or reading cost reminder")
	_check(notes.records.size() == 1 and notes.records[0].label == "泣血铜镜", "records named after the actual item")
	var before := _session.read_state()
	_session.risk_model("death_archive"); _session.risk_model("item_weeping_mirror")
	_check(GhostSaveCodec.same(before, _session.read_state()), "reading and selecting records is free and state-neutral")
	await _capture("00_item_notes")
	await _click("照看与处置")
	var mirror := LivingMirror.held(_session._day.state)
	mirror.ownership_state = "sold"
	var sold := _session.risk_model()
	_check(sold.history.contains("短记上写着") and sold.records.size() == 1, "sold item's own record remains readable")
	_check(not sold.buttons.any(func(row: Dictionary) -> bool: return row.command in ["cover", "uncover", "soul_inspect"]), "sold mirror has no holding actions")
	mirror.ownership_state = "owned"
	var death_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v22/death.json"))
	_session._day.state.death_archive.assign(death_data.death_archive)
	var archive := _session.risk_model("death_archive")
	_check(archive.history.contains("《绝当录》") and not archive.history.contains("短记上写着"), "actual archive has its own page")
	_check(not _session.risk_model("item_weeping_mirror").history.contains("《绝当录》"), "archive does not mix with item notes")
	_session._day.state.death_archive.clear()
	install(Fixture.guest(catalog, GhostGuests.CLOSED))
	await receipts()
	await _click("鉴定")
	await _capture("01_no_inspection")
	await _click("物品记事")
	await _click("借铜镜照看来客 · 5分钟")
	_check(_session._day.state.soul_history.back().result == "ghost", "actual mirror button")
	await _capture("02_ghost_reflection")
	await _click("物品见闻")
	_check(not _session.risk_model().history.contains("此客不是活人"), "mirror use result is absent from item notes")
	await _capture("02_item_notes_after_scan")
	await _click("照看与处置")
	await _click("借铜镜照看来客 · 5分钟")
	await _click("鉴定")
	var action: Dictionary = _session.counter_model().appraisal.buttons.filter(func(row: Dictionary) -> bool: return row.command == "appraise")[0]
	await _click(action.label)
	_check(_session._day.state.visits.any(func(v: CustomerVisit) -> bool: return v.customer_id == GhostGuests.CLOSED and v.status == "inspection_refused"), "actual forbidden inspection leaves")
	await _capture("03_inspection_departure")
	await receipts()
	install(Fixture.guest(catalog, GhostGuests.SWAP))
	await _click("交易")
	await _capture("04_swap_offer")
	await _click("物品记事")
	await _click("借铜镜照看来客 · 5分钟")
	_check(_session._day.state.soul_history.back().result == "ghost", "swap identity")
	await _click("交易")
	await _click("交出原物，收下替物与80银元 · 5分钟")
	_check(_session._day.state.exchange_history.size() == 1, "actual exchange commit")
	await _capture("05_swap_receipt")
	await receipts()
	await _click("账本")
	await _click("当票")
	await _capture("06_replaced_ticket")
	install(Fixture.before(catalog, func(s: RunSession, row: Dictionary) -> bool: return s._day.state.current_night_index == 6 and row.method == "inspect_customer" and row.args[0].begins_with("return/")))
	await _click("物品记事")
	await _click("借铜镜照看来客 · 5分钟")
	_check(_session._day.state.soul_history.back().result == "living", "return living scan")
	await _capture("07_living_return")
	await _click_button(_main.get_node("CounterScreen/CounterView").get_hotspot(&"customer"))
	await _click("办理赎当")
	var label: String = _session.counter_model().trade.buttons[0].label
	await _click(label)
	await _capture("08_substitute_delivery")
	await receipts()
	install(Fixture.before(catalog, func(s: RunSession, row: Dictionary) -> bool: return s._day.state.current_night_index == 7 and row.method == "execute" and row.args[0] == "open_shop"))
	await _click("铺中记事")
	_check(_session.seven_notice().contains("替物") and _session._day.state.person_deaths.size() == 1, "death notice exists")
	await _capture("09_death_notice")
	print("LIVING UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func install(fixture: RunSession) -> void:
	_session._day.state = fixture._day.state
	_session._pawn_choices = fixture._pawn_choices
	_session.message = ""
	_session.changed.emit()
