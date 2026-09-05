extends SceneTree

const PATH := "user://tests/m7_cross_process.json"
var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL · " + message)

func run_test() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var catalog := JsonContentProvider.new("res://tests/fixtures/m7_manifest.json").load_catalog().catalog
	var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	if mode == "write": DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var s := RunSession.new(definition, catalog.content_version, SaveManager.new(PATH), catalog)
	var helper := M7Tests.new()
	helper._expect = check; helper.catalog = catalog; helper.run_def = definition
	match mode:
		"write":
			s._day.state.run_seed = helper.seed_for("n2_visit1", "flawed", "urgent")
			s._day.state.scenario_selections.clear()
			s._counter.customers.prepare_night(s._day.state, definition, catalog)
			helper.open(s)
			helper.action(s, "question", "repairs"); helper.action(s, "appraise", "light")
			if helper.active(s).item.selected_variant_id == "repaired": helper.action(s, "question", "seam")
			helper.action(s, "reject"); helper.wait_to(s, 90)
			helper.action(s, "question", "material"); helper.action(s, "appraise", "magnet")
			if helper.active(s).item.selected_variant_id == "plated": helper.action(s, "question", "magnetic_core")
			helper.action(s, "appraise", "scratch"); helper.action(s, "reject")
			helper.seal(s)
			check(s.execute("continue_run").ok, "第二夜开铺前落盘")
		"resume":
			check(s.load_checkpoint().ok, "新进程读取三笔情境与首夜问答")
			check(s.read_state().scenario_history.size() >= 8, "首夜取证记录完整恢复")
			helper.open(s)
			check(helper.active(s).item.selected_variant_id == "flawed" and helper.active(s).situation_id == "urgent", "跨进程种子保持故障与急售组合")
			helper.action(s, "question", "reason"); helper.action(s, "question", "deadline")
			helper.action(s, "appraise", "observe"); helper.action(s, "appraise", "inspect")
			helper.action(s, "pressure", "flaw"); helper.action(s, "concession")
			check(helper.active(s).trade.reserve_price == 15, "跨进程继续后两份独立优惠正确")
			check(helper.action(s, "offer", "", 17).ok, "怀表成交")
			helper.seal(s)
		"read":
			check(s.load_checkpoint().ok, "第三个进程读取怀表成交")
			check(s.read_state().cash == 67 and s.read_state().inventory_instances[0].acquisition_price == 17, "成交与两夜息费完整保留")
			var history: Array = s.read_state().scenario_history
			check(history.back().command == "offer" and history.back().concession_used and history.back().used_clues == ["flaw"], "问答物证与急售使用记录保持")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_: check(false, "未知模式")
	print("M7 CROSS PROCESS %s: %d passes, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)
