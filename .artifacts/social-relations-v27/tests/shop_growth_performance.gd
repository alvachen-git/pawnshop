extends "res://tests/shop_growth.gd"

func run() -> void:
	if not setup(): quit(1); return
	var rows: Array = []
	for stage in ["preparation", "buyer", "ending"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-growth/" + stage + ".json"))
		var verifier := InvestigationSaveCodec.new()
		InvestigationSaveCodec.clear_cache()
		var start := Time.get_ticks_usec()
		var restored := verifier.restore(data, run_def, catalog, true)
		var cold := Time.get_ticks_usec() - start
		check(restored != null and verifier.replayed_actions == data.action_journal.size(), "cold replay " + stage)
		if restored == null: continue
		var warm: Array = []
		for i in 5:
			start = Time.get_ticks_usec()
			check(verifier.restore(data, run_def, catalog, true) != null and verifier.replayed_actions == 0, "verified prefix reused " + stage)
			warm.append((Time.get_ticks_usec() - start) / 1000.0)
		var forged := data.duplicate(true); forged.shop_growth.exploration.append({"step": 9})
		check(verifier.restore(forged, run_def, catalog, true) == null, "warm cache rejects new feature tamper " + stage)
		var session := fresh_growth(int(data.run_seed)); session._day.state = restored
		var before := session.read_state()
		start = Time.get_ticks_usec()
		for i in 20: session.counter_model(); ShopGrowthReadModels.page(session._day, i % 3)
		var models := (Time.get_ticks_usec() - start) / 20000.0
		check(session.read_state() == before, "read models do not roll or mutate " + stage)
		rows.append({"stage": stage, "journal_actions": data.action_journal.size(), "cold_ms": cold / 1000.0, "warm_ms": warm, "model_pair_average_ms": models})
	DirAccess.make_dir_recursive_absolute("res://docs/qa/shop-growth")
	FileAccess.open("res://docs/qa/shop-growth/performance.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("SHOP GROWTH PERFORMANCE: %d passes, %d failures; %s" % [passes, failures, JSON.stringify(rows)])
	quit(0 if failures == 0 else 1)
