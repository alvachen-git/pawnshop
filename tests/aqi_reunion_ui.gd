extends "res://tests/aqi_companion_ui.gd"

func _run() -> void:
	aqi_manifest = "res://data/aqi_reunion_manifest.json"
	aqi_version = 27
	aqi_fixture_dir = "res://.godot/qa/v27-aqi/"
	await super._run()
