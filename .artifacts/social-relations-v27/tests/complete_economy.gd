extends "res://tests/run_mirror_chapter.gd"

# Decisions use current counter evidence and buyer cards, never seeded future demand,
# reserve prices, hidden variants or the scripted role of a visitor.
var cash_shortages := 0
var comparison_rows: Array = []

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/complete_seven_manifest.json").load_catalog()
	check(loaded.is_success(), "comparison catalog")
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "complete_seven")
	run_def._randomize_seed = false
	driver.check = check; driver.catalog = catalog
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/complete_economy"))
	for policy in ["immediate", "positive", "patient", "appointment"]:
		for seed_value in (1 if "quick" in OS.get_cmdline_user_args() else 32):
			run_def._seed = seed_value
			comparison_rows.append(simulate(policy))
			print("COMPARISON ", policy, " seed ", seed_value)
		print("COMPARISON completed ", policy)
	var output := FileAccess.open("res://.godot/qa/complete_economy/comparison.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(comparison_rows, "\t")); output.close()
	check(comparison_rows.size() == (4 if "quick" in OS.get_cmdline_user_args() else 128), "all paired seeds")
	print("MARKET COMPARISON TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func simulate(policy: String) -> Dictionary:
	cash_shortages = 0
	var s := fresh("comparison_" + policy)
	for night in range(1, 8):
		driver.drain(s)
		# Same preparations across policies; paid tea also exercises the overlay save rules.
		if night == 2 and s.can_execute("prep_tea"): driver.action(s, "prep_tea")
		if night == 4 and s.can_execute("prep_investigate"): driver.action(s, "prep_investigate")
		if night == 4 and s.can_execute("prep_contact"): driver.action(s, "prep_contact")
		driver.action(s, "open_shop"); driver.drain(s)
		for step in 250:
			driver.drain(s)
			if s._day.state.game_minutes >= 480: break
			var back := PawnReturnService.current(s._day.state)
			if not back.is_empty():
				check(s.counter_command("redeem", back.id).ok, "handle every original owner before business")
				continue
			var visit := s._counter.customers.active(s._day.state)
			if visit != null: purchase(s, visit, policy)
			elif not sell_current(s, policy): driver.action(s, "short_task")
		finish_comparison(s)
		if s._day.state.phase in [&"bankrupt", &"dead", &"run_ended"]: break
	var state := s._day.state
	var gross := 0
	var buyers := {}
	for sale in state.sale_records:
		gross += sale.realized_profit
		buyers[sale.buyer_id] = buyers.get(sale.buyer_id, 0) + 1
	if policy == "appointment": check(buyers.get(PreparationService.BUYER, 0) == 2, "two held pens sold in actual sixth-night window")
	var remaining := 0
	var pledged := 0
	for item in state.inventory_instances:
		if item.ownership_state == "owned": remaining += item.acquisition_price
		elif item.ownership_state == "pledged": pledged += item.acquisition_price
	var missed := state.visit_history.filter(func(h: Dictionary) -> bool: return h.outcome in ["timed_out", "shop_closed"]).size()
	var row := {"seed": state.run_seed, "policy": policy, "phase": String(state.phase), "cash_shortages": cash_shortages,
		"missed_customers": missed, "sale_gross_profit": gross, "daily_fees": state.fee_history.duplicate(true),
		"preparations": state.preparation_history.duplicate(true), "night_reached": state.current_night_index,
		"remaining_inventory_cost": remaining, "sale_minutes": state.sale_batches.size() * 20, "cash": state.cash,
		"pledged_inventory_cost": pledged,
		"buyers": buyers, "visit_history": state.visit_history.duplicate(true), "sales": state.sale_records.duplicate(true)}
	if policy == "positive" and state.run_seed == 0:
		var file := FileAccess.open("res://.godot/qa/complete_economy/economy_checkpoint.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(SaveCodec.new().encode(state, 19))); file.close()
		var library := SaveLibrary.new("res://.godot/qa/complete_economy/economy_library.json")
		check(library.write_entry("manual/1", state, run_def, 19, catalog), "manual market history checkpoint")
	return row

func purchase(s: RunSession, visit: CustomerVisit, policy: String) -> void:
	if EarlyRedemption.is_visit(visit):
		check(s.counter_command("early_redeem", visit.visit_id).ok, "optional early return during economy route")
		return
	if policy == "appointment":
		var row := VarietySaveCodec.selection(s._day.state, visit.visit_id)
		if row.get("seven_role", "") in ["pen4", "pen5"]:
			check(s.counter_command("offer", visit.visit_id, "", visit.trade.asking_price).ok, "buy both real appointment opportunities")
		elif row.get("seven_role", "") == "pawn":
			check(s.counter_command("pawn", visit.visit_id, "", 40).ok, "third-night original owner contract")
		else: check(s.counter_command("reject", visit.visit_id).ok, "appointment route declines other offers")
		return
	var item: ItemDefinition = catalog.get_definition("items", visit.item.definition_id)
	# This economic experiment declines ghost goods; full chapter routes are tested separately.
	if item.item_type == "normal":
		for action in item.appraisal_actions:
			if s._counter.reason(s._day, "appraise", visit.visit_id, action.id).is_empty():
				var result := s.counter_command("appraise", visit.visit_id, action.id)
				check(result.ok or visit.status != "active", "inspect available evidence: " + result.message)
				driver.drain(s)
		for clue in visit.item.revealed_clue_ids:
			if item.find_clue(clue).leverage > 0 and s._counter.reason(s._day, "pressure", visit.visit_id, clue).is_empty():
				var result := s.counter_command("pressure", visit.visit_id, clue)
				check(result.ok or visit.status != "active", "negotiate using revealed clue: " + result.message)
				driver.drain(s)
		if visit.status == "active":
			var pawn_only := visit.transaction_modes == ["pawn"]
			var offer := 40 if pawn_only else mini(visit.trade.asking_price, s._counter.appraisal.valuation(visit.item, item).x)
			if s._day.state.cash < offer: cash_shortages += 1
			else:
				var command := "pawn" if pawn_only else "offer"
				if s._counter.reason(s._day, command, visit.visit_id, "", offer).is_empty():
					# A legal offer can be refused; that is an economic outcome, not a test failure.
					s.counter_command(command, visit.visit_id, "", offer)
					driver.drain(s)
	if visit.status == "active":
		var result := s.counter_command("reject", visit.visit_id)
		check(result.ok or visit.status != "active", "decline remaining offer: " + result.message)

func sell_current(s: RunSession, policy: String) -> bool:
	var best := {}
	for buyer in s.counter_model().inventory.sales.buyers:
		if not buyer.reason.is_empty(): continue
		if policy == "appointment" and s._day.state.current_night_index <= 6 and buyer.id != PreparationService.BUYER: continue
		if policy == "patient" and s._day.state.current_night_index < 7 and buyer.id not in ["buyer_lu", PreparationService.BUYER]: continue
		for item in buyer.stock:
			if not item.reason.is_empty(): continue
			if policy == "positive" and item.price <= item.cost: continue
			if not best.has(item.id) or item.price > best[item.id].price: best[item.id] = {"buyer": buyer.id, "price": item.price}
	var batches := {}
	var totals := {}
	for id in best:
		var buyer: String = best[id].buyer
		if not batches.has(buyer): batches[buyer] = []; totals[buyer] = 0
		batches[buyer].append(id); totals[buyer] += best[id].price
	var chosen := ""
	for buyer in batches:
		if chosen.is_empty() or totals[buyer] > totals[chosen]: chosen = buyer
	if chosen.is_empty(): return false
	var buyer: Dictionary = s.counter_model().inventory.sales.buyers.filter(func(b: Dictionary) -> bool: return b.id == chosen)[0]
	var preview := CashFlowReadModel.sale_preview(s.counter_model().inventory.cash_flow, buyer, batches[chosen])
	check(preview.valid and preview.executable, "preview allows actual selected trip")
	check(s.sell_batch(chosen, batches[chosen]).ok, "sell known current best quotes")
	check(s._day.state.cash == preview.cash and CashFlowReadModel.build(s._day.state, run_def).balance == preview.balance, "real transaction exactly matches cash flow preview")
	return true

func finish_comparison(s: RunSession) -> void:
	for command in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
		if s._day.state.phase in [&"bankrupt", &"dead", &"run_ended"]: break
		driver.drain(s)
		if command == "resolve_night":
			for ticket in s._commerce.pawns.maturities(s._day.state): check(s.choose_pawn_disposal(ticket.ticket_id, "keep").ok, "unredeemed collateral disposition")
		driver.action(s, command)
		if command in ["resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]: driver.resume(s)
