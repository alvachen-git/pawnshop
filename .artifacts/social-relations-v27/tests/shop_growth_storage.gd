extends "res://tests/shop_growth.gd"

func run() -> void:
	if not setup(): quit(1); return
	var directory := "user://tests/shop_growth_storage/"
	DirAccess.make_dir_recursive_absolute(directory)
	for stage in ["preparation", "buyer"]:
		var manager := SaveManager.new(directory + stage + ".json")
		manager.catalog = catalog
		manager.library = SaveLibrary.new(directory + stage + "_library.json")
		if "read" in OS.get_cmdline_user_args():
			var restored := manager.load_state(run_def, 25)
			var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + stage + "_expected.json"))
			check(restored != null and GhostSaveCodec.same(restored.to_read_model(), expected), "independent process exact load " + stage)
			check(manager.library.entries().any(func(row: Dictionary) -> bool: return row.get("run_id", "") == "shop_growth_ten"), "save list recognizes growth slot")
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-growth/" + stage + ".json"))
		var s := fresh_growth(int(data.run_seed))
		s._day.state = SaveCodec.new().decode(data, run_def, 25, catalog, true)
		check(s._day.state != null, "verified disk input " + stage)
		if s._day.state == null: continue
		s._save = manager
		check(manager.save_state(s._day.state, run_def, 25), "initial real atomic publication " + stage + manager.error_message)
		var disk := FileAccess.get_file_as_string(manager.library.path)
		var before := s.read_state()
		manager.library.fail_write = true
		var result: ActionResult
		if stage == "preparation": result = s.growth_command("build", "bench")
		else: result = s.counter_command("display_accept", s._counter.customers.active(s._day.state).visit_id)
		check(not result.ok and result.message.contains("恢复原状"), "real write failure reported " + stage)
		check(s.read_state() == before and FileAccess.get_file_as_string(manager.library.path) == disk, "real file and full state retained " + stage)
		manager.library.fail_write = false
		if stage == "preparation": result = s.growth_command("build", "bench")
		else: result = s.counter_command("display_accept", s._counter.customers.active(s._day.state).visit_id)
		check(result.ok, "real retry single commit " + stage + result.message)
		FileAccess.open(directory + stage + "_expected.json", FileAccess.WRITE).store_string(JSON.stringify(s.read_state()))
		var saved_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manager.library.path))
		saved_file.entries["auto/shop_growth_ten"].payload.shop_growth.bench = not saved_file.entries["auto/shop_growth_ten"].payload.shop_growth.bench
		check(manager.library.decode_entry(saved_file.entries["auto/shop_growth_ten"]).is_empty(), "file tamper rejected " + stage)
	if "read" not in OS.get_cmdline_user_args():
		for stage in ["preparation", "closed", "buyer"]:
			var bootstrap := Bootstrap.new()
			bootstrap.manifest_path = "res://data/shop_growth_manifest.json"
			bootstrap.save_path = "user://tests/growth_bootstrap/" + stage + ".json"
			bootstrap.growth_preview = stage
			check(bootstrap.initialize().is_success() and bootstrap.session != null, "real preview bootstrap " + stage)
			var s := bootstrap.session
			check(s._day.state.ghost_origin.run_token == s._day.state.run_token and s._day.state.run_token != "0123456789abcdef0123456789abcdef", "preview has fresh attempt identity")
			var result: ActionResult
			if stage == "preparation": result = s.growth_command("build", "bench")
			elif stage == "closed": result = s.growth_command("explore", "0")
			else: result = s.counter_command("display_accept", s._counter.customers.active(s._day.state).visit_id)
			check(result.ok, "preview mutation really saves " + stage + result.message)
			var restored := s._save.load_state(s.definition, 25)
			check(restored != null and GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "preview resumes exact saved action " + stage)
			bootstrap.free()
	print("SHOP GROWTH STORAGE %s: %d passes, %d failures" % [str(OS.get_cmdline_user_args()), passes, failures])
	quit(0 if failures == 0 else 1)
