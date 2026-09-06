extends SceneTree

const PATH := "user://tests/room_cross_process.json"
var passes := 0
var failures := 0

func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var catalog := JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog().catalog
	var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	if mode in ["write_room", "write_pursuit", "write_shop"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var s := RunSession.new(definition, catalog.content_version, SaveManager.new(PATH), catalog)
	var helper := RoomTests.new()
	helper.catalog = catalog
	helper.run_def = definition
	helper._expect = check
	match mode:
		"write_room":
			helper.open(s)
			helper.seal(s)
			check(s.execute("enter_room").ok, "房间落盘")
		"sleep":
			check(s.load_checkpoint().ok and s.read_state().phase == "private_room", "新进程房间恢复")
			check(s.execute("sleep").ok, "就寝落盘")
		"summary":
			check(s.load_checkpoint().ok and s.read_state().phase == "sleep_resolution", "新进程睡眠恢复")
			check(s.execute("finish_sleep").ok and s.read_state().cash == 92, "日结不重复扣费")
		"write_pursuit":
			var id := helper.midnight(s)
			s.risk_command("uncover", id)
			check(s.mirror_command("midnight_old_ticket", "peek").ok, "窥镜")
			check(s.mirror_command("midnight_old_ticket", "pursue").ok, "追看")
			s.risk_command("cover", id)
			check(s.commerce_command("sell", id, "buyer_mirror").ok, "卖镜")
			helper.seal(s)
			check(s.execute("enter_room").ok, "带纠缠回房")
		"read_summary":
			check(s.load_checkpoint().ok and s.read_state().phase == "day_summary", "新进程日结恢复")
			check(not s.execute("finish_sleep").ok and s.read_state().cash == 92, "日结恢复不重扣")
		"write_shop":
			helper.third(s)
			helper.seal(s)
			check(s.read_state().phase == "shop_resolution" and not s.read_state().risk_pending.is_empty(), "铺内危机落盘")
		"read_shop":
			check(s.load_checkpoint().ok and s.read_state().phase == "shop_resolution", "新进程铺内危机恢复")
			check(not s.execute("enter_room").ok, "新进程不可绕过铺内危机")
			check(s.risk_command("retreat", s.read_state().risk_pending).ok, "新进程铺内应对")
			check(s.execute("enter_room").ok, "铺内应对后回房")
		"pursuit_sleep":
			check(s.load_checkpoint().ok and s.read_state().phase == "private_room", "新进程纠缠恢复")
			check(s.execute("sleep").ok and not s.read_state().risk_pending.is_empty(), "个人危机落盘")
		"death":
			check(s.load_checkpoint().ok and s.read_state().phase == "sleep_resolution", "新进程危机恢复")
			check(s.risk_command("defy", s.read_state().risk_pending).ok, "死亡落盘")
		"read_death":
			check(s.load_checkpoint().ok and s.read_state().phase == "dead", "终局不可复活")
			check(s.read_state().death_archive.size() == 1 and not s.execute("finish_sleep").ok, "死亡不可绕过")
			s.new_run()
			check(s.read_state().death_archive.size() == 1, "重开保留绝当录")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_: check(false, "未知测试模式")
	print("ROOM PROCESS %s: %d assertions, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL: " + message)
