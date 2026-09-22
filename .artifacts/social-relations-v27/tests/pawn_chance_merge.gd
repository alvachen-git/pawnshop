extends "res://tests/run_complete_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/pawn_chance_manifest.json").load_catalog()
	check(loaded.is_success(), "merged v20 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false; run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	cash_flow(); preview_cases()
	var old := JsonContentProvider.new("res://data/complete_seven_manifest.json").load_catalog().catalog
	var previous := old.get_definition("runs", old.default_run_id) as RunDefinition
	var session := RunSession.new(previous, 19, SaveManager.new("user://tests/merge_old.json"), old)
	var library := SaveLibrary.new("user://tests/merge_complete_%d.json" % Time.get_ticks_usec())
	check(library.write_entry("manual/1", session._day.state, previous, 19, old), "save upstream v19")
	var next := fresh("merge20"); next._save.library = library
	check(library.adopt(library.read_entry("manual/1"), next) and next.definition.id == "complete_seven", "restore upstream run identity")
	check(not CashFlowReadModel.build(next._day.state, next.definition).is_empty(), "old complete keeps presentation")
	check(not PawnRedemptionPolicy.enabled(next.definition), "old complete keeps original pawn policy")
	next.new_run()
	check(next.definition.id == "pawn_chance_seven" and PawnRedemptionPolicy.enabled(next.definition), "new game returns v20")
	print("PAWN CHANCE MERGE: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
