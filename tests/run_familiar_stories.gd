extends SceneTree

var passes := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition
var driver = preload("res://tests/integrated_test_driver.gd").new()
var seeds := {}
var covered := {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL " + label)
		if failures >= 3: quit(1)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/familiar_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v17 content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "familiar_seven")
	driver.check = check
	driver.catalog = catalog
	var distributions := {"bookkeeper": 0, "seamstress": 0, "both": 0}
	var nights := {"bookkeeper": {}, "seamstress": {}}
	for seed_value in 512:
		var plan := FamiliarStories.plan(run_def, catalog, seed_value)
		check(plan == FamiliarStories.plan(run_def, catalog, seed_value), "plan deterministic")
		var ids: Array = plan.stories.map(func(s: Dictionary) -> String: return s.id)
		distributions["both" if ids.size() == 2 else ids[0]] += 1
		var state := RunState.create(run_def)
		state.run_seed = seed_value
		var base := SevenNightPlan.plan(run_def, catalog, seed_value)
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		check(rows.size() == 42, "six seats each night")
		var occupied := {}
		for story in plan.stories:
			nights[story.id][story.first_night] = true
			if not seeds.has(story.id): seeds[story.id] = seed_value
			if story.id == "seamstress" and story.first_night <= 4 and story.funds == 0: seeds["funding"] = seed_value
			if story.id == "seamstress" and story.first_night <= 4 and story.funds == 30: seeds["independent"] = seed_value
			if story.id == "bookkeeper" and story.follow_night <= 7 and story.first.variant_id != "sound": seeds["bargain"] = seed_value
			if story.id == "seamstress" and story.due_night > 7: seeds["late"] = seed_value
			for stage in ["first", "follow"]:
				var row: Dictionary = story[stage]
				check(int(row.arrival) % 5 == 0 and row.arrival <= 450, "time step")
				check(row.person == story.person, "same named person")
				if row.night > 7: continue
				check(not occupied.has(row.visit_id), "distinct seats")
				occupied[row.visit_id] = row.night
				var originals := base.filter(func(r: Dictionary) -> bool: return r.visit_id == row.visit_id)
				check(originals.size() == 1 and not originals[0].has("seven_role") and not originals[0].context_id.is_empty(), "only ordinary unprotected seats")
				check(originals[0].arrival == row.arrival, "preserve arrival schedule")
			check(story.follow_night - story.first_night in ([2, 3] if story.id == "bookkeeper" else [1, 2]), "relative story gap")
		for n in range(1, 8): check(occupied.values().count(n) <= 2, "at most two story sellers per night")
		for i in base.size():
			if base[i].has("seven_role") or base[i].context_id.is_empty(): check(base[i] == rows[i], "protected story and opportunity unchanged")
		check(base.all(func(r: Dictionary) -> bool: return r.person.name not in FamiliarStories.NAMES), "ordinary names exclude story identities")
	check(distributions.both > 180 and distributions.both < 330, "both stories near half")
	check(distributions.bookkeeper > 80 and distributions.seamstress > 80, "both single-story cases")
	check(nights.bookkeeper.size() == 5 and nights.seamstress.size() == 4, "all first-night possibilities")
	print("SEEDS ", seeds, " distribution ", distributions)
	for route in ["normal", "candid", "guarded", "elsewhere", "insult_reject", "exhaust", "timeout"]:
		play(int(seeds.bargain), route)
		if failures > 0: quit(1); return
	for route in ["funded", "short", "unsold", "transfer", "no_pawn"]: play(int(seeds.funding), route)
	play(int(seeds.independent), "unsold")
	play(int(seeds.late), "late")
	print("FAMILIAR STORIES TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func roundtrip(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 17)
	var restored := codec.decode(JSON.parse_string(JSON.stringify(data)), run_def, 17, catalog, true)
	check(restored != null, "restore " + label + ": " + codec.error_message)
	var folder := "res://.godot/qa/familiar/cross"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var f := FileAccess.open(folder + "/%d_%d_%s.json" % [s._day.state.run_seed, s._day.state.current_night_index, String(s._day.state.phase)], FileAccess.WRITE)
	f.store_string(JSON.stringify(data)); f.close()
	if restored != null: check(restored.to_read_model() == data_without_versions(data), "exact state " + label)

func data_without_versions(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result.erase("content_version"); result.erase("save_version")
	return result

func command(s: RunSession, v: CustomerVisit, cmd: String, detail := "", amount := 0) -> void:
	var result := s.counter_command(cmd, v.visit_id, detail, amount)
	check(result.ok, cmd + ": " + result.message)

func play(seed_value: int, route: String) -> void:
	print("ROUTE ", seed_value, " ", route)
	run_def._randomize_seed = false
	run_def._seed = seed_value
	var saves := SaveManager.new("res://.godot/qa/familiar/%s_%d.json" % [route, seed_value])
	var s := RunSession.new(run_def, 17, saves, catalog)
	for n in range(1, 8):
		driver.drain(s)
		if failures > 0: return
		if n >= 2:
			if n % 2 == 0:
				check(s.execute("prep_visitors").ok, "learn actual callers")
				var targeted := s.execute("prep_target", "stationery")
				check(targeted.ok or targeted.message.contains("没有可另约"), "target respects protected seats: " + targeted.message)
			check(s.execute("prep_finish").ok, "finish preparation")
		roundtrip(s, route + " before night " + str(n))
		check(s.execute("open_shop").ok, "open")
		driver.drain(s)
		while not PawnReturnService.current(s._day.state).is_empty():
			var back := PawnReturnService.current(s._day.state)
			check(s.counter_command("redeem", back.id).ok, "same owner redeems")
			check(not s.counter_command("redeem", back.id).ok, "redeem once")
		for step in 180:
			if s._day.state.game_minutes >= 470: break
			driver.drain(s)
			if failures > 0: return
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				check(s.execute("short_task").ok, "wait")
				continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if row.get("familiar_id") == "bookkeeper": bookkeeper(s, v, row, route)
			elif row.get("familiar_id") == "seamstress": seamstress(s, v, row, route)
			else: command(s, v, "reject")
		check(s.execute("close_shop").ok, "close")
		roundtrip(s, "early closed")
		check(s.execute("wait_until_seal").ok, "seal")
		roundtrip(s, "unsettled 0300")
		for ticket in s._commerce.pawns.maturities(s._day.state): check(s.choose_pawn_disposal(ticket.ticket_id, "transfer" if route == "transfer" else "keep").ok, "dispose unredeemed")
		check(s.execute("resolve_night").ok, "resolve: " + s.message)
		for action in ["enter_room", "sleep", "finish_sleep"]:
			driver.drain(s)
			check(s.execute(action).ok, action + ": " + s.message)
			roundtrip(s, action)
		check(s.execute("continue_run").ok, "next / end")
		if failures >= 3: return
	check(s._day.state.phase == &"run_ended", "seven-night end")
	roundtrip(s, "final")
	var data := SaveCodec.new().encode(s._day.state, 17)
	var file := FileAccess.open("res://.godot/qa/familiar/%s_%d_final.json" % [route, seed_value], FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	var bad := data.duplicate(true)
	bad.familiar_plan.stories[0].follow_night += 1
	check(SaveCodec.new().decode(bad, run_def, 17, catalog, true) == null, "reject altered schedule")
	bad = data.duplicate(true); bad.familiar_progress.clear()
	check(SaveCodec.new().decode(bad, run_def, 17, catalog, true) == null, "reject altered progress")
	for t in s._day.state.pawn_tickets:
		if t.terms_id != FamiliarStories.TERMS: continue
		if t.due_night > 7: check(t.status == "active", "late ticket stays active")
		else:
			var expected := FamiliarStories.return_mode(t.to_data(), FamiliarStories.history_data(s._day.state), "redeem")
			check((t.status == "redeemed") == (expected == "redeem"), "redemption follows actual funds")

func bookkeeper(s: RunSession, v: CustomerVisit, row: Dictionary, route: String) -> void:
	if row.familiar_stage == "follow":
		check(v.person.name == "许文衡", "recognizable return")
		if route == "guarded": check(v.trade.rounds_left == 2 and v.expires_at - v.arrival == 30, "guarded visit limits")
		if route == "candid":
			check("condition_chipped" in v.trade.used_clue_ids and v.item.revealed_clue_ids.is_empty(), "price concession not evidence")
			command(s, v, "appraise", "observe"); command(s, v, "appraise", "inspect")
			var before := s._day.state.to_read_model()
			check(not s.counter_command("pressure", v.visit_id, "condition_chipped").ok, "same flaw cannot discount twice")
			check(before == s._day.state.to_read_model(), "repeated discount no time or money")
		command(s, v, "reject"); return
	if route in ["guarded", "insult_reject"]:
		command(s, v, "belittle")
		var before := s._day.state.to_read_model()
		check(not s.counter_command("belittle", v.visit_id).ok and before == s._day.state.to_read_model(), "belittle once")
	if route == "candid":
		command(s, v, "appraise", "observe"); command(s, v, "appraise", "inspect")
		command(s, v, "pressure", "flaw" if v.item.selected_variant_id == "flawed" else "condition_replacement_nib")
	if route in ["elsewhere", "insult_reject"]: command(s, v, "reject")
	elif route == "exhaust":
		while v.status == "active": command(s, v, "offer", "", 1)
	elif route == "timeout":
		while v.status == "active": check(s.execute("short_task").ok, "timeout")
	else: command(s, v, "offer", "", v.trade.reserve_price)

func seamstress(s: RunSession, v: CustomerVisit, row: Dictionary, route: String) -> void:
	if row.familiar_stage == "first":
		if route == "no_pawn": command(s, v, "reject"); return
		command(s, v, "pawn", "", 90 if route == "short" else maxi(25, roundi(v.trade.reserve_price * 0.5)))
	else:
		check(s.counter_model().dialogue.body.contains("银簪赎金"), "funding explained")
		if route in ["unsold", "transfer"]: command(s, v, "reject")
		else: command(s, v, "offer", "", v.trade.reserve_price)
