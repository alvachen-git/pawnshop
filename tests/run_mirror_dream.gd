extends "res://tests/run_mirror_reunion.gd"

class FailingStore extends GhostReplayStore:
	var fail := true
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		return not fail

func run() -> void:
	reunion_manifest = "res://data/mirror_dream_manifest.json"
	reunion_fixture_dir = "res://.godot/qa/v28/"
	super.run()

func aqi_story(s: RunSession, _route: String) -> void:
	check(s.event_model().pending_id == "aq_ledger", "Aqi and mirror dream keep independent events")
	driver.drain(s)

func act(s: RunSession, command: String) -> void:
	if command == "finish_sleep" and s._day.state.phase == &"day_summary" and s._day.state.current_night_index == 4:
		check(not s.execute(command).ok, "dream already completed sleep; duplicate wake rejected")
		fixture(s, "after")
		return
	super.act(s, command)
	if command == "enter_room" and s._day.state.current_night_index == 4: fixture(s, "bedtime")
	if command != "sleep": return
	if s._day.state.current_night_index == 3:
		check(s._day.state.pending_event_id != MirrorDreamService.EVENT, "no dream on acquisition night")
	if s._day.state.pending_event_id != MirrorDreamService.EVENT: return
	check(s._day.state.current_night_index == 4, "night after actual mirror purchase")
	fixture(s, "dream")
	verify(s, "unfinished dream")
	check(not s.can_execute("finish_sleep") and not s.can_execute("continue_run"), "unfinished dream blocks date advance")
	check(MirrorDreamService.FLAG not in s._day.state.narrative_flags, "offering dream grants no fact")
	var before := s.read_state()
	for i in 3: s.event_model(); s.risk_model()
	check(before == s.read_state(), "read projections never complete dream")
	var store := s._save
	var failure := FailingStore.new(); s._save = failure
	check(not s.event_command(MirrorDreamService.EVENT, "wake").ok, "dream save failure reported")
	check(before == s.read_state(), "dream and entire sleep atomically rolled back")
	s._save = store
	eligibility_edges(s)
	var data := SaveCodec.new().encode(s._day.state, 28)
	var forged := data.duplicate(true)
	for posting in forged.ledger_entries:
		if posting.kind == "acquisition" and posting.item_instance_id == LivingMirror.held(s._day.state).instance_id: posting.night = 4
	check(SaveCodec.new().decode(forged, run_def, 28, catalog, true) == null, "forged acquisition date rejected")
	var before_flags := s._day.state.narrative_flags.duplicate()
	var cash := s._day.state.cash
	var minute := s._day.state.game_minutes
	var damage := s._day.state.personal_damage
	check(s.event_command(MirrorDreamService.EVENT, "wake").ok, "wake completes in one action")
	check(s._day.state.phase == &"day_summary", "no second sleep confirmation")
	check(s._day.state.cash == cash and s._day.state.game_minutes == minute and s._day.state.personal_damage == damage, "dream has no cost or harm")
	before_flags.append(MirrorDreamService.FLAG)
	check(before_flags == s._day.state.narrative_flags, "dream grants only its own record")
	check(s._day.state.event_history.count(s._day.state.event_history.back()) == 1, "one dream record")
	verify(s, "dream completed")
	forged = SaveCodec.new().encode(s._day.state, 28)
	forged.event_history.append(forged.event_history.back().duplicate(true))
	check(SaveCodec.new().decode(forged, run_def, 28, catalog, true) == null, "duplicate dream record rejected")
	check(not s.event_command(MirrorDreamService.EVENT, "wake").ok, "wake cannot repeat")

func eligibility_edges(s: RunSession) -> void:
	var state := RunSnapshot.copy(s._day.state)
	var item := LivingMirror.held(state)
	state.soul_history.clear()
	state.mirror_history.clear()
	check(MirrorDreamService.eligible(state), "covered unused mirror permits dream")
	item.ownership_state = "sold"
	check(not MirrorDreamService.eligible(state), "sold mirror prevents dream")
	item.ownership_state = "owned"
	state.risk_pending = item.instance_id
	check(not MirrorDreamService.eligible(state), "crisis precedes dream")
	state.risk_pending = ""; state.phase = &"dead"
	check(not MirrorDreamService.eligible(state), "death prevents dream")
	state.phase = &"sleep_resolution"; state.current_night_index = 10
	for row in state.ledger_entries:
		if row.item_instance_id == item.instance_id and row.kind == "acquisition": row.night = 10
	check(not MirrorDreamService.eligible(state), "night ten acquisition remains pending")
	state.current_night_index = 11
	check(MirrorDreamService.eligible(state), "eligibility uses relative acquisition date")
	check(s.definition.total_nights == 10, "no eleventh playable night")
	coexistence(s)

func coexistence(source: RunSession) -> void:
	# Focused lifecycle scenarios start at an otherwise valid dream-night bedtime.
	# These constructed crises exercise ordering; full journeys above verify replay.
	for lethal in [false, true]:
		var s := fresh23()
		s._day.state = RunSnapshot.copy(source._day.state)
		var state := s._day.state
		state.phase = &"private_room"
		state.pending_event_id = ""; state.pending_event_minute = -1
		var mirror := LivingMirror.held(state)
		state.mirror_history.append({"encounter_id": run_def.mirror_encounters[0].id, "visit_id": "dream-conflict", "mirror_id": mirror.instance_id, "night": 4, "minute": 530, "action": "pursue", "prior_actions": []})
		PersonalRisk.damage(state, "mirror/dream-conflict", 1, "test pursuit", "mirror")
		PersonalRisk.damage(state, "wet_cloth/dream-conflict", 1, "test wet cloth", "wet_cloth")
		if lethal: PersonalRisk.damage(state, "prior-injury", 1)
		var damage := state.personal_damage
		check(s.execute("sleep").ok, "sleep accepts coexisting prior harms")
		check(not state.risk_pending.is_empty() and state.pending_event_id.is_empty(), "personal crisis precedes dream in same sleep")
		check(s.risk_command("defy" if lethal else "retreat", mirror.instance_id).ok, "resolve personal crisis before dream")
		if lethal:
			check(state.phase == &"dead" and state.pending_event_id.is_empty(), "lethal crisis never offers dream")
			check(not s.event_command(MirrorDreamService.EVENT, "wake").ok, "dead player cannot complete dream")
		else:
			check(state.pending_event_id == MirrorDreamService.EVENT, "surviving crisis immediately offers same-night dream")
			check(s.event_command(MirrorDreamService.EVENT, "wake").ok, "wake after crisis completes sleep")
			check(state.phase == &"day_summary" and state.personal_damage == damage, "dream neither adds nor heals existing harms")
