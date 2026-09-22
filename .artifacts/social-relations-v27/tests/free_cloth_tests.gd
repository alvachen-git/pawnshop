extends "res://tests/run_mirror_chapter.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/mirror_chapter_manifest.json").load_catalog()
	check(loaded.is_success(), "free cloth catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "mirror_chapter")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	var s := fresh("cloth")
	for n in [1, 2]:
		driver.open(s); driver.work(s, "stop"); driver.finish(s, "covered")
	driver.open(s)
	var v := s._counter.customers.active(s._day.state)
	check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "acquire mirror")
	var id := v.item.instance_id
	var minute := s._day.state.game_minutes
	var count := s._day.state.action_count
	for i in 5:
		check(s.risk_command("cover", id).ok and s._risk.covered(s._day.state, id), "instant cover")
		check(not s.risk_command("cover", id).ok, "duplicate cover rejected")
		check(s.risk_command("uncover", id).ok and not s._risk.covered(s._day.state, id), "instant uncover")
	check(s._day.state.game_minutes == minute and s._day.state.action_count == count, "cloth changes neither clock nor action count")
	for button in s.risk_model().buttons:
		if button.command in ["cover", "uncover"]: check(not button.label.contains("分钟"), "no duration label")
	check(s.risk_command("cover", id).ok, "cover before close")
	# Close at the same timestamp: earlier uncover rows must not become post-close violations.
	driver.action(s, "close_shop")
	check(s._risk.storage_outcome(s._day.state, 3) == "mirror_safe", "same-minute before-close toggles stay safe")
	minute = s._day.state.game_minutes; count = s._day.state.action_count
	check(s.risk_command("uncover", id).ok, "closed shop uncover is instant but still violates rule")
	check(s.risk_command("cover", id).ok, "closed shop recover")
	check(s._day.state.game_minutes == minute and s._day.state.action_count == count, "post-close cloth also free")
	check(s._risk.storage_outcome(s._day.state, 3) == "mirror_scar", "same-minute after-close violation retained")
	driver.action(s, "wait_until_seal"); driver.action(s, "resolve_night"); driver.resume(s)
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 16)
	check(codec.decode(data, run_def, 16, catalog) != null, "instant history reload " + codec.error_message)
	var transfer := FileAccess.open("res://.godot/qa/mirror_chapter/free_cloth.json", FileAccess.WRITE)
	transfer.store_string(JSON.stringify(data)); transfer.close()
	var bad := data.duplicate(true)
	bad.risk_history[0].instant = "yes"
	check(codec.decode(bad, run_def, 16, catalog) == null, "invalid marker rejected")
	if FileAccess.file_exists("/private/tmp/mirror_before_free_cloth.json"):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string("/private/tmp/mirror_before_free_cloth.json"))
		check(codec.decode(old, run_def, 16, catalog) != null, "existing paid-cloth v16 checkpoint remains valid " + codec.error_message)
	print("FREE CLOTH TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
