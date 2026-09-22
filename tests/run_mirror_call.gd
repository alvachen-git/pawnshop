extends "res://tests/run_mirror_reunion.gd"

var call_policy := "first"
var inline_sleep := false
var refusal_count := 0

class FailingStore extends GhostReplayStore:
	func save_state(_s: RunState, _d: RunDefinition, _v: int) -> bool: return false

func run() -> void:
	reunion_manifest = "res://data/mirror_dream_call_manifest.json"
	reunion_fixture_dir = "res://.godot/qa/v29/"
	for issue in JsonContentProvider.new(reunion_manifest).load_catalog().issues: print(issue.format_message())
	super.run()

func aqi_story(s: RunSession, _route: String) -> void:
	driver.drain(s)

func entry_checks() -> void:
	super.entry_checks()
	call_policy = "never"; refusal_count = 0
	journey("ignore")
	check(refusal_count == 2, "exactly two consecutive nights then no further call")
	call_policy = "second"; refusal_count = 0
	journey("ignore")
	check(refusal_count == 1, "can inspect on second night")
	call_policy = "first"

func act(s: RunSession, command: String) -> void:
	if inline_sleep and command == "finish_sleep":
		check(s._day.state.phase in [&"pre_open", &"run_ended"], "inline sleep completed date transition")
		return
	if inline_sleep and command == "continue_run":
		inline_sleep = false; return
	super.act(s, command)
	if command == "enter_room" and s._day.state.current_night_index == 4: fixture(s, "bedtime")
	if command != "sleep": return
	if s._day.state.current_night_index == 3:
		check(s._day.state.pending_event_id != MirrorDreamService.CALL, "not on acquisition night")
	if s._day.state.pending_event_id != MirrorDreamService.CALL: return
	fixture(s, "second" if s._day.state.current_night_index == 5 else "call")
	verify(s, "door call")
	check(not s.event_command(MirrorDreamService.EVENT, "wake").ok, "cannot skip inspect decision")
	var before := s.read_state(); var store := s._save
	s._save = FailingStore.new()
	check(not s.event_command(MirrorDreamService.CALL, "ignore").ok, "ignore save failure")
	check(before == s.read_state(), "ignore rollback includes date and choice")
	check(not s.event_command(MirrorDreamService.CALL, "inspect").ok, "inspect save failure")
	check(before == s.read_state(), "inspect rollback grants no fact")
	s._save = store
	var edge := RunSnapshot.copy(s._day.state)
	var item := LivingMirror.held(edge)
	item.ownership_state = "sold"
	check(not MirrorDreamService.call_eligible(edge), "sold mirror prevents crying")
	item.ownership_state = "owned"; edge.risk_pending = item.instance_id
	check(not MirrorDreamService.call_eligible(edge), "crisis takes priority")
	edge.risk_pending = ""; edge.phase = &"dead"
	check(not MirrorDreamService.call_eligible(edge), "dead player hears no crying")
	edge.phase = &"sleep_resolution"; edge.current_night_index = 10
	for row in edge.ledger_entries:
		if row.kind == "acquisition" and row.item_instance_id == item.instance_id: row.night = 10
	check(not MirrorDreamService.call_eligible(edge), "night ten acquisition not rushed")
	check(s.definition.total_nights == 10, "no eleventh opening")
	var ignore := call_policy == "never" or (call_policy == "second" and s._day.state.current_night_index == 4)
	if ignore:
		refusal_count += 1
		check(s.event_command(MirrorDreamService.CALL, "ignore").ok, "ignore and sleep")
		check(MirrorDreamService.FLAG not in s._day.state.narrative_flags and MirrorDreamService.ENTERED not in s._day.state.narrative_flags, "refusing hears no story and grants no evidence")
		check(s._day.state.phase == &"pre_open", "refusal proceeds to next day")
		verify(s, "ignored call")
	else:
		check(s.event_command(MirrorDreamService.CALL, "inspect").ok, "inspect enters dream")
		check(not s.event_command(MirrorDreamService.CALL, "inspect").ok, "cannot double inspect")
		check(s._day.state.pending_event_id == MirrorDreamService.EVENT, "dream replaces call")
		check(MirrorDreamService.FLAG not in s._day.state.narrative_flags, "entry grants no heard story")
		fixture(s, "dream"); verify(s, "dream entered")
		before = s.read_state(); s._save = FailingStore.new()
		check(not s.event_command(MirrorDreamService.EVENT, "wake").ok, "wake save failure")
		check(before == s.read_state(), "wake rollback keeps dream pending")
		s._save = store
		check(s.event_command(MirrorDreamService.EVENT, "wake").ok, "dream finishes sleep")
		check(s._day.state.pending_event_id == MirrorDreamService.MORNING, "morning recollection before business")
		check(not s.execute("continue_run").ok, "cannot bypass morning")
		check(s._day.state.personal_damage == before.personal_damage and s._day.state.game_minutes == before.game_minutes, "no dream harm or business time cost")
		fixture(s, "morning"); verify(s, "morning")
		var forged := SaveCodec.new().encode(s._day.state, 29)
		for row in forged.event_history:
			if row.event_id == MirrorDreamService.CALL: row.choice_id = "ignore"
		check(SaveCodec.new().decode(forged, run_def, 29, catalog, true) == null, "forged inspect history rejected")
		before = s.read_state(); s._save = FailingStore.new()
		check(not s.event_command(MirrorDreamService.MORNING, "rise").ok, "morning save failure")
		check(before == s.read_state(), "morning rollback does not skip day")
		s._save = store
		check(s.event_command(MirrorDreamService.MORNING, "rise").ok, "morning continues once")
		check(not s.event_command(MirrorDreamService.MORNING, "rise").ok, "no repeated morning")
		verify(s, "morning complete")
	inline_sleep = true
