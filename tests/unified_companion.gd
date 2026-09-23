extends "res://tests/run_aqi_companion.gd"

var dream_sleep := false

func run() -> void:
	if aqi_manifest == "res://data/aqi_companion_manifest.json":
		aqi_manifest = "res://data/unified_manifest.json"
		aqi_fixture_dir = "res://.godot/qa/unified-companion/"
	super.run()

func act(s: RunSession, command: String) -> void:
	if dream_sleep and command == "finish_sleep":
		check(s._day.state.phase in [&"pre_open", &"run_ended"], "dream choice completed sleep")
		return
	if dream_sleep and command == "continue_run":
		dream_sleep = false
		return
	super.act(s,command)
	if command == "sleep" and s._day.state.pending_event_id == MirrorDreamService.CALL:
		dream_sleep = true
