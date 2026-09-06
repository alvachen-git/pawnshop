extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var ordinary := mode.ends_with("ordinary")
	var helper := BargainingTests.new()
	helper.setup(check)
	var path := "user://tests/bargaining-process-" + ("ordinary" if ordinary else "scenario") + ".json"
	var manager := SaveManager.new(path)
	manager.catalog = helper.catalog
	var s := RunSession.new(helper.run_def, helper.catalog.content_version, manager, helper.catalog)
	if mode.begins_with("write"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		helper.open(s)
		if ordinary: helper.wait_to(s, 210)
		helper.action(s, "appraise", "observe")
		check(helper.action(s, "belittle").ok, "试探完成")
		check(helper.action(s, "offer", "", helper.active(s).trade.reserve_price).ok, "按试探后底价成交")
		helper.seal(s)
		check(s.execute("enter_room").ok, "回房检查点写入")
	else:
		check(s.load_checkpoint().ok, "另一进程恢复检查点：" + s.message)
		var key := "bargaining_history" if ordinary else "scenario_history"
		var count := 0
		for row in s.read_state()[key]:
			if row.command == "belittle": count += 1
		check(count == 1 and s.read_state().inventory_instances.size() == 1, "恢复恰好一次试探与一次成交")
		var before := s.read_state()
		check(s.load_checkpoint().ok and before == s.read_state(), "重复读取不再扣款或重抽机会")
		if mode.begins_with("sleep"):
			check(s.read_state().phase == "private_room", "从房间恢复")
			check(s.execute("sleep").ok and s.execute("finish_sleep").ok, "就寝日结写入")
		else:
			check(s.read_state().phase == "day_summary", "日结仍保留试探历史")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("BARGAINING PROCESS TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
