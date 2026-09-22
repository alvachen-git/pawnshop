extends "res://tests/run_living_mirror.gd"

const Fixture = preload("res://tests/living_fixture.gd")

func run() -> void:
	catalog = JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	var s := Fixture.before(catalog, func(session: RunSession, row: Dictionary) -> bool: return session._day.state.current_night_index == 5 and row.method == "execute" and row.args[0] == "prep_finish")
	var store := SaveManager.new("res://.godot/qa/v22/live_save.json")
	store.catalog = catalog
	s._save = store
	var before := Time.get_ticks_msec()
	check(s.execute("open_shop").ok, "implicit preparation commits with real disk save")
	check(store.load_state(run_def, 22) != null, "saved preparation can replay")
	print("V22 pre-open write/read ms: ", Time.get_ticks_msec() - before)
	var state := SaveCodec.new().decode(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v22/night6.json")), run_def, 22, catalog)
	check(state != null, "real seventh opening fixture")
	if state == null: quit(1); return
	var lib := SaveLibrary.new("res://.godot/qa/v22/library_%d.json" % Time.get_ticks_usec())
	check(lib.write_entry("manual/1", state, run_def, 22, catalog), "manual v22 write")
	var decoded := lib.read_entry("manual/1")
	check(not decoded.is_empty(), "manual v22 read")
	var source_token := state.run_token
	check(lib.adopt(decoded, s), "adopt with new run token")
	check(s._day.state.run_token != source_token, "independent loaded attempt")
	check(lib.write_entry("manual/2", s._day.state, run_def, 22, catalog), "new token replay remains valid")
	var old_bytes := FileAccess.get_file_as_string(lib.path)
	lib.fail_write = true
	check(not lib.write_entry("manual/3", s._day.state, run_def, 22, catalog), "failed library write")
	check(FileAccess.get_file_as_string(lib.path) == old_bytes, "failed library publish retains prior file")
	var snapshot := s.read_state()
	for i in 3: s.event_model(); s.risk_model(); s.counter_model(); s.seven_notice()
	check(GhostSaveCodec.same(snapshot, s.read_state()), "repeated views neither deliver nor kill again")
	# At activation, a dead individual is skipped; another person sharing the profession remains.
	var same_person := CustomerVisit.new()
	same_person.visit_id = "dead-person-unit"; same_person.customer_id = state.pawn_tickets[0].customer_id
	same_person.person = {"id": state.person_deaths[0].person_id}; same_person.status = "active"
	GhostGuests.arrive(s._day.state, same_person)
	check(same_person.status == "person_deceased", "specific dead person cannot return")
	var other := CustomerVisit.new(); other.visit_id = "other-person-unit"; other.customer_id = same_person.customer_id
	other.person = {"id": "another-person"}; other.status = "active"
	GhostGuests.arrive(s._day.state, other)
	check(other.status == "active", "profession is not killed")
	print("LIVING SAVE CHECKPOINTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
