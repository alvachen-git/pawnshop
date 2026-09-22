extends "res://tests/fan_condition_ui.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("BENCH UI TIMEOUT"); quit(1))
	_capture_prefix = "bench_independent_1600" if "wide" in OS.get_cmdline_user_args() else "bench_independent_1280"
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start_fan_condition_v29.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/bench_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := DraftUIStore.new(); store.origin = _session._day.state.ghost_origin; _session._save = store
	await _frames(); await _click_button(_main.title_menu.buttons[0])
	install("upgrade-without-book")
	await service()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var room := screen.facilities.room
	await _click_button(room.hotspots.bench)
	var upgrade := _find_button(room, "改造二级鉴物台 · 80银元 / 准备1次 / 两夜工期")
	_check(upgrade != null and room._scroll.get_global_rect().encloses(upgrade.get_global_rect()), "upgrade visible without scrolling")
	await _capture("upgrade")
	await _click("改造二级鉴物台 · 80银元 / 准备1次 / 两夜工期")
	_check(int(FanAppraisalService.data(_session._day.state).bench_due) == 4, "mouse upgrades without book")
	install("tools-without-book"); await service(); await _click_button(room.hotspots.bench)
	await _click("添置扇画工具 · 30银元 / 准备1次")
	_check(FanAppraisalService.data(_session._day.state).tools and not FanAppraisalService.data(_session._day.state).manual, "mouse buys tools without book")
	var study := _find_button(room, "研习扇画图录 · 准备1次 / 不收费")
	_check(study == null, "study moved out of bench")
	_check(room.body.text.contains("扇画工具 · 已配齐"), "bench shows installed equipment")
	await _capture("tools")
	print("BENCH UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
