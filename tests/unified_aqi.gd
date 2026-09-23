extends "res://tests/run_aqi_companion.gd"

var inline_sleep := false

func run() -> void:
	aqi_manifest = "res://data/unified_manifest.json"
	aqi_fixture_dir = "res://.godot/qa/unified-aqi/"
	super.run()

func act(s: RunSession, command: String) -> void:
	if inline_sleep and command == "finish_sleep": return
	if inline_sleep and command == "continue_run":
		inline_sleep = false
		return
	super.act(s,command)
	if command != "sleep" or s._day.state.pending_event_id != MirrorDreamService.CALL: return
	check(s.event_command(MirrorDreamService.CALL,"inspect").ok,"crying coexists with Aqi route")
	check(s.event_command(MirrorDreamService.EVENT,"wake").ok,"dream with companion enabled")
	check(s.event_command(MirrorDreamService.MORNING,"rise").ok,"morning resumes combined campaign")
	verify(s,"dream during Aqi playthrough")
	inline_sleep = true
