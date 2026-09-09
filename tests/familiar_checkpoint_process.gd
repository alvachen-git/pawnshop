extends SceneTree

var checks := 0
var failures := 0
var catalog: ContentCatalog
var definition: RunDefinition

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/familiar_manifest.json").load_catalog()
	check(loaded.is_success(), "fresh process content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	definition = catalog.get_definition("runs", "familiar_seven")
	var directory := "res://.godot/qa/familiar/cross"
	var files := DirAccess.get_files_at(directory)
	check(files.size() >= 30, "separate process snapshots exist")
	var phases := {}
	for name in files:
		if not name.ends_with(".json"): continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))
		var codec := SaveCodec.new()
		var restored := codec.decode(data, definition, 17, catalog, true)
		check(restored != null, "fresh process " + name + ": " + codec.error_message)
		if restored == null: continue
		phases[String(restored.phase)] = true
		var bad := data.duplicate(true)
		bad.familiar_plan.stories[0].funds += 1
		check(codec.decode(bad, definition, 17, catalog, true) == null, "funds cannot change on restore")
		bad = data.duplicate(true)
		if not bad.scenario_history.is_empty():
			bad.scenario_history.append(bad.scenario_history[0].duplicate(true))
			check(codec.decode(bad, definition, 17, catalog, true) == null, "duplicate action refused")
		if data.phase == "closed_processing" and data.current_night_index == 4: save_failures(restored)
	check(phases.has("pre_open") and phases.has("closed_processing") and phases.has("night_resolution") and phases.has("private_room") and phases.has("sleep_resolution") and phases.has("day_summary") and phases.has("run_ended"), "all stable phases in another process")
	funding_boundaries()
	completed_routes()
	print("FAMILIAR CHECKPOINTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func save_failures(state: RunState) -> void:
	var library := SaveLibrary.new("res://.godot/qa/familiar/library_failure_%d.json" % Time.get_ticks_usec())
	check(library.write_entry("manual/1", state, definition, 17, catalog), "manual slot valid before failed replacement")
	var bytes := FileAccess.get_file_as_bytes(library.path)
	var snapshot := state.to_read_model()
	library.fail_write = true
	check(not library.write_entry("manual/1", state, definition, 17, catalog), "write failure reported")
	check(FileAccess.get_file_as_bytes(library.path) == bytes and state.to_read_model() == snapshot, "old slot and state retained")
	check(not library.write_entry("manual/2", state, definition, 17, catalog), "failed new slot not published")
	library.fail_write = false
	check(library.write_entry("manual/1", state, definition, 17, catalog), "retry slot succeeds")
	var saved := library.read_entry("manual/1")
	check(not saved.is_empty(), "cross entry catalog resolves v17")
	var manager := SaveManager.new("res://.godot/qa/familiar/unused.json")
	manager.library = library
	manager.catalog = catalog
	var session := RunSession.new(definition, 17, manager, catalog)
	check(library.adopt(saved, session), "adopt known good slot")
	check(session._day.state.run_token != state.run_token, "retry has its own attempt")
	check(session.execute("wait_until_seal").ok, "advance loaded early closure")
	for ticket in session._commerce.pawns.maturities(session._day.state): session.choose_pawn_disposal(ticket.ticket_id, "keep")
	var before := session.read_state()
	library.fail_write = true
	check(not session.execute("resolve_night").ok, "night commit failure reported")
	check(session.read_state() == before, "night rollback includes stories and tickets")
	library.fail_write = false
	check(session.execute("resolve_night").ok, "night retry commits once")
	var once := session.read_state()
	check(not session.execute("resolve_night").ok and once == session.read_state(), "no duplicate night settlement")

func funding_boundaries() -> void:
	var plan := FamiliarStories.plan(definition, catalog, 511)
	var story := FamiliarStories.story_for({"familiar_plan": plan}, "seamstress")
	var terms := catalog.get_definition("pawn_terms", FamiliarStories.TERMS) as PawnTermsDefinition
	for principal in [1, 25, 30, 31, 90]:
		var redemption: int = principal + ceili(principal * terms.redemption_fee_ratio)
		check(redemption == principal + ceili(principal / 10.0), "fixed fee rounds up")
		var ticket := {"terms_id": FamiliarStories.TERMS, "source_visit_id": story.first.visit_id, "redemption_amount": redemption}
		for delta in [-1, 0, 1]:
			var data := {"familiar_plan": plan, "visit_history": [{"visit_id": story.follow.visit_id, "outcome": "bought", "night": story.follow_night}],
				"inventory_instances": [{"source_visit_id": story.follow.visit_id, "acquisition_type": "purchase", "acquisition_price": redemption + delta}]}
			check(FamiliarStories.return_mode(ticket, data, "redeem") == ("redeem" if delta >= 0 else "absent"), "exact or one-coin shortage")
			ticket.terms_id = "sample_three_redeem"
			check(FamiliarStories.return_mode(ticket, data, "redeem") == "redeem", "old contract ignores story funds")
			ticket.terms_id = FamiliarStories.TERMS
	var bad := {"familiar_plan": plan, "visit_history": [], "inventory_instances": [{"source_visit_id": story.first.visit_id, "acquisition_type": "pawn", "acquisition_price": 900}]}
	check(FamiliarStories.funds(story, bad) == int(story.funds), "initial loan is spent, never counted again")

func completed_routes() -> void:
	for route in ["normal", "candid", "guarded", "elsewhere", "insult_reject", "exhaust", "timeout"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/familiar/%s_507_final.json" % route))
		var story := FamiliarStories.story_for(data, "bookkeeper")
		var expected: String = "ended" if route in ["insult_reject", "exhaust", "timeout"] else route
		check(FamiliarStories.branch(story, data, catalog) == expected, "actual first reception determines " + route)
		var selected: Array = data.ordinary_selections.filter(func(row: Dictionary) -> bool: return row.visit_id == story.follow.visit_id)
		check(selected.size() == 1, "follow seat occurs once")
		if selected.size() == 1:
			check(selected[0].get("familiar_stage", "") == ("" if expected == "ended" else "follow"), "ordinary fallback or actual follow " + route)
		if route == "guarded":
			var first_item := catalog.get_definition("items", story.first.item_id) as ItemDefinition
			var clue: ClueDefinition = first_item.clues.filter(func(c: ClueDefinition) -> bool: return c.leverage > 0)[0]
			data.scenario_history.append({"visit_id": story.first.visit_id, "night": story.first_night, "ok": true, "command": "pressure", "detail": clue.id})
			check(FamiliarStories.branch(story, data, catalog) == "guarded", "belittling wins over valid evidence concession")
	for route in ["funded", "short", "unsold", "transfer", "no_pawn", "independent"]:
		var filename: String = "unsold_508" if route == "independent" else route + "_511"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/familiar/%s_final.json" % filename))
		var story := FamiliarStories.story_for(data, "seamstress")
		var tickets: Array = data.pawn_tickets.filter(func(t: Dictionary) -> bool: return t.source_visit_id == story.first.visit_id)
		check(tickets.size() == (0 if route == "no_pawn" else 1), "actual linked contract " + route)
		if not tickets.is_empty():
			var expected: String = {"funded": "redeemed", "short": "defaulted", "unsold": "defaulted", "transfer": "transferred", "independent": "redeemed"}[route]
			check(tickets[0].status == expected, "actual money produces expected ticket status " + route)
	var future := {}
	for seed_value in 512:
		for story in FamiliarStories.plan(definition, catalog, seed_value).stories:
			if story.follow_night > 7: future[int(story.follow_night)] = true
			if story.due_night > 7: future[int(story.due_night)] = true
	check(future.has(8) and future.has(9), "plans beyond both eighth and ninth nights remain representable")
