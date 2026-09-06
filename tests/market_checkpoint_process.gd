extends SceneTree

var failures := 0
var passes := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error("FAIL " + label)
func run() -> void:
	var helper := MarketTests.new()
	helper._expect = check
	helper.catalog = JsonContentProvider.new("res://data/content_manifest.json").load_catalog().catalog
	helper.run_def = helper.catalog.get_definition("runs", helper.catalog.default_run_id)
	var path := "user://tests/market_process.json"
	var session := RunSession.new(helper.run_def, helper.catalog.content_version, SaveManager.new(path), helper.catalog)
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "write":
		session._day.state.run_seed = 1
		session._day.state.ordinary_selections.clear()
		session._day.state.scenario_selections.clear()
		session._counter.customers.prepare_night(session._day.state, helper.run_def, helper.catalog)
		var ids := helper.buy_first_three(session)
		check(session.sell_batch("buyer_recycler", ids).ok, "跨进程前真实批量出售")
		check(helper.finish(session), "写入批次和行情")
	else:
		check(session.load_checkpoint().ok, "独立进程读取v12")
		check(session._day.state.sale_batches.size() == 1 and session._day.state.sale_records.size() == 3, "逐件和批次完整")
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var restored := SaveCodec.new().encode(session._day.state, 12)
		# JSON numbers decode as floats; compare both payloads after the same round trip.
		check(JSON.stringify(JSON.parse_string(JSON.stringify(restored))) == JSON.stringify(payload), "JSON检查点精确恢复")
		if mode == "next":
			helper.finish_room(session)
			check(session.execute("continue_run").ok, "跨进程推进次夜")
		else:
			check(session._day.state.current_night_index == 2 and session._day.state.market_history.size() == 2, "次夜保留此前行情")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MARKET PROCESS %s: %d passes, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)
