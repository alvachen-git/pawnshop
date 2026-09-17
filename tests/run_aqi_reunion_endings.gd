extends "res://tests/run_mirror_reunion.gd"

func run() -> void:
	reunion_manifest = "res://data/aqi_reunion_manifest.json"
	reunion_fixture_dir = "res://.godot/qa/v27-reunion/"
	super.run()

func aqi_story(s: RunSession, _route: String) -> void:
	check(s.event_model().pending_id == "aq_ledger", "seventh close keeps ledger separate from daytime arrival")
	check("aq_met" in s._day.state.narrative_flags, "daytime arrival already completed")
	driver.drain(s)
