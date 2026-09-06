extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL · " + message)
func _initialize() -> void:
	var helper := VarietyTests.new()
	helper._expect = check
	helper.catalog = JsonContentProvider.new("res://data/legacy/content_v10.json").load_catalog().catalog
	helper.run_def = helper.catalog.get_definition("runs", helper.catalog.default_run_id)
	var saver := SaveManager.new("user://tests/variety_cross_process.json")
	var s := RunSession.new(helper.run_def, helper.catalog.content_version, saver, helper.catalog)
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "write":
		s._day.state.run_seed = 42
		s._day.state.ordinary_selections.clear()
		s._day.state.scenario_selections.clear()
		s._counter.customers.prepare_night(s._day.state, helper.run_def, helper.catalog)
		helper.open(s)
		var visit := helper.active(s)
		check(helper.action(s, "offer", "", visit.trade.reserve_price).ok, "buy first item")
		check(s.commerce_command("inquire", visit.item.instance_id).ok, "paid provenance")
		for minute in [90, 210]:
			helper.wait_to(s, minute)
			visit = helper.active(s)
			var term: PawnTermsDefinition = helper.catalog.get_definition("pawn_terms", visit.pawn_terms_id)
			check(helper.action(s, "pawn", "", maxi(1, roundi(visit.trade.reserve_price * term.loan_ratio))).ok, "independent owner pawn")
		check(helper.finish(s), "first night checkpoint")
		helper.finish_room(s)
		check(s.execute("continue_run").ok, "before original return checkpoint")
	elif mode == "settle":
		check(s.load_checkpoint().ok, "restore random identities across process: " + s.message)
		var item: Dictionary = s.read_state().inventory_instances[0]
		check(item.provenance.status == "verified" and item.provenance.investigated and s.read_state().provenance_history.size() == 1, "source and inquiry persist")
		helper.open(s)
		var owner := PawnReturnService.current(s._day.state)
		var expected: Dictionary = VarietyService.plan(helper.run_def, helper.catalog, 42)[1].person
		check(owner.person == expected and s.counter_model().customer.contains(expected.name), "same named original owner")
		check(s.counter_command("redeem", owner.id).ok, "redeem actual original owner")
		check(s.execute("close_shop").ok and s.execute("wait_until_seal").ok, "early close")
		for row in s.pawn_disposal_model(): check(s.choose_pawn_disposal(row.id, "transfer").ok, "draft transfer")
		# Failed disk publication must roll back the combined maturity/fee transaction.
		var blocker := "user://tests/variety_blocker"
		var file := FileAccess.open(blocker, FileAccess.WRITE)
		file.store_string("test file blocks directory creation"); file.close()
		var path := saver.path
		saver.path = blocker + "/save.json"
		var before := s.read_state()
		check(not s.execute("resolve_night").ok and before == s.read_state(), "disk failure atomic rollback with provenance and transfers")
		saver.path = path
		check(s.execute("resolve_night").ok, "retry maturity and fees")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	else:
		check(s.load_checkpoint().ok, "restore redeemed/transferred state: " + s.message)
		var state := s.read_state()
		check(state.pawn_tickets[0].status == "redeemed" and state.pawn_tickets[1].status == "transferred", "owner and stock terminal states")
		check(state.provenance_history.size() == 1 and state.summaries[0].provenance_expense == 2 and state.summaries[1].provenance_expense == 0, "investigation expense not repeated")
		check(not s.execute("resolve_night").ok and not s.commerce_command("inquire", state.inventory_instances[0].instance_id).ok and state == s.read_state(), "restart cannot duplicate payout or expense")
		check(state.ordinary_selections == VarietyService.plan(helper.run_def, helper.catalog, 42).filter(func(r: Dictionary) -> bool: return r.night <= 2), "all selections unchanged")
	print("VARIETY PROCESS %s: %d failures" % [mode, failures])
	quit(0 if failures == 0 else 1)
