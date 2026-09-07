extends SceneTree

var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("FAIL " + label)
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/seven_night_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog")
	if not loaded.is_success(): quit(1); return
	var run_def := loaded.catalog.get_definition("runs", "ordinary_seven") as RunDefinition
	run_def._randomize_seed = false
	run_def._seed = 42
	var s := RunSession.new(run_def, 13, SaveManager.new("user://tests/seven_process.json"), loaded.catalog)
	var driver := SevenTestDriver.new()
	driver.check = check
	var mode := OS.get_cmdline_user_args()[0]
	if mode == "prepare":
		for n in 3:
			driver.open(s); driver.work(s); driver.finish(s)
		driver.action(s, "prep_visitors")
		check(s._day.state.current_night_index == 4 and s._day.state.pawn_tickets.size() == 1, "preparation with existing three-night ticket")
	else:
		var result := s.load_checkpoint()
		check(result.ok, "cross-process restore: " + result.message)
		if not result.ok: quit(1); return
		match mode:
			"sixth":
				check(PreparationService.used(s._day.state, "visitors", 4), "intel restored")
				driver.action(s, "prep_investigate")
				driver.open(s); driver.work(s); driver.finish(s)
				driver.action(s, "prep_contact")
				driver.open(s); driver.work(s); driver.finish(s)
				check(s._day.state.current_night_index == 6 and s._day.state.inventory_instances.size() == 3, "sixth pre-open with two pens and collateral")
			"room":
				driver.open(s)
				check(s._day.state.pawn_tickets[0].status == "redeemed", "same owner sixth night redemption")
				driver.work(s)
				check(s._day.state.sale_records.size() == 2, "two real appointment sales")
				for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]: driver.action(s, action)
			"sleep": driver.action(s, "sleep")
			"seventh": driver.action(s, "finish_sleep"); driver.action(s, "continue_run")
			"finish": driver.open(s); driver.finish(s)
			"read":
				check(s._day.state.phase == &"run_ended" and s._day.state.summaries.size() == 7, "final summary restored")
				check(s._day.state.pawn_tickets[0].status == "redeemed" and s._day.state.sale_batches.size() == 1, "no duplicate redemption or batch")
	print("SEVEN PROCESS %s: %d assertions, %d failures" % [mode, assertions, failures])
	quit(0 if failures == 0 else 1)
