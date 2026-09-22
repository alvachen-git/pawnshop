extends "res://tests/run_integrated_seven.gd"

class FailingStore extends GhostReplayStore:
	var writes := 0
	func save_state(_state: RunState, _run: RunDefinition, _version: int) -> bool:
		writes += 1
		error_message = "模拟写盘失败"
		return false

func load_stage(stage: String) -> RunSession:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/" + stage + ".json"))
	var replay := GhostReplayStore.new(); replay.origin = data.ghost_origin
	var s := RunSession.new(run_def, 23, replay, catalog)
	s._day.state = SaveCodec.new().decode(data, run_def, 23, catalog, true)
	return s

func run() -> void:
	catalog = JsonContentProvider.new("res://data/mirror_investigation_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var s := load_stage("commission")
	var saved := RunSnapshot.copy(s._day.state)
	s._day.state.cash = 29
	var before := s.read_state()
	check(not s.investigation_command("commission").ok and s.read_state() == before, "insufficient cash no mutation")
	s._day.state = RunSnapshot.copy(saved); s._day.state.game_minutes = 530
	before = s.read_state()
	check(not s.investigation_command("commission").ok and s.read_state() == before, "must finish before close")
	s._day.state = RunSnapshot.copy(saved); s._day.state.narrative_flags.erase("wm_concealed")
	before = s.read_state()
	check(not s.investigation_command("commission").ok and s.read_state() == before, "evidence required")
	s = load_stage("meeting")
	var visit := s._counter.customers.active(s._day.state)
	var id := visit.visit_id
	s._day.state.game_minutes = visit.expires_at - 5
	var start := s._day.state.game_minutes
	check(not s.counter_command("meeting_question", id, "business").ok, "expires mid question")
	check(s._day.state.game_minutes == start + 5 and s._day.state.investigation.answers.is_empty(), "time retained no invented answer")
	check(InvestigationService.appointment(s._day.state).status == "missed", "expired appointment recorded")
	check(s.investigation_command("book").ok and InvestigationService.appointment(s._day.state).night == 11, "late rebooking")
	s = load_stage("report")
	s.investigation_command("read_report")
	before = s.read_state()
	s.investigation_command("read_report")
	var after := s.read_state(); before.erase("action_journal"); after.erase("action_journal")
	check(before == after, "rereading costs nothing and adds no facts")
	# Every meaningful derived field must be reproduced by the public transcript.
	for stage in ["commission", "report", "meeting", "ending"]:
		s = load_stage(stage)
		var data := SaveCodec.new().encode(s._day.state, 23)
		for field in ["cash", "personal_damage", "ghost_origin", "investigation"]:
			var forged := data.duplicate(true)
			if field in ["cash", "personal_damage"]: forged[field] += 1
			elif field == "ghost_origin": forged[field].run_token = "ffffffffffffffffffffffffffffffff"
			else: forged.investigation["payment_id"] = "forged"
			check(SaveCodec.new().decode(forged, run_def, 23, catalog, true) == null, "forged " + stage + "/" + field)
		if data.investigation.has("report_night"):
			for field in ["report_night", "accepted_night", "delivered", "read", "answers", "appointments"]:
				var forged := data.duplicate(true)
				if field in ["report_night", "accepted_night"]: forged.investigation[field] += 1
				elif field in ["delivered", "read"]: forged.investigation[field] = not forged.investigation[field]
				else: forged.investigation[field] = [{"id": "invented"}]
				check(SaveCodec.new().decode(forged, run_def, 23, catalog, true) == null, "forged commission field " + field)
	# A failed date checkpoint restores the report, appointments, cash and all visits.
	s = load_stage("report")
	s.investigation_command("read_report"); s.investigation_command("book")
	s.execute("close_shop"); s.execute("wait_until_seal"); s.execute("resolve_night")
	before = s.read_state()
	var store := FailingStore.new(); s._save = store
	check(not s.execute("enter_room").ok, "checkpoint failure reported")
	check(s.read_state() == before and store.writes == 1, "one write and complete rollback")
	# Capture the real third-night encounter before it was declined in the fixture.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/ending.json"))
	var replay_store := GhostReplayStore.new(); replay_store.origin = data.ghost_origin
	s = RunSession.new(run_def, 23, replay_store, catalog)
	for row in data.action_journal:
		var v := s._counter.customers.active(s._day.state)
		if v != null and v.customer_id == "mirror_husband" and row.method == "counter_command" and row.args[0] == "reject": break
		s.callv(row.method, row.args)
	check(s.mirror_command("midnight_old_ticket", "peek").ok, "real old memory")
	before = s.read_state(); store = FailingStore.new(); s._save = store
	check(not s.mirror_command("midnight_old_ticket", "pursue").ok, "harm checkpoint failure")
	check(s.read_state() == before and store.writes == 1, "harm rollback one journal no nested disk write")
	s._save = GhostReplayStore.new()
	check(s.mirror_command("midnight_old_ticket", "pursue").ok and s._day.state.personal_damage == 1, "integrated personal injury")
	check(PersonalRisk.damage(s._day.state, "mirror/" + s._counter.customers.active(s._day.state).visit_id, 1) == 0, "event injury dedup")
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(s._day.state, 23), run_def, 23, catalog, true) != null, "harm autosave exact replay")
	var mirror := LivingMirror.held(s._day.state)
	s.risk_command("cover", mirror.instance_id)
	s.execute("close_shop"); s.execute("wait_until_seal"); s.execute("resolve_night")
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	s.execute("enter_room"); driver.drain(s)
	check(BedroomMirrorFeedback.build(s._day.state).get("mode", "") == "shadow", "v23 bedroom shadow from pending pursuit")
	s.execute("sleep"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	check(BedroomMirrorFeedback.build(s._day.state).is_empty() and s._day.state.personal_damage == 1, "response removes shadow but does not heal lamp")
	replay_store = GhostReplayStore.new(); replay_store.origin = data.ghost_origin
	s = RunSession.new(run_def, 23, replay_store, catalog)
	for row in data.action_journal:
		var v := s._counter.customers.active(s._day.state)
		if v != null and v.night_policy == "wet_cloth" and row.method == "counter_command" and row.args[0] == "reject": break
		s.callv(row.method, row.args)
	visit = s._counter.customers.active(s._day.state)
	check(visit != null and visit.night_policy == "wet_cloth", "real wet guest fixture")
	check(s.counter_command("question", visit.visit_id, "origin").ok and s._day.state.personal_damage == 1, "v23 wet taboo injures personal lamp")
	check(NightMarketRisk.after_command(s._day.state, visit, "question", "origin").is_empty() and s._day.state.personal_damage == 1, "wet incident dedup")
	var disk := SaveManager.new("res://.godot/qa/v23/actual_harm.json"); disk.catalog = catalog
	check(disk.save_state(s._day.state, run_def, 23), "real harm save write " + disk.error_message)
	check(disk.load_state(run_def, 23) != null, "real harm save load " + disk.error_message)
	mirror = LivingMirror.held(s._day.state)
	if mirror != null: s.risk_command("cover", mirror.instance_id)
	s.execute("close_shop")
	check(s.execute("seal_cloth/" + visit.visit_id).ok and s._day.state.personal_damage == 1, "sealing wet cloth does not heal")
	print("INVESTIGATION EDGES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
