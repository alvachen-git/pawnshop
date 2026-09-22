extends "res://tests/run_integrated_seven.gd"

const PROCESS_PATH := "res://.godot/qa/integrated_seven/runtime/process.json"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/integrated_manifest.json").load_catalog()
	check(loaded.is_success(), "process catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "integrated_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	var s := RunSession.new(run_def, 14, SaveManager.new(PROCESS_PATH), catalog)
	var mode := OS.get_cmdline_user_args()[0]
	if mode == "opening":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROCESS_PATH))
		var model := s.event_model()
		check(s.event_command(model.pending_id, model.buttons[0].detail).ok, "save interrupted opening")
	else:
		check(s.load_checkpoint().ok, "cross process load: " + s.message)
		check(JSON.stringify(s.read_state()) == FileAccess.get_file_as_string(PROCESS_PATH + ".expected"), "cross process exact state")
		match mode:
			"first": driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
			"third": driver.open(s); driver.finish(s, "covered")
			"risk":
				driver.open(s); driver.work(s, "pursue")
				for item in s._day.state.inventory_instances:
					if item.definition_id == "item_weeping_mirror": check(s.risk_command("cover", item.instance_id).ok, "cover before pending personal risk")
				for command in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep"]: driver.action(s, command)
				check(not s._day.state.risk_pending.is_empty(), "save unresolved third night personal crisis")
			"survive":
				check(s.risk_command("retreat", s._day.state.risk_pending).ok, "resume and survive")
				driver.action(s, "finish_sleep"); driver.action(s, "continue_run")
			"sixth":
				for n in 2: driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
				check(s._day.state.current_night_index == 6, "arrive at sixth with two pens and pawn")
			"end":
				for n in 2: driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
			"read":
				check(s._day.state.phase == &"run_ended" and s._day.state.fee_history.size() == 7, "seven fees once")
				check(s._day.state.pawn_tickets[0].status == "redeemed" and s._day.state.sale_records.size() == 2, "redemption and sales once")
	var file := FileAccess.open(PROCESS_PATH + ".expected", FileAccess.WRITE)
	file.store_string(JSON.stringify(s.read_state()))
	file.close()
	print("INTEGRATED PROCESS %s: %d passes, %d failures" % [mode, passes, failures])
	quit(0 if failures == 0 else 1)
