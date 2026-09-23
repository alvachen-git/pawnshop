extends "res://tests/unified_companion.gd"

func run() -> void:
	aqi_manifest = "res://data/tiered_manifest.json"
	aqi_fixture_dir = "res://.godot/qa/precision-companion/"
	super.run()
