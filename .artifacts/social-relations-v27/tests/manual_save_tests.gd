extends SceneTree
var failures := 0
var checks := 0
var serial := 0
var driver := SevenTestDriver.new()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(manifest: String) -> RunSession:
	var result := JsonContentProvider.new(manifest).load_catalog()
	check(result.is_success(), "content " + manifest)
	var run_def := result.catalog.get_definition("runs", result.catalog.default_run_id) as RunDefinition
	run_def._randomize_seed = false
	run_def._seed = 42
	serial += 1
	var saves := SaveManager.new("user://tests/manual_legacy_%d.json" % serial)
	saves.library = SaveLibrary.new("user://tests/manual_%d_%d.json" % [Time.get_ticks_usec(), serial])
	saves.catalog = result.catalog
	return RunSession.new(run_def, result.catalog.content_version, saves, result.catalog)

func save(s: RunSession, slot := 1) -> bool:
	var ok := s._save.library.write_entry("manual/%d" % slot, s._day.state, s.definition, s.content_version, s._counter.catalog)
	check(ok, "save " + String(s._day.state.phase) + ": " + s._save.library.error_message)
	return ok

func roundtrip(s: RunSession, slot := 1) -> void:
	if not save(s, slot): return
	var lib := SaveLibrary.new(s._save.library.path)
	var restored := lib.read_entry("manual/%d" % slot)
	check(not restored.is_empty(), "new manager decodes: " + lib.error_message)
	if restored.is_empty(): return
	check(restored.state.to_read_model() == s._day.state.to_read_model(), "snapshot exact " + String(s._day.state.phase))
	var bad: Dictionary = lib._read().entries["manual/%d" % slot].duplicate(true)
	bad.payload.cash += 1
	check(lib.decode_entry(bad).is_empty(), "reject altered cash")
	check(s._save.library.adopt(restored, s), "load atomic")
	check(not s._save.library.dirty(s._day.state), "read is clean")

func events(s: RunSession) -> void:
	for i in 45:
		var model := s.event_model()
		if model.buttons.is_empty(): return
		var button: Dictionary = model.buttons[0]
		var result := s.event_command(button.target_id, button.detail)
		check(result.ok, "event " + result.message)
		if not result.ok: return

func run() -> void:
	driver.check = check
	for manifest in ["res://data/content_manifest.json", "res://data/four_night_manifest.json", "res://data/seven_night_manifest.json", "res://data/opening_manifest.json"]:
		var s := fresh(manifest)
		roundtrip(s)
		events(s)
		check(s.execute("open_shop").ok, "open")
		var before := s._day.state.to_read_model()
		check(not s._save.library.write_entry("manual/2", s._day.state, s.definition, s.content_version, s._counter.catalog), "open cannot save")
		check(s._day.state.to_read_model() == before, "blocked save unchanged")
		if String(s.definition.id) != "opening_v01":
			var visitor := s._counter.customers.active(s._day.state)
			if visitor != null and "purchase" in visitor.transaction_modes:
				check(s.counter_command("offer", visitor.visit_id, "", visitor.trade.asking_price).ok, "purchase before close")
		else:
			# Opening tutorial is exercised separately by its existing end-to-end suite.
			events(s)
		if s._day.state.pending_event_id.is_empty():
			check(s.execute("close_shop").ok, "close")
			roundtrip(s, 2)
			check(s._day.state.summaries.is_empty() and s._day.state.fee_history.is_empty(), "close load does not settle")
			events(s)
			if s._day.state.pending_event_id.is_empty():
				check(s.execute("wait_until_seal").ok, "reach 03")
				roundtrip(s, 3)
				check(s.execute("resolve_night").ok, "settle once")
				roundtrip(s, 4)
				if s.definition.private_room:
					check(s.execute("enter_room").ok, "room")
					roundtrip(s, 5)
		var lib := s._save.library
		var original := FileAccess.get_file_as_string(lib.path)
		lib.fail_write = true
		check(not lib.write_entry("manual/1", s._day.state, s.definition, s.content_version, s._counter.catalog), "write failure")
		check(FileAccess.get_file_as_string(lib.path) == original, "failed overwrite preserves whole library")
		lib.fail_write = false
		check(lib.entries().filter(func(row: Dictionary) -> bool: return row.key.begins_with("manual/")).size() == 6, "six shared slots")
	_seven_contracts()
	_retry_endings()
	_corrupt_and_legacy()
	print("MANUAL SAVE TESTS: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _seven_contracts() -> void:
	var s := fresh("res://data/seven_night_manifest.json")
	for night in range(1, 8):
		if night >= 4:
			if night == 4: driver.action(s, "prep_investigate"); driver.action(s, "prep_contact")
			roundtrip(s)
		driver.open(s)
		driver.work(s)
		driver.action(s, "close_shop")
		roundtrip(s, 2)
		driver.action(s, "wait_until_seal")
		roundtrip(s, 3)
		driver.finish(s)
		roundtrip(s, 4)

func _retry_endings() -> void:
	var s := fresh("res://data/legacy/content_v9.json")
	var helper := RoomTests.new()
	helper.catalog = s._counter.catalog
	helper.run_def = s.definition
	helper._expect = check
	var mirror := helper.third(s)
	check(s.execute("close_shop").ok, "mirror close")
	roundtrip(s, 2)
	helper.seal(s)
	check(not s._day.state.risk_pending.is_empty(), "real pending mirror")
	save(s, 1)
	for attempt in 2:
		var before := s._day.state.to_read_model()
		var disk := FileAccess.get_file_as_string(s._save.library.path)
		s._save.library.fail_write = true
		check(not s.risk_command("defy", mirror).ok and s._day.state.to_read_model() == before, "failed death publication rolls back choice")
		check(FileAccess.get_file_as_string(s._save.library.path) == disk, "failed death no archive or slot write")
		s._save.library.fail_write = false
		check(s.risk_command("defy", mirror).ok, "real death " + str(attempt))
		check(s._save.library.archive("death_archive", String(s.definition.id)).size() == attempt + 1, "one archive per attempt")
		var repeated := s.risk_command("defy", mirror)
		check(not repeated.ok, "death response cannot repeat")
		var restored := s._save.library.read_entry("manual/1")
		check(not restored.is_empty(), "old living slot remains readable")
		check(s._save.library.adopt(restored, s), "death permits retry")
		check(s._day.state.phase == &"shop_resolution" and s._day.state.death_archive.size() == attempt + 1, "retry restores crisis and keeps deaths")
	check(s.risk_command("retreat", mirror).ok, "different outcome after retry")
	helper.finish_room(s)
	check(save(s, 1), "overwrite source slot keeps old deaths")
	check(s._save.library.archive("death_archive", String(s.definition.id)).size() == 2, "overwriting cannot erase archive")
	var bank := fresh("res://data/seven_night_manifest.json")
	save(bank)
	driver.open(bank)
	var visitor := bank._counter.customers.active(bank._day.state)
	check(bank.counter_command("offer", visitor.visit_id, "", 300).ok, "actual purchase uses cash")
	driver.finish(bank)
	driver.open(bank)
	driver.finish(bank, false)
	check(bank._day.state.phase == &"bankrupt", "real arrears bankruptcy")
	var recovered := bank._save.library.read_entry("manual/1")
	check(not recovered.is_empty() and bank._save.library.adopt(recovered, bank), "bankruptcy permits old save")
	check(bank._day.state.cash == 300 and bank._day.state.bankruptcy_archive.size() == 1, "restored cash with preserved bankruptcy")

func _corrupt_and_legacy() -> void:
	var s := fresh("res://data/legacy/content_v9.json")
	var lib := s._save.library
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, s.content_version)
	var entry := {"format": 1, "saved_at": "test", "payload": payload}
	check(not lib.decode_entry(entry, false).is_empty(), "old checkpoint keeps strict validation")
	var original := s.read_state()
	var bad := entry.duplicate(true)
	bad.payload.content_version = 99999
	check(lib.decode_entry(bad).is_empty() and s.read_state() == original, "incompatible content preserves current run")
	check(lib.decode_entry({"format": 1}).is_empty(), "malformed entry rejected")
	events(s)
	check(s.execute("open_shop").ok and s.execute("close_shop").ok, "legacy content closes normally")
	entry.payload = codec.encode(s._day.state, s.content_version)
	check(lib.decode_entry(entry, false).is_empty(), "old raw files cannot smuggle new partial phases")
	check(not lib.decode_entry(entry).is_empty(), "new format supports same content at partial phase")
	save(s)
	var intact := FileAccess.get_file_as_string(lib.path)
	var label := lib.last_label
	lib.busy = true
	check(not lib.write_entry("manual/1", s._day.state, s.definition, s.content_version, s._counter.catalog), "busy duplicate cannot submit")
	check(FileAccess.get_file_as_string(lib.path) == intact and lib.last_label == label, "duplicate preserves file and summary")
	lib.busy = false
	var file := FileAccess.open(lib.path, FileAccess.WRITE)
	file.store_string("{broken"); file.close()
	var state_before := s.read_state()
	check(lib.read_entry("manual/1").is_empty(), "corrupt library cannot load")
	check(not lib.write_entry("manual/1", s._day.state, s.definition, s.content_version, s._counter.catalog), "corrupt library cannot be overwritten")
	check(FileAccess.get_file_as_string(lib.path) == "{broken" and s.read_state() == state_before and lib.last_label == label, "corruption preserves source and current run")
