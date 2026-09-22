extends "res://tests/run_aqi_companion.gd"

func run() -> void:
	aqi_manifest = "res://data/aqi_reunion_manifest.json"
	aqi_fixture_dir = "res://.godot/qa/v27-aqi/"
	super.run()
