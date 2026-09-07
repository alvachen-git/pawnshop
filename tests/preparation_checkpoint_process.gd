extends "res://tests/preparation_tests.gd"

const PROCESS_PATH := "res://.godot/qa/preparation_v15/runtime/process.json"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/preparation_manifest.json").load_catalog()
	check(loaded.is_success(), "cross-process catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "prepared_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	var s := RunSession.new(run_def, 15, SaveManager.new(PROCESS_PATH), catalog)
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "start":
		driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
	else:
		check(s.load_checkpoint().ok, "load previous process: " + s.message)
		check(JSON.stringify(s.read_state()) == FileAccess.get_file_as_string(PROCESS_PATH + ".expected"), "exact restored state")
		match mode:
			"attract": driver.action(s, "prep_attract")
			"tea": driver.action(s, "prep_tea")
			"finish": driver.action(s, "prep_finish")
			"second": driver.open(s); driver.finish(s, "covered")
			"target": check(s.execute("prep_target", "watches").ok, "targeted request")
			"intel": driver.action(s, "prep_visitors")
			"third": driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
			"sixth":
				for night in [4, 5]:
					driver.action(s, "prep_tea")
					driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
			"end":
				for night in [6, 7]: driver.open(s); driver.work(s, "covered"); driver.finish(s, "covered")
			"read":
				check(s._day.state.phase == &"run_ended" and s._day.state.fee_history.size() == 7, "seven nights settled once")
				check(s._day.state.pawn_tickets[0].status == "redeemed", "original collateral returned")
				check(s._day.state.sale_records.filter(func(row: Dictionary) -> bool: return row.buyer_id == PreparationService.BUYER).size() == 2, "pens sold without contact or investigation")
				check(s._day.state.ledger_entries.filter(func(row: Dictionary) -> bool: return row.kind == "preparation").size() == 4, "preparation charged exactly once")
	var file := FileAccess.open(PROCESS_PATH + ".expected", FileAccess.WRITE)
	file.store_string(JSON.stringify(s.read_state()))
	file.close()
	print("PREPARATION PROCESS %s: %d assertions, %d failures" % [mode, assertions, failures])
	quit(0 if failures == 0 else 1)
