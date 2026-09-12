extends "res://tests/run_personal_risk.gd"

const TRANSFER := "res://.artifacts/keepsakes-transfer/"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/life_lamp_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", "life_lamp_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	if "process-read" in OS.get_cmdline_user_args():
		var files := DirAccess.get_files_at(TRANSFER)
		check(files.size() >= 6, "cross process fixtures exist")
		for file in files:
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRANSFER + file))
			var state := SaveCodec.new().decode(data, run_def, 22, catalog)
			check(state != null, "independent process restores " + file)
		print("KEEPSAKES CROSS PROCESS: %d passes, %d failures" % [passes, failures])
		quit(0 if failures == 0 else 1)
		return
	for placed in [false, true]: scenario(placed)
	compatibility()
	print("ROOM KEEPSAKES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func scenario(placed: bool) -> void:
	var s := fresh("keepsakes_" + str(placed))
	var before := s.read_state()
	check(RoomKeepsakes.read_model(s._day.state).letters.is_empty(), "no letter before received")
	check(not s.execute("photo_place").ok and s.read_state() == before, "opening blocks placement without journal growth")
	driver.open(s)
	var visit := s._counter.customers.active(s._day.state)
	check(s.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "tutorial purchase")
	driver.drain(s)
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]: driver.action(s, action)
	check(not RoomKeepsakes.available(s._day.state), "opening room narrative blocks free interaction")
	for choice in (["photo", "letter", "lamp"] if placed else ["letter", "lamp"]):
		check(s.event_command("evt_intro_room_first_night", choice).ok, "opening choice " + choice)
	legacy(s, "intro_" + str(placed))
	check(s.event_command("evt_intro_room_first_night", "settled").ok, "opening room settled")
	check(RoomKeepsakes.photo_placed(s._day.state) == placed, "inherit opening choice")
	legacy(s, "settled_" + str(placed))
	var flags := s._day.state.narrative_flags.duplicate()
	before = s.read_state()
	for i in 5:
		var model := RoomKeepsakes.read_model(s._day.state)
		check(model.letters.size() == 1 and model.letters[0].id == "gu_jingtang", "only received Gu letter")
	check(s.read_state() == before, "rereading does not mutate state")
	if not placed: check(s.execute("photo_place").ok, "place initially unplaced photograph")
	var library := SaveLibrary.new("res://.godot/keepsakes-%d.json" % Time.get_ticks_usec())
	s._save.library = library
	check(s.execute("photo_store").ok, "store and autosave")
	check(not RoomKeepsakes.photo_placed(s._day.state) and s._day.state.narrative_flags == flags, "hide without rewriting opening flags")
	var stored := s.read_state()
	var bytes := FileAccess.get_file_as_bytes(library.path)
	check(not s.execute("photo_store").ok and stored == s.read_state(), "duplicate command does not append journal")
	check(bytes == FileAccess.get_file_as_bytes(library.path), "duplicate command never publishes")
	check(s.load_checkpoint().ok and s._day.state.room_photo_position == "drawer", "auto restore stored photograph")
	stored = s.read_state()
	library.fail_write = true
	check(not s.execute("photo_place").ok and stored == s.read_state(), "save failure rolls back photo and transcript")
	check(bytes == FileAccess.get_file_as_bytes(library.path), "failed save preserves file bytes")
	library.fail_write = false
	check(s.execute("photo_place").ok and s._risk_error.is_empty(), "retry commits and clears error")
	check(library.write_entry("manual/1", s._day.state, run_def, 22, catalog), "manual saves placed photo")
	check(s.execute("photo_store").ok, "store after manual snapshot")
	var decoded := library.read_entry("manual/1")
	check(not decoded.is_empty() and library.adopt(decoded, s), "manual restore succeeds")
	check(RoomKeepsakes.photo_placed(s._day.state), "manual restores its own photo position")
	var after := s.read_state()
	for key in before:
		if key not in ["room_photo_position", "action_journal", "run_token"]:
			check(before[key] == after[key], "keepsake actions leave unchanged " + key)
	for phase in [&"sleep_resolution", &"dead", &"bankrupt", &"shop_resolution", &"open"]:
		var saved_phase := s._day.state.phase
		s._day.state.phase = phase
		var blocked := s.read_state()
		check(not s.execute("photo_store").ok and s.read_state() == blocked, "blocked during " + phase)
		s._day.state.phase = saved_phase
	for pending in ["pending_event_id", "risk_pending"]:
		s._day.state.set(pending, "test")
		var blocked := s.read_state()
		check(not s.execute("photo_store").ok and s.read_state() == blocked, "pending blocks " + pending)
		s._day.state.set(pending, "")
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, 22)
	for value in ["drawer", "", "unknown", 3, null]:
		var bad := payload.duplicate(true)
		bad.room_photo_position = value
		check(codec.decode(bad, run_def, 22, catalog) == null, "tampered placement rejected " + str(value))
	var missing := payload.duplicate(true)
	missing.erase("room_photo_position")
	check(codec.decode(missing, run_def, 22, catalog) == null, "cannot erase new field when new commands exist")
	write_transfer("placed_" + str(placed), payload)
	check(s.execute("photo_store").ok, "store for overnight")
	driver.action(s, "sleep")
	driver.drain(s)
	driver.action(s, "finish_sleep")
	driver.action(s, "continue_run")
	check(s._day.state.current_night_index == 2 and s._day.state.room_photo_position == "drawer", "next day retains stored photo")
	write_transfer("next_day_" + str(placed), codec.encode(s._day.state, 22))
	driver.open(s)
	for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]: driver.action(s, action)
	driver.drain(s)
	check(RoomKeepsakes.available(s._day.state) and not RoomKeepsakes.photo_placed(s._day.state), "next bedroom retains state and interaction")
	check(s.execute("photo_place").ok, "can place again next night")

func legacy(s: RunSession, name: String) -> void:
	var payload := SaveCodec.new().encode(s._day.state, 22)
	payload.erase("room_photo_position")
	var file := FileAccess.open(s._save.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(s._save.path)
	var restored := s._save.load_state(run_def, 22)
	check(restored != null and RoomKeepsakes.photo_placed(restored) == RoomKeepsakes.photo_placed(s._day.state), "released v22 reads " + name)
	check(bytes == FileAccess.get_file_as_bytes(s._save.path), "load does not rewrite old file")
	var library := SaveLibrary.new("res://.godot/legacy-keepsakes-%d.json" % Time.get_ticks_usec())
	var entry := {"format": 1, "saved_at": "2026-09-12T00:00:00", "payload": payload}
	check(library._publish({"format": 1, "entries": {"auto/life_lamp_seven": entry, "manual/1": entry}, "death_archive": [], "bankruptcy_archive": []}), "prepare released library fixture")
	bytes = FileAccess.get_file_as_bytes(library.path)
	for key in ["auto/life_lamp_seven", "manual/1"]:
		var decoded := library.read_entry(key)
		check(not decoded.is_empty(), "released library decodes " + key)
		var target := fresh("legacy_target")
		check(library.adopt(decoded, target) and RoomKeepsakes.photo_placed(target._day.state) == RoomKeepsakes.photo_placed(s._day.state), "released library adopts " + key)
	check(bytes == FileAccess.get_file_as_bytes(library.path), "loading old library leaves original bytes unchanged")
	write_transfer(name, payload)

func write_transfer(name: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRANSFER))
	var file := FileAccess.open(TRANSFER + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
