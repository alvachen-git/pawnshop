extends "res://tests/run_aqi_companion.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/aqi_companion_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog")
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	for stage in ["aq-room-2", "pre-open-7", "example-aq_arrival", "example-aq_return_helped", "example-aq_stay_8", "idle-8", "idle-9", "idle-10", "example-aq_old_ticket"]:
		var s := restored_stage(stage)
		if s == null: quit(1); return
		if stage == "pre-open-7": check(s.execute("prep_finish").ok, "prepare before testing opening write itself")
		var lib := SaveLibrary.new("res://.godot/qa/v25/durable-%d.json" % Time.get_ticks_usec())
		var store := SaveManager.new("res://.godot/qa/v25/unused.json")
		store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/aqi_companion_ten", s._day.state, run_def, 25, catalog), "write auto " + stage)
		check(not lib.save_reason(s._day.state).is_empty() if s._day.state.phase == &"open" else true, "manual still blocked in business")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		lib.fail_write = true
		var failed := submit(s, stage)
		check(not failed.ok and "重试" in failed.message and before == s.read_state(), "atomic failure " + stage)
		check(bytes == FileAccess.get_file_as_bytes(lib.path), "prior disk survives " + stage)
		lib.fail_write = false
		check(submit(s, stage).ok, "retry " + stage)
		var saved := lib.read_entry("auto/aqi_companion_ten")
		check(not saved.is_empty(), "auto readable " + stage)
		if not saved.is_empty(): check(GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "auto exact " + stage)
		before = s.read_state()
		if stage not in ["pre-open-7", "aq-room-2"]:
			var id: String = "aq_chat_" + stage.trim_prefix("idle-") if stage.begins_with("idle-") else String(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v25/" + stage + ".json")).pending_event_id)
			var event := catalog.get_definition("events", id) as EventDefinition
			check(not s.event_command(id, event.choices[0].id).ok and before == s.read_state(), "duplicate checkpoint " + stage)
	var s := restored_stage("idle-8")
	for flag in ["aq_ticket_seen", "aq_ticket_compared", "aq_left_8"]:
		var raw := SaveCodec.new().encode(s._day.state, 25); raw.narrative_flags.append(flag)
		check(SaveCodec.new().decode(raw, run_def, 25, catalog, true) == null, "forged " + flag)
	s = restored_stage("example-aq_stay_8")
	var forged := SaveCodec.new().encode(s._day.state, 25)
	forged.narrative_flags.append("aq_companion_allowed"); forged.narrative_flags.append("aq_seated")
	forged.pending_event_id = ""; forged.pending_event_minute = -1
	check(SaveCodec.new().decode(forged, run_def, 25, catalog, true) == null, "invented permission rejected")
	s = restored_stage("example-aq_arrival")
	forged = SaveCodec.new().encode(s._day.state, 25)
	forged.phase = "private_room"; forged.game_minutes = 540; forged.pending_event_id = ""; forged.pending_event_minute = -1
	check(SaveCodec.new().decode(forged, run_def, 25, catalog, true) == null, "skip arrival to room rejected")
	boundaries()
	print("AQI V25 DURABILITY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func restored_stage(stage: String) -> RunSession:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v25/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(raw, run_def, 25, catalog, true)
	check(state != null, "fixture " + stage + ": " + codec.error_message)
	if state == null: return null
	var store := GhostReplayStore.new(); store.origin = raw.ghost_origin
	var s := RunSession.new(run_def, 25, store, catalog); s._day.state = state
	return s

func submit(s: RunSession, stage: String) -> ActionResult:
	if stage == "pre-open-7": return s.execute("open_shop")
	if stage == "aq-room-2": return s.observe_room("aq_coat")
	if stage.begins_with("idle-"): return s.event_command("aq_chat_" + stage.trim_prefix("idle-"), "talk")
	var m := s.event_model()
	return s.event_command(m.pending_id, m.buttons[0].detail)

func boundaries() -> void:
	var s := restored_stage("idle-8")
	for step in 100:
		if s._day.state.game_minutes >= 235: break
		driver.drain(s)
		var v := s._counter.customers.active(s._day.state)
		if v != null: check(s.counter_command("reject", v.visit_id).ok, "clear customer before boundary")
		else: check(s.execute("short_task").ok, "clock advances normally")
	check(s._day.state.game_minutes == 235 and s.companion_model().visible, "21:55 present")
	fixture(s, "2155")
	var before := s._day.state.event_history.size()
	check(s.execute("short_task").ok, "cross 22 action completes")
	check(s._day.state.game_minutes == 240 and not s.companion_model().visible, "22:00 absent")
	check(s._day.state.event_history.size() == before, "no automatic farewell event")
	verify(s, "2200")
	fixture(s, "2200")
	s = restored_stage("customer-8")
	while s._day.state.game_minutes < 235: check(s.execute("short_task").ok, "wait with live customer to 2155")
	var customer := s._counter.customers.active(s._day.state)
	check(customer != null and s.companion_model().visible, "customer and Aqi before boundary")
	if customer != null:
		var cash := s._day.state.cash
		check(s.counter_command("appraise", customer.visit_id, "observe").ok, "real appraisal crosses 22 without interruption")
		check(s._day.state.game_minutes >= 240 and not s.companion_model().visible and s._day.state.cash == cash, "appraisal completes; companion leaves free")
		check(s._counter.customers.active(s._day.state) != null, "customer reception survives companion departure")
		verify(s, "appraisal across 22")
	s = restored_stage("idle-8")
	check(s.execute("close_shop").ok and not s.companion_model().visible, "early closing leaves")
	verify(s, "early closing")
	s = restored_stage("idle-8")
	# Read-model death suppression: risk gameplay itself remains covered by frozen regression.
	s._day.state.phase = &"dead"
	check(not s.companion_model().visible and not s.companion_model().available, "death immediately hides companion")
