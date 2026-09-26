extends "res://tests/pawn_interest.gd"

func manifest_path() -> String:
	return "res://data/town_life_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/town-life-pawn/"

func setup() -> bool:
	if not super.setup(): return false
	driver = preload("res://tests/town_life_driver.gd").new()
	driver.check = check; driver.catalog = catalog
	return true
