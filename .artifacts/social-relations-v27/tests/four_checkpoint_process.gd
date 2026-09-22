extends "res://tests/run_four_night.gd"

const PATH := "user://tests/four_cross_process.json"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/four_night_manifest.json").load_catalog()
	check(loaded.is_success(), "process catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	var mode: String = OS.get_cmdline_user_args()[0]
	var s := session(42, PATH)
	if mode == "write":
		command(s, "open_shop")
		while s._day.state.pawn_tickets.is_empty() and s._day.state.game_minutes < 490:
			var visit := s._counter.customers.active(s._day.state)
			if visit == null: command(s, "short_task"); continue
			if VarietySaveCodec.selection(s._day.state, visit.visit_id).get("sample_role") == "pawn":
				check(s.counter_command("pawn", visit.visit_id, "", 40).ok, "original contract")
			else: check(s.counter_command("reject", visit.visit_id).ok, "other visitor rejected")
		end_night(s)
		command(s, "continue_run")
		check(s._day.state.current_night_index == 2, "middle night checkpoint")
	else:
		check(s.load_checkpoint().ok, "new process restores: " + s.message)
		if failures > 0: quit(1); return
		match mode:
			"fourth":
				for night in [2, 3]:
					check(s._day.state.current_night_index == night, "correct middle night")
					command(s, "open_shop")
					end_night(s)
					command(s, "continue_run")
				check(s._day.state.pawn_returns.size() == 1 and s._day.state.phase == &"pre_open", "before fourth night return")
			"room":
				command(s, "open_shop")
				var returning := PawnReturnService.current(s._day.state)
				check(s.counter_command("redeem", returning.id).ok, "fourth night redemption")
				command(s, "close_shop")
				command(s, "wait_until_seal")
				command(s, "resolve_night")
				# Failure rolls back the room transition and never repeats redemption.
				var before := s.read_state()
				var original_path := s._save.path
				s._save.path = PATH + "/invalid.json"
				check(not s.execute("enter_room").ok and s.read_state() == before, "write failure rolls back")
				s._save.path = original_path
				command(s, "enter_room")
				check(s._day.state.cash == 264 and s._day.state.pawn_tickets[0].status == "redeemed", "principal returned once plus fee4 minus costs40")
			"sleep":
				check(s._day.state.phase == &"private_room", "room across process")
				command(s, "sleep")
			"finish":
				check(s._day.state.phase == &"sleep_resolution", "sleep across process")
				command(s, "finish_sleep")
				command(s, "continue_run")
			"read":
				check(s._day.state.phase == &"run_ended" and s._day.state.cash == 264, "final fourth night summary across process")
				var before := s.read_state()
				for action in ["resolve_night", "sleep", "finish_sleep", "continue_run"]:
					check(not s.execute(action).ok and before == s.read_state(), "no duplicate final settlement")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("FOUR PROCESS %s: %d passes, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)

func end_night(s: RunSession) -> void:
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep"]:
		if not command(s, action): return
