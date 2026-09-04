extends SceneTree

var failures := 0
var passes := 0
const PATH := "user://tests/m6_cross_process.json"
func _initialize() -> void:
	call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL · " + message)
func events(s: RunSession) -> void:
	for i in 10:
		var model := s.event_model()
		if model.pending_id.is_empty(): return
		check(s.event_command(model.pending_id, model.buttons[0].detail).ok, "事件")
func run_test() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var catalog := JsonContentProvider.new("res://tests/fixtures/m6_manifest.json").load_catalog().catalog
	var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var s := RunSession.new(definition, catalog.content_version, SaveManager.new(PATH), catalog)
	match mode:
		"write_debt":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			s = RunSession.new(definition, catalog.content_version, SaveManager.new(PATH), catalog)
			events(s); s.execute("open_shop")
			check(s.counter_command("offer", s.counter_model().active_id, "", 95).ok, "收货占款")
			s.execute("wait_until_seal")
			check(s.execute("resolve_night").ok, "欠款保存")
		"resume_bankrupt":
			check(s.load_checkpoint().ok and s.read_state().fee_arrears[0].amount == 3, "新进程恢复短款")
			check(s.execute("continue_run").ok, "宽限一夜")
			events(s); s.execute("open_shop"); s.execute("wait_until_seal")
			check(s.execute("resolve_night").ok and s.read_state().phase == "bankrupt", "跨进程到期失败")
		"read_bankrupt":
			check(s.load_checkpoint().ok and s.read_state().phase == "bankrupt" and s.read_state().bankruptcy_archive.size() == 1, "重启保持破铺终局")
		"write_mirror":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			s = RunSession.new(definition, catalog.content_version, SaveManager.new(PATH), catalog)
			var helper := M6Tests.new()
			helper._expect = check
			helper.catalog = catalog
			helper.run_def = definition
			var id := helper.midnight(s)
			s.risk_command("uncover", id); s.mirror_command("midnight_old_ticket", "peek"); s.mirror_command("midnight_old_ticket", "pursue")
			check(s.commerce_command("sell", id, "buyer_mirror").ok, "卖镜")
			helper.seal(s)
		"resume_death":
			check(s.load_checkpoint().ok, "新进程恢复已卖镜纠缠")
			var id: String = s.read_state().risk_pending
			check(not id.is_empty() and s.risk_command("defy", id).ok, "危机死亡保存")
		"read_death":
			check(s.load_checkpoint().ok and s.read_state().phase == "dead" and s.read_state().death_archive.size() == 1, "重启保持死亡和费用记录")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_: check(false, "未知模式")
	print("M6 CROSS PROCESS %s: %d passes, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)
