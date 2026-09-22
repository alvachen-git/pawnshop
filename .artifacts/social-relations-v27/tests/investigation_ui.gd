extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("V23 UI TIMEOUT"); quit(1))
	_capture_prefix = "v23_1600" if "wide" in OS.get_cmdline_user_args() else "v23_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/v23_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save = GhostReplayStore.new()
	_main.title_menu.configure(true, false)
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 23, "default v23")
	install("commission")
	await service()
	await _capture("01_commission")
	var cash := _session._day.state.cash
	await _click("托人核查 · 30银元 · 10分钟")
	_check(_session._day.state.cash == cash - 30, "actual commission payment")
	await _capture("02_paid")
	install("report")
	await service()
	_check(not _session._day.state.investigation.read, "letter starts sealed")
	await _capture("03_delivered")
	await _click("拆阅查访回报")
	_check(_session._day.state.investigation.read, "explicit letter read")
	await _capture("04_report")
	await _click("约丈夫来铺 · 5分钟")
	_check(InvestigationService.appointment(_session._day.state).night == 10, "actual appointment")
	await _capture("05_booked")
	install("meeting")
	await _click("对话")
	await _capture("06_meeting")
	await _click("借铜镜照看来客 · 5分钟")
	_check(_session._day.state.soul_history.back().result == "living", "husband living")
	await _capture("07_living")
	await _click(InvestigationService.PROMPTS[0] + " · 5分钟")
	_check(_session.counter_model().dialogue.body.contains("此客是活人"), "known reflection remains readable after question")
	await _capture("08_first_answer")
	await _click("结束这次会面")
	await service()
	await _click("重新约见 · 5分钟")
	_check(InvestigationService.appointment(_session._day.state).night == 11 and _session._day.state.investigation.answers.size() == 1, "partial meeting retained pending eleventh")
	await _capture("09_partial_pending")
	install("meeting")
	await _click("对话")
	for i in 3: await _click(InvestigationService.PROMPTS[i] + " · 5分钟")
	await _capture("10_admission")
	await service()
	await _click("记下：准备把事实带到镜前")
	_check(_session._day.state.investigation.attitude == "prepare_mirror", "only preparation attitude")
	await _capture("11_intent")
	install("ending")
	await _click("夜间结算")
	await _frames()
	await _capture("12_ending")
	print("INVESTIGATION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func service() -> void:
	await receipts()
	var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	await _click_button(_main.get_node("CounterScreen/%MenuButton"))
	await _click("托人查访")

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 23, _session._counter.catalog, true)
	_check(state != null, "validated fixture " + stage + codec.error_message)
	if state == null: return
	_session._day.state = state
	_session.message = ""
	_session.restored.emit()
	_session.changed.emit()
