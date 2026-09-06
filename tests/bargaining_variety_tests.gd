extends SceneTree
var passes := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error(label)
func run() -> void:
	var helper := VarietyTests.new()
	helper._expect = check
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	check(loaded.is_success(), "v10 integration content")
	if not loaded.is_success():
		quit(1)
		return
	helper.catalog = loaded.catalog
	helper.run_def = loaded.catalog.get_definition("runs", loaded.catalog.default_run_id)
	for customer_id in ["customer_citizen", "customer_house_agent", "customer_hawker", "customer_scholar"]:
		var chosen := -1
		for seed_value in 512:
			if VarietyService.plan(helper.run_def, helper.catalog, seed_value)[0].customer_id == customer_id:
				chosen = seed_value
				break
		check(chosen >= 0, "random template covered " + customer_id)
		if chosen < 0: continue
		var s := helper.seeded(chosen)
		helper.open(s)
		var visit := helper.active(s)
		var person := visit.person.duplicate(true)
		check(helper.action(s, "question", "origin").ok, "ask source before bargaining")
		check(helper.action(s, "verify_source").ok, "source verification before bargaining")
		check(helper.action(s, "belittle").ok, "released bargaining available in random v10 visit")
		var after := s.read_state()
		check(not helper.action(s, "belittle").ok and s.read_state() == after, "repeat bargaining rejected without cost")
		check(helper.action(s, "offer", "", visit.trade.reserve_price).ok, "buy after combined source and bargaining")
		check(visit.person == person, "source and bargaining preserve identity")
		helper.finish(s)
		helper.finish_room(s)
		helper.resume(s, "v10 source plus bargaining checkpoint")
		var payload := SaveCodec.new().encode(s._day.state, helper.catalog.content_version)
		var found := false
		for row in payload.scenario_history:
			if row.command == "belittle":
				found = true
				row.belittle_result.asking += 1
		check(found, "v10 bargaining result persisted")
		check(SaveCodec.new().decode(payload, helper.run_def, helper.catalog.content_version, helper.catalog) == null, "combined history rejects altered bargaining price")
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("BARGAINING VARIETY TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
