extends "res://tests/run_first_debt.gd"

func recovery_manifest() -> String:
	return "res://data/first_debt_recovery_manifest.json"

func recovery_version() -> int:
	return 40

func load_stage(stage: String, route_suffix := "") -> RunSession:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v%d" % recovery_version() + route_suffix + "/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(raw, run_def, recovery_version(), catalog, true)
	check(state != null, "restore " + stage + ": " + codec.error_message)
	if state == null: return null
	var store := GhostReplayStore.new(); store.origin = raw.ghost_origin
	var s := RunSession.new(run_def, recovery_version(), store, catalog); s._day.state = state
	return s

func run() -> void:
	var loaded := JsonContentProvider.new(recovery_manifest()).load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for spec in [["first-seller", "counter_command", ["reject", "ACTIVE"], ""], ["seller", "counter_command", ["offer", "ACTIVE", "", 100], ""], ["hint", "event_command", [PhoenixRecovery.HINT, "heard"], ""], ["phoenix-prep", "execute", ["prep_phoenix_invite"], ""], ["before-fd_truth", "event_command", ["fd_truth", "tell"], ""], ["before-fd_compensation", "event_command", ["fd_compensation", "offer"], "-pay"], ["before-fd_settle", "event_command", ["fd_settle", "pay"], "-pay"]]:
		var s := load_stage(spec[0], spec[3])
		if s == null: quit(1); return
		if spec[1] == "counter_command": spec[2][1] = s._counter.customers.active(s._day.state).visit_id
		var lib := SaveLibrary.new("res://.godot/qa/v%d" % recovery_version() + "/durable-" + spec[0] + ".json")
		lib.register_catalog(recovery_manifest(), catalog)
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/" + String(run_def.id), s._day.state, run_def, recovery_version(), catalog), "initial write")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		lib.fail_write = true
		check(not s.callv(spec[1], spec[2]).ok and before == s.read_state() and bytes == FileAccess.get_file_as_bytes(lib.path), "failed write rolls back " + spec[0])
		lib.fail_write = false
		check(s.callv(spec[1], spec[2]).ok, "retry " + spec[0])
		var saved := lib.read_entry("auto/" + String(run_def.id))
		check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "complete disk replay " + spec[0])
		before = s.read_state()
		check(not s.callv(spec[1], spec[2]).ok and before == s.read_state(), "duplicate " + spec[0])
		var file := FileAccess.open("res://.godot/qa/v%d" % recovery_version() + "/committed-" + spec[0] + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, recovery_version())))
	# Money boundaries are isolated domain probes, never accepted as legal saves.
	for cash in [299, 300]:
		var s := load_stage("before-fd_settle", "-pay")
		s._day.state.cash = cash
		var minute := s._day.state.game_minutes
		check(s.event_command("fd_settle", "pay").ok == (cash == 300), "compensation boundary " + str(cash))
		check(s._day.state.cash == (0 if cash == 300 else 299), "exact cash")
		check(s._day.state.game_minutes == minute + (5 if cash == 300 else 0), "pay alone costs five minutes")
	# Shared preparation cap; closures retain the paid appointment.
	var s := load_stage("phoenix-prep")
	check(s.execute("prep_visitors").ok and s.execute("prep_tea").ok, "use shared preparations")
	check(not s.execute("prep_phoenix_invite").ok, "cannot exceed two preparations")
	s = load_stage("phoenix-invited")
	var n := s._day.state.current_night_index
	SocialRules.night(s._day.state).closed = true
	check(DragonSearch.appointment_night(s._day.state, "phoenix_invite") == n + 1, "military closure carries appointment")
	check(not s.execute("prep_phoenix_invite").ok, "cannot repay postponed booking")
	s._day.state.current_night_index += 1
	var rows := OpeningPreparation.plan(s._day.state, run_def, catalog).filter(func(r: Dictionary) -> bool: return r.night == n + 1)
	check(rows.filter(func(r: Dictionary) -> bool: return r.customer_id == "fd_seller").size() == 1, "one postponed seller")
	check(rows.filter(func(r: Dictionary) -> bool: return r.get("first_debt_appointment", false)).size() == 1, "independent appointment")
	# Aqi departure/absence, time and crisis capture cannot be retroactive.
	for mode in ["present", "absent", "dismissed", "2200", "crisis", "dead"]:
		s = load_stage("first-seller")
		var st := s._day.state
		var v := s._counter.customers.active(st)
		if mode == "absent": st.narrative_flags.erase("aq_seated")
		if mode == "dismissed": st.event_history.append({"event_id":"fd_aqi_leave", "choice_id":"bye", "night":st.current_night_index, "minute":st.game_minutes})
		if mode == "2200": st.game_minutes = 240
		var first := st.visit_history.size()
		s._counter.customers.finish(st, v, "rejected")
		if mode == "crisis": st.risk_pending = "test"
		if mode == "dead": st.phase = &"dead"
		PhoenixRecovery.capture(st, v.visit_id, first)
		check(PhoenixRecovery.hint_due(st) == (mode == "present"), "Aqi eligibility " + mode)
		if mode != "dead": check(PhoenixRecovery.available(st), "booking independent of Aqi " + mode)
		if mode == "crisis": st.risk_pending = ""; check(not PhoenixRecovery.hint_due(st), "no hint after resolving crisis")
	# Real failed negotiation and repeat visit retain a single hint and unique seller.
	s = load_stage("first-seller")
	var v := s._counter.customers.active(s._day.state)
	for i in 12:
		if v.status != "active": break
		s.counter_command("offer", v.visit_id, "", 1)
	check(v.status in ["patience_exhausted", "rounds_exhausted"], "failed bargaining leaves")
	check(PhoenixRecovery.hint_due(s._day.state) and PhoenixRecovery.available(s._day.state), "failed negotiation has recovery")
	verify(s, "failed bargaining")
	# Unread notifications are optional, survive intervening business this evening,
	# and expire with Aqi rather than becoming a global reception gate.
	s = load_stage("hint")
	check(s.companion_model().has("notification") and s.bell_model().enabled, "unread marker permits bell")
	var bell := s.bell_model()
	check(s.bell_command(bell.mode, bell.target_id).ok, "receive next guest without reading hint")
	check(not s.companion_model().has("notification"), "busy guest suppresses marker interaction")
	check(not s.event_command(PhoenixRecovery.HINT, "heard").ok, "cannot read hint during customer transaction")
	v = s._counter.customers.active(s._day.state)
	check(v != null and s.counter_command("reject", v.visit_id).ok, "business can finish with unread notification")
	check(s.companion_model().has("notification"), "marker returns in next idle gap")
	verify(s, "unread notification across business")
	check(s.event_command(PhoenixRecovery.HINT, "heard").ok, "read later during same evening")
	verify(s, "later notification acknowledgement")
	for boundary in [239, 240]:
		s = load_stage("hint"); s._day.state.game_minutes = boundary
		check(PhoenixRecovery.hint_due(s._day.state) == (boundary == 239), "notification22 boundary " + str(boundary))
	s = load_stage("hint"); s._day.state.current_night_index += 1
	check(not PhoenixRecovery.hint_due(s._day.state), "unread notification never carries to next night")
	# Repeated refusal / early close remain rebookable without repeating Aqi.
	for ended in ["rejected", "shop_closed"]:
		s = load_stage("seller")
		var recalled := s._counter.customers.active(s._day.state)
		var identity: String = recalled.person.id
		if ended == "rejected": check(s.counter_command("reject", recalled.visit_id).ok, "repeat refusal")
		check(not PhoenixRecovery.hint_due(s._day.state), "no repeated hint")
		driver.check = check; driver.catalog = catalog
		for command in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
			act(s, command); driver.drain(s)
		check(s.execute("prep_phoenix_invite").ok, "rebook after " + ended)
		var plan := OpeningPreparation.plan(s._day.state, run_def, catalog).filter(func(r: Dictionary) -> bool: return r.night == s._day.state.current_night_index)
		var booked := plan.filter(func(r: Dictionary) -> bool: return r.customer_id == "fd_seller")
		check(booked.size() == 1 and booked[0].person.id == identity and booked[0].arrival == 60, "same seller at19 once")
		check(plan.size() == 7 + ReputationService.adjustment(s._day.state.social.reputation), "appointment preserves six plus reputation")
		verify(s, "rebooking after " + ended)
	# No evidence knowledge is awarded for a failed purchase or a reminder.
	s = load_stage("first-seller"); v = s._counter.customers.active(s._day.state)
	s._day.state.cash = 99
	check(not s.counter_command("offer", v.visit_id, "", 100).ok, "insufficient phoenix funds")
	check(s.counter_command("reject", v.visit_id).ok and PhoenixRecovery.available(s._day.state), "insufficient then leave can rebook")
	check(not FirstDebt.flag(s._day.state, "fd_receipt_read") and not FirstDebt.flag(s._day.state, "fd_mark_read"), "hint awards no evidence")
	var raw := SaveCodec.new().encode(load_stage("phoenix-prep")._day.state, recovery_version())
	for kind in ["flag", "booking", "hint_gate"]:
		var bad := raw.duplicate(true)
		if kind == "flag": bad.narrative_flags.append("fd_phoenix_hint_seen")
		if kind == "booking": bad.preparation_history.append({"night": 13, "minute": 0, "action":"phoenix_invite", "category":"", "cost":0, "visit_ids":[], "change":{}})
		if kind == "hint_gate":
			for row in bad.event_history:
				if row.event_id == PhoenixRecovery.GATE: row.choice_id = "quiet"
		check(SaveCodec.new().decode(bad, run_def, recovery_version(), catalog, true) == null, "reject forged " + kind)
	print("RECOVERY DURABILITY: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(s._day.state, recovery_version()), run_def, recovery_version(), catalog, true) != null, label + " " + codec.error_message)
