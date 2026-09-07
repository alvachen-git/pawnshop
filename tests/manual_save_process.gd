extends "res://tests/manual_save_tests.gd"
const PATH := "user://tests/manual_cross_process_library.json"

func _initialize() -> void: call_deferred("process_test")

func process_test() -> void:
	driver.check = check
	var mode: String = OS.get_cmdline_user_args()[0]
	var s := fresh("res://data/seven_night_manifest.json")
	s._save.library.path = PATH
	if mode == "write":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		save(s, 1)
		driver.open(s)
		var visitor := s._counter.customers.active(s._day.state)
		check(s.counter_command("offer", visitor.visit_id, "", visitor.trade.asking_price).ok, "acquire for process test")
		driver.action(s, "close_shop")
		save(s, 2)
		driver.action(s, "wait_until_seal")
		save(s, 3)
		driver.action(s, "resolve_night")
		driver.action(s, "enter_room")
		save(s, 4)
		var horror := fresh("res://data/legacy/content_v9.json")
		horror._save.library.path = PATH
		var helper := RoomTests.new()
		helper.catalog = horror._counter.catalog
		helper.run_def = horror.definition
		helper._expect = check
		helper.third(horror)
		helper.seal(horror)
		save(horror, 5)
		var opening := fresh("res://data/opening_manifest.json")
		opening._save.library.path = PATH
		var model := opening.event_model()
		check(opening.event_command(model.pending_id, model.buttons[0].detail).ok, "opening first choice")
		save(opening, 6)
	elif mode == "read":
		for slot in range(1, 7):
			var entry := s._save.library.read_entry("manual/%d" % slot)
			check(not entry.is_empty(), "fresh process reads slot " + str(slot) + s._save.library.error_message)
			if entry.is_empty(): continue
			check(s._save.library.adopt(entry, s), "fresh process adopts " + str(slot))
			check(s._day.state.phase == [&"pre_open", &"closed_processing", &"night_resolution", &"private_room", &"shop_resolution", &"pre_open"][slot - 1], "exact phase across process")
			if slot in [2, 3]: check(s._day.state.summaries.is_empty() and s._day.state.fee_history.is_empty(), "no premature settlement")
			if slot == 5: check(not s._day.state.risk_pending.is_empty(), "pending crisis survives restart")
			if slot == 6: check(s._day.state.event_history.size() == 1 and not s._day.state.pending_event_id.is_empty(), "opening choice position preserved")
	elif mode == "continue":
		var entry := s._save.library.read_entry("manual/2")
		check(s._save.library.adopt(entry, s), "resume closed night")
		driver.finish(s)
		for night in range(2, 8): driver.open(s); driver.finish(s)
		check(s._day.state.phase == &"run_ended" and s._day.state.fee_history.size() == 7, "only seven daily settlements")
		save(s, 4)
	elif mode == "read_final":
		var entry := s._save.library.read_entry("manual/4")
		check(not entry.is_empty() and s._save.library.adopt(entry, s), "final restart")
		check(s._day.state.phase == &"run_ended" and s._day.state.fee_history.size() == 7, "final state unchanged")
		check(not s.execute("resolve_night").ok, "cannot resettle end")
	print("MANUAL PROCESS TESTS %s: %d assertions, %d failures" % [mode, checks, failures])
	quit(1 if failures else 0)
