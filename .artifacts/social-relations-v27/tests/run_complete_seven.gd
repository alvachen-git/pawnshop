extends "res://tests/run_market_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/complete_seven_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "complete catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "complete_seven")
	run_def._randomize_seed = false; run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/complete"))
	check(run_def.initial_cash == 300 and run_def.fee_policy.principal == 500 and run_def.fee_policy.interest + run_def.fee_policy.overhead == 10, "economy unchanged")
	combinations()
	contract(); batch_edges(); preparation_timing()
	cash_flow()
	preview_cases()
	compatibility()
	for route in ["ability", "pursue", "death", "reject", "sold", "missed"]: chapter(route)
	print("COMPLETE SEVEN: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func chapter_transfer_path() -> String:
	return "res://.godot/qa/complete/chapter.json"

func combinations() -> void:
	for seed_value in 512:
		var state := RunState.create(run_def); state.run_seed = seed_value
		var base := SevenNightPlan.plan(run_def, catalog, seed_value)
		var plan := OpeningPreparation.plan(state, run_def, catalog)
		var market := MarketService.plan(run_def, seed_value)
		check(plan.size() == 42 and plan == OpeningPreparation.plan(state, run_def, catalog), "42 stable combined slots")
		check(FamiliarStories.plan(run_def, catalog, seed_value).stories.size() in [1, 2], "story choice retained")
		state.current_night_index = 2; state.phase = &"pre_open"
		check(OpeningPreparation.perform(state, run_def, catalog, "attract").ok, "attract combined guest")
		check(OpeningPreparation.perform(state, run_def, catalog, "target", "stationery").ok, "target combined ordinary guest")
		var after := OpeningPreparation.plan(state, run_def, catalog)
		check(after.size() == 43 and after == OpeningPreparation.plan(state, run_def, catalog), "prepared overlay stable")
		for before in plan:
			if before.has("seven_role") or before.get("familiar_reserved", false) or before.context_id.is_empty():
				var matching := after.filter(func(row: Dictionary) -> bool: return row.visit_id == before.visit_id)
				check(matching.size() == 1 and matching[0] == before, "prepared actions preserve protected seats")
		for night in range(1, 8): check(after.filter(func(row: Dictionary) -> bool: return row.night == night).size() == (7 if night == 2 else 6), "daily potential count")
		check(market == MarketService.plan(run_def, seed_value), "preparation does not change demands")
		check(base == SevenNightPlan.plan(run_def, catalog, seed_value), "base unchanged")

func cash_flow() -> void:
	var s := fixture()
	var state := s._day.state
	state.cash = 300
	var flow := CashFlowReadModel.build(state, run_def)
	check(flow.pending_fees == 10 and flow.balance == 290 and flow.arrears == 0, "cash excludes principal and tonight fees reserved")
	state.current_night_index = 2
	state.fee_arrears.append({"origin_night": 1, "due_night": 2, "amount": 3})
	state.cash = 13
	flow = CashFlowReadModel.build(state, run_def)
	check(flow.balance == 0 and flow.arrears == 3, "exact coverage is zero")
	check(CashFlowReadModel.debt_detail(flow).contains("今夜到期"), "old shortfall deadline visible")
	state.cash = 12; flow = CashFlowReadModel.build(state, run_def)
	check(flow.balance == -1 and CashFlowReadModel.balance_text(flow.balance) == "留足息费尚差1银元", "short one no negative spendable cash")
	var before := state.to_read_model()
	for i in 3: s.counter_model(); CashFlowReadModel.build(state, run_def)
	check(state.to_read_model() == before, "read models do not change time money or dirty state")
	FeeService.settle(state, run_def)
	flow = CashFlowReadModel.build(state, run_def)
	check(state.cash == 0 and flow.pending_fees == 0 and flow.arrears == 1 and flow.balance == -1, "partial payment counted once after settlement")
	check(flow.arrears_rows[0].due_night == 3 and not CashFlowReadModel.debt_detail(flow).contains("（今夜到期）"), "new shortfall keeps tomorrow grace")
	FeeService.settle(state, run_def)
	check(flow == CashFlowReadModel.build(state, run_def), "repeated settlement does not change reserve")
	var prep := fixture(2); prep._day.state.phase = &"pre_open"
	var cash := prep._day.state.cash
	check(OpeningPreparation.perform(prep._day.state, run_def, catalog, "tea").ok, "actual tea cost")
	check(CashFlowReadModel.build(prep._day.state, run_def).balance == cash - 5 - 10, "already paid tea not subtracted twice")
	var inquiry := fixture()
	var investigated := stock(inquiry)
	var cash_before := inquiry._day.state.cash
	check(ProvenanceService.inquire(inquiry._day, investigated, catalog.get_definition("items", investigated.definition_id)).ok, "real source investigation")
	check(CashFlowReadModel.build(inquiry._day.state, run_def).balance == cash_before - 2 - 10, "paid source inquiry not subtracted twice")
	var held := stock(prep); held.acquisition_price = 40
	flow = CashFlowReadModel.build(prep._day.state, run_def)
	check(flow.inventory_cost == 40 and flow.cash == prep._day.state.cash, "inventory cost is separate from cash")
	held.ownership_state = "pledged"
	var ticket := PawnTicket.new(); ticket.status = "active"; ticket.principal = 40; ticket.redemption_amount = 44
	prep._day.state.pawn_tickets.append(ticket)
	flow = CashFlowReadModel.build(prep._day.state, run_def)
	check(flow.inventory_cost == 0 and flow.pawn_principal == 40 and flow.cash == prep._day.state.cash, "future redemption not available cash")
	ticket.status = "defaulted"; held.ownership_state = "owned"
	flow = CashFlowReadModel.build(prep._day.state, run_def)
	check(flow.inventory_cost == 40 and flow.pawn_principal == 0, "default transfers cost category without creating money")

func preview_cases() -> void:
	for cost in [1, 100]:
		var s := fixture(); var item := stock(s); item.acquisition_price = cost
		var model := s.counter_model()
		check(model.inventory.cash_flow == model.ledger.cash_flow, "same inventory and ledger numbers")
		check(not model.trade.has("cash_flow"), "no trade panel hints")
		var buyer: Dictionary = model.inventory.sales.buyers.filter(func(b: Dictionary) -> bool: return b.id == "buyer_recycler")[0]
		var flow: Dictionary = model.inventory.cash_flow
		var preview := CashFlowReadModel.sale_preview(flow, buyer, [item.instance_id])
		check(preview.executable and preview.profit == preview.income - cost, "positive or negative gross remains selectable")
		check(not CashFlowReadModel.sale_preview(flow, buyer, []).executable, "empty batch")
		check(not CashFlowReadModel.sale_preview(flow, buyer, [item.instance_id, item.instance_id]).valid, "duplicate batch rejected")
		check(not CashFlowReadModel.sale_preview(flow, buyer, ["absent"]).valid, "invalid batch rejected")
		var blocked := buyer.duplicate(true); blocked.reason = "店里还有客人"
		var trial := CashFlowReadModel.sale_preview(flow, blocked, [item.instance_id])
		check(not trial.executable and trial.cash == preview.cash, "blocked quote explicitly trial only")
		check(s.sell_batch("buyer_recycler", [item.instance_id]).ok, "actual selected buyer sale")
		check(s._day.state.cash == preview.cash and CashFlowReadModel.build(s._day.state, run_def).balance == preview.balance, "preview equals real cash and fee remainder")
		check(CashFlowReadModel.build(s._day.state, run_def).inventory_cost == 0, "sold stock no longer tied up")

func compatibility() -> void:
	var s := fresh("compat19")
	var lib := SaveLibrary.new("res://.godot/qa/complete/library.json")
	s._save.library = lib
	for manifest in ["market_familiar_manifest", "market_seven_manifest", "familiar_manifest", "familiar_early_manifest", "mirror_chapter_manifest", "content_manifest", "four_night_manifest"]:
		var old := JsonContentProvider.new("res://data/" + manifest + ".json").load_catalog().catalog
		var definition: RunDefinition = old.get_definition("runs", old.default_run_id)
		var previous := RunSession.new(definition, old.content_version, SaveManager.new("user://tests/complete_old.json"), old)
		check(CashFlowReadModel.build(previous._day.state, definition).is_empty(), "legacy hints disabled")
		for key in ["manual/1", "auto/" + String(definition.id)]:
			check(lib.write_entry(key, previous._day.state, definition, old.content_version, old), "write independent old location")
			var restored := lib.read_entry(key)
			check(not restored.is_empty() and restored.run.id == definition.id, "same version different run resolves correctly")
			check(lib.adopt(restored, s), "adopt legacy")
			s.new_run()
			check(s.definition.id == "complete_seven" and s.content_version == 19 and s.counter_model().inventory.has("cash_flow"), "new game restores complete default")
	check(lib.write_entry("auto/complete_seven", s._day.state, run_def, 19, catalog), "new independent auto")
	var original := FileAccess.get_file_as_string(lib.path)
	var before := s.read_state()
	lib.fail_write = true
	var event := s.event_model()
	check(not s.event_command(event.pending_id, event.buttons[0].detail).ok and before == s.read_state() and original == FileAccess.get_file_as_string(lib.path), "opening save failure leaves cash flow and old slots intact")

func stock(s: RunSession, id := "item_fountain_pen", variant := "sound") -> ItemInstance:
	var item := super.stock(s, id, variant)
	item.provenance = {"truth": "none", "status": "unchecked", "investigated": false, "evidence": []}
	return item
