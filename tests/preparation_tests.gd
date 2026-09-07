extends SceneTree

var assertions := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition
var driver = preload("res://tests/integrated_test_driver.gd").new()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func fresh() -> RunSession:
	return RunSession.new(run_def, 15, SaveManager.new("res://.godot/qa/preparation_v15/runtime/test_%d.json" % Time.get_ticks_usec()), catalog)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/preparation_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v15 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "prepared_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	edges()
	if failures == 0: manual_storage()
	if failures == 0: play()
	if failures == 0: plans()
	if failures == 0: compatibility()
	print("PREPARATION TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func apply(state: RunState, action: String, category := "") -> bool:
	var result := OpeningPreparation.perform(state, run_def, catalog, action, category)
	check(result.ok, action + ": " + result.message)
	return result.ok

func edges() -> void:
	var s := fresh()
	check(not s.execute("prep_tea").ok, "first night has no preparation")
	driver.open(s); driver.finish(s, "reject")
	if failures: return
	check(s._day.state.current_night_index == 2 and s._day.state.cash == 290, "second night starts with original cash")
	var before := s.read_state()
	check(not s.execute("prep_target").ok and s.read_state() == before, "unselected category costs nothing")
	check(not s.execute("prep_target", "ghost").ok and s.read_state() == before, "invalid category rejected")
	var original_save := s._save
	var failing := M4Tests.ToggleSave.new(original_save.path)
	failing.catalog = catalog
	failing.fail = true
	s._save = failing
	check(not s.execute("prep_tea").ok and s.read_state() == before, "failed save rolls back expense and preparation")
	check(s._day.state.preparation_version == 1 and s._day.state.visits.size() == 6, "rollback retains v15 runtime and visits")
	s._save = original_save
	driver.action(s, "prep_attract")
	if failures: return
	check(s._day.state.cash == 287 and s._day.state.visits.size() == 7, "attract costs three and adds customer")
	driver.resume(s)
	before = s.read_state()
	check(not s.execute("prep_attract").ok and before == s.read_state(), "duplicate attract does not charge")
	var original_waits := {}
	for v in s._day.state.visits: original_waits[v.visit_id] = v.expires_at - v.arrival
	driver.action(s, "prep_tea")
	if failures: return
	check(s._day.state.cash == 282 and s._day.state.night_opening_cash == 290 and s._day.state.game_minutes == 0, "tea costs five without time or opening balance change")
	for v in s._day.state.visits: check(v.expires_at - v.arrival == original_waits[v.visit_id] + 20, "tea includes additional customer")
	check(FinancialSummary.build(s._day.state).preparation_expense == 8, "both costs counted")
	driver.resume(s)
	before = s.read_state()
	check(not s.execute("prep_visitors").ok and s.read_state() == before, "daily two action limit")
	driver.action(s, "open_shop")
	check(s._day.state.phase == &"open", "one command ends prep and opens")
	check(not s.execute("prep_tea").ok, "no preparation after opening")
	driver.finish(s, "reject")
	if failures: return
	check(s._day.state.summaries[1].preparation_expense == 8 and s._day.state.summaries[1].closing_cash == 272, "second night accounts reconcile")
	check(PreparationService.count(s._day.state) == 0 and FinancialSummary.build(s._day.state).preparation_expense == 0, "next night clears allowances and costs")
	var encoded := SaveCodec.new().encode(s._day.state, 15)
	for field in ["cost", "change", "visit_ids"]:
		var changed := encoded.duplicate(true)
		match field:
			"cost": changed.preparation_history[0].cost = 1
			"change": changed.preparation_history[0].change.variant_id = "fake"
			"visit_ids": changed.preparation_history[0].visit_ids = ["fake"]
		check(SaveCodec.new().decode(changed, run_def, 15, catalog) == null, "reject tampered " + field)
	for money in [0, 2, 3, 4, 5]:
		var state := RunState.create(run_def)
		state.current_night_index = 2
		state.cash = money
		var data := state.to_read_model()
		var result := OpeningPreparation.perform(state, run_def, catalog, "tea")
		check(result.ok == (money >= 5), "tea affordability boundary %d" % money)
		if not result.ok: check(state.to_read_model() == data, "insufficient money leaves no changes")
		state.cash = money
		check(OpeningPreparation.perform(state, run_def, catalog, "attract").ok == (money >= 3), "attract affordability boundary %d" % money)

func play() -> void:
	var s := fresh()
	for night in range(1, 8):
		driver.drain(s)
		match night:
			2:
				driver.action(s, "prep_visitors")
				check(s.execute("prep_target", "stationery").ok, "intel before target")
			3:
				check(s.execute("prep_target", "watches").ok, "target watches")
				driver.action(s, "prep_visitors")
			4:
				driver.action(s, "prep_investigate")
				driver.action(s, "prep_tea")
			5:
				driver.action(s, "prep_attract")
				driver.action(s, "prep_visitors")
			6:
				driver.action(s, "prep_tea")
				check(s.execute("prep_target", "porcelain").ok, "target before redemption")
			7:
				check(s.execute("prep_target", "jewelry").ok, "last night target")
				driver.action(s, "prep_tea")
		if failures: return
		driver.resume(s)
		driver.open(s)
		driver.work(s, "covered")
		driver.finish(s, "covered")
		if failures: return
	check(s._day.state.phase == &"run_ended" and s._day.state.summaries.size() == 7, "v15 completes seven nights")
	check(s._day.state.pawn_tickets[0].status == "redeemed", "original pawn redeemed")
	check(s._day.state.sale_records.filter(func(row: Dictionary) -> bool: return row.buyer_id == PreparationService.BUYER).size() == 2, "pens sold without introduction")
	check(not PreparationService.used(s._day.state, "contact"), "no contact action needed")

func plans() -> void:
	for seed_value in 256:
		var state := RunState.create(run_def)
		state.run_seed = seed_value
		var base := SevenNightPlan.plan(run_def, catalog, seed_value)
		for night in range(2, 8):
			state.current_night_index = night
			state.preparation_history.clear()
			state.cash = 10000
			apply(state, "attract"); apply(state, "tea")
			var rows := OpeningPreparation.plan(state, run_def, catalog)
			check(rows == OpeningPreparation.plan(state, run_def, catalog) and base == SevenNightPlan.plan(run_def, catalog, seed_value), "stable overlay, unchanged base")
			var today: Array = rows.filter(func(row: Dictionary) -> bool: return row.night == night)
			check(today.size() == 7, "extra visit count")
			var extra: Dictionary = today.filter(func(row: Dictionary) -> bool: return row.visit_id.ends_with("/prep_extra"))[0]
			check(extra.arrival >= 0 and extra.arrival <= 450 and int(extra.arrival) % 5 == 0, "extra visit grid")
			for row in today:
				if row.visit_id != extra.visit_id: check(absi(int(row.arrival) - int(extra.arrival)) >= 15, "extra spacing")
				if night == 2: check("pawn" not in row.transaction_modes, "second night sell only")
			for category in OpeningPreparation.CATEGORIES:
				for intel_first in [false, true]:
					state.preparation_history.clear()
					if intel_first: apply(state, "visitors")
					var known := OpeningPreparation.known_ids(state, night)
					if not apply(state, "target", category): return
					var targeted: Dictionary = state.preparation_history.back().change
					check(targeted.visit_id not in known, "target keeps known intel")
					check((catalog.get_definition("items", targeted.item_id) as ItemDefinition).category == category, "target category exact")
					if not intel_first:
						apply(state, "visitors")
						check(targeted.visit_id in state.preparation_history.back().visit_ids, "intel prioritizes target")
					rows = OpeningPreparation.plan(state, run_def, catalog)
					check(rows.size() == 42, "target does not add visits")
					for original in base:
						if original.has("seven_role") or not OpeningPreparation.ordinary(original):
							check(original in rows, "protected content unchanged")
		if failures: return

func compatibility() -> void:
	var library := SaveLibrary.new("res://.godot/qa/preparation_v15/runtime/compat_%d.json" % Time.get_ticks_usec())
	var s := fresh()
	s._save.library = library
	check(library.write_entry("auto/prepared_seven", s._day.state, run_def, 15, catalog), "new automatic position")
	var old_catalog := JsonContentProvider.new("res://data/integrated_manifest.json").load_catalog().catalog
	var old_run := old_catalog.get_definition("runs", "integrated_seven") as RunDefinition
	var old := RunSession.new(old_run, 14, SaveManager.new("res://.godot/qa/preparation_v15/runtime/old.json"), old_catalog)
	check(library.write_entry("auto/integrated_seven", old._day.state, old_run, 14, old_catalog), "separate old automatic position")
	var decoded := library.read_entry("auto/integrated_seven")
	check(not decoded.is_empty() and library.adopt(decoded, s), "v14 still loads")
	check(s._day.state.preparation_version == 0 and not s.execute("prep_attract").ok, "old game retains old rules")
	s.new_run()
	check(s.definition.id == "prepared_seven" and s._day.state.preparation_version == 1, "new game returns to new content")
	check(not library.read_entry("auto/integrated_seven").is_empty(), "old automatic position survives new game")

func manual_storage() -> void:
	var s := fresh()
	driver.open(s); driver.finish(s, "reject")
	var library := SaveLibrary.new("res://.godot/qa/preparation_v15/runtime/manual_%d.json" % Time.get_ticks_usec())
	s._save.library = library
	driver.action(s, "prep_attract")
	driver.action(s, "prep_tea")
	var before := s.read_state()
	check(library.write_entry("manual/1", s._day.state, run_def, 15, catalog), "manual preparation snapshot")
	var decoded := library.read_entry("manual/1")
	check(not decoded.is_empty() and decoded.state.to_read_model() == before, "manual prep exact cash and history")
	driver.open(s)
	check(not SaveLibrary.save_reason(s._day.state).is_empty(), "existing no-save-during-trading rule retained")
	driver.action(s, "close_shop")
	before = s.read_state()
	check(library.write_entry("manual/2", s._day.state, run_def, 15, catalog), "manual closed but unsettled preparation expenses: " + library.error_message)
	decoded = library.read_entry("manual/2")
	check(not decoded.is_empty() and decoded.state.to_read_model() == before, "unsettled snapshot reconciles preparation costs")
	library.fail_write = true
	check(not library.write_entry("manual/2", s._day.state, run_def, 15, catalog) and s.read_state() == before, "manual failure keeps original state")
