extends "res://tests/silver_market.gd"

func manifest_path() -> String:
	return "res://data/first_debt_merit_release_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/merit-release-silver/"

func expected_version() -> int:
	return 49
