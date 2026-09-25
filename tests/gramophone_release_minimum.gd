extends "res://tests/luxury_minimum.gd"

func setup() -> bool:
	return setup_catalog("res://data/gramophone_release_manifest.json")

func fresh_growth(seed_value := 42) -> RunSession:
	var s := super.fresh_growth(seed_value)
	s._day.state.narrative_flags.append(PawnInterestPolicy.FLAG)
	return s
