extends "res://tests/recovery_durability.gd"
func run() -> void:
	var loaded := JsonContentProvider.new(recovery_manifest()).load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for stage in ["first-seller", "seller", "hint", "phoenix-prep", "before-fd_truth", "before-fd_compensation", "before-fd_settle"]:
		var started := Time.get_ticks_msec()
		var s := load_stage("committed-" + stage)
		check(s != null, "cold restore " + stage)
		if s == null: quit(1); return
		print("RESTORE ", stage, " ", Time.get_ticks_msec() - started, "ms")
		check(s._day.state.run_definition_id == String(run_def.id), "version isolated")
		if stage == "before-fd_settle":
			check(FirstDebt.flag(s._day.state, "fd_peace") and not s.event_command("fd_settle", "pay").ok, "cannot pay again after process restart")
	print("RECOVERY PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
