extends SceneTree

var failed := false

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("M5 PROCESS FAIL: " + label)

func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var fixture := M5Tests.new()
	fixture._expect = check
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	check(loaded.is_success(), "加载生产目录")
	fixture.catalog = loaded.catalog
	fixture.run_def = fixture.catalog.get_definition("runs", fixture.catalog.default_run_id)
	var save := SaveManager.new("user://tests/m5_process.json")
	var session := RunSession.new(fixture.run_def, fixture.catalog.content_version, save, fixture.catalog)
	match mode:
		"warning":
			fixture.third(session)
			fixture.seal(session)
			check(not session.read_state().risk_pending.is_empty(), "写入可挽救危机")
		"death":
			check(session.load_checkpoint().ok, "新进程恢复危机")
			check(not session.read_state().risk_pending.is_empty(), "待处理危机未丢失")
			check(session.risk_command("defy", session.read_state().risk_pending).ok, "提交永久死亡")
		"restart":
			check(session.load_checkpoint().ok and session.read_state().phase == "dead", "另一进程恢复死亡，无法复活")
			session.new_run()
			fixture.events(session)
			session.execute("open_shop")
			fixture.seal(session)
			check(session.read_state().death_archive.size() == 1, "重开保留绝当录")
		"archive":
			check(session.load_checkpoint().ok and session.read_state().phase == "day_summary" and session.read_state().current_night_index == 1 and session.read_state().death_archive.size() == 1, "重开存档与绝当录跨进程共存")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
		_: check(false, "未知模式")
	print("M5 PROCESS ", mode, " PASS=", not failed)
	quit(1 if failed else 0)
