extends "res://tests/merit_recovery_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new(recovery_manifest()).load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for mode in ["return", "pay"]:
		for status in ["pending", "seen"]:
			InvestigationSaveCodec.clear_cache()
			var start := Time.get_ticks_msec()
			var s := load_stage("merit-" + status + "-" + mode)
			check(s != null,"cold restore")
			if s == null: quit(1); return
			check(s._day.state.hidden_merit == 10,"one persisted reward")
			check(s.merit_feedback_model().pending == (status == "pending"),"playback survives restart")
			check(not s.event_command("fd_settle",mode).ok,"cannot settle again after restart")
			print("COLD ",mode," ",status," ",Time.get_ticks_msec()-start,"ms")
	print("MERIT PROCESS: %d passes, %d failures" % [passes,failures]); quit(0 if failures == 0 else 1)
