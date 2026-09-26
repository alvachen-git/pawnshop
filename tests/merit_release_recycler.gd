extends "res://tests/recycler_sales.gd"

func manifest_path() -> String:
	return "res://data/first_debt_merit_release_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/merit-release-recycler/"

func expected_version() -> int:
	return 49
