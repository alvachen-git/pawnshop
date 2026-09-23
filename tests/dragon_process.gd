extends "res://tests/dragon_durability.gd"
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for stage in ["committed-before-fd_search_motive", "committed-search-ready", "committed-letter", "committed-invite-ready", "committed-lu", "committed-quoted", "bought", "after-fd_settle"]:
		InvestigationSaveCodec.clear_cache()
		var start := Time.get_ticks_msec()
		var s := load_stage(stage)
		check(s != null, "fresh process " + stage)
		print("COLD LOAD ", stage, " ", Time.get_ticks_msec() - start, "ms")
	print("DRAGON PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
