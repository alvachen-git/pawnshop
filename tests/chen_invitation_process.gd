extends "res://tests/run_first_debt.gd"
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for stage in ["help-invited", "help-uninvited", "later-invited", "later-departed", "returned"]:
		InvestigationSaveCodec.clear_cache()
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/chen-invitation/" + stage + ".json"))
		var codec := SaveCodec.new()
		var st := codec.decode(raw, run_def, 31, catalog, true)
		check(st != null, "fresh process " + stage + " " + codec.error_message)
		var bad: Dictionary = raw.duplicate(true)
		bad.action_journal.append({"method": "event_command", "args": ["fd_compensation", "offer"], "chen_visits": 1})
		check(SaveCodec.new().decode(bad, run_def, 31, catalog, true) == null, "reject forged absent or closed meeting")
		bad = raw.duplicate(true)
		bad.action_journal[-1].erase("chen_visits")
		check(SaveCodec.new().decode(bad, run_def, 31, catalog, true) == null, "reject downgrade after new revision")
	print("CHEN PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
