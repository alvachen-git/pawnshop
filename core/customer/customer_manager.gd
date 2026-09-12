class_name CustomerManager
extends RefCounted

func prepare_night(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> void:
	if FamiliarStories.enabled(run): state.familiar_plan = FamiliarStories.plan(run, catalog, state.run_seed)
	state.visits.clear()
	var return_delay := PawnReturnService.prepare(state, catalog)
	if not run.variety.is_empty():
		VarietyService.prepare(state, run, catalog, return_delay)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = state.run_seed + state.current_night_index * 104729
	for slot in run.customer_slots:
		if state.current_night_index < slot.night_min or state.current_night_index > slot.night_max: continue
		var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
		var item_id: String = slot.item_id if not slot.item_id.is_empty() else customer.item_pool[rng.randi_range(0, customer.item_pool.size() - 1)]
		var item_def := catalog.get_definition("items", item_id) as ItemDefinition
		var variant := item_def.find_variant(slot.variant_id)
		if variant == null:
			var total := 0.0
			for option in item_def.possible_variants: total += option.weight
			var roll := rng.randf() * total
			variant = item_def.possible_variants.back()
			for option in item_def.possible_variants:
				roll -= option.weight
				if roll < 0:
					variant = option
					break
		var visit := CustomerVisit.new()
		visit.visit_id = "%s/%d/%s" % [run.id, state.current_night_index, slot.id]
		visit.customer_id = customer.id
		visit.arrival = slot.arrival + return_delay
		visit.expires_at = visit.arrival + customer.terms.wait_minutes
		visit.item = ItemInstance.new()
		visit.item.instance_id = "item/" + visit.visit_id
		visit.item.definition_id = item_def.id
		visit.item.selected_variant_id = variant.id
		visit.trade.opening_price = maxi(1, int(round(item_def.base_value * customer.terms.ask_multiplier)))
		visit.trade.asking_price = visit.trade.opening_price
		visit.trade.reserve_price = maxi(1, int(round(visit.trade.opening_price * customer.terms.reserve_ratio)))
		visit.trade.rounds_left = customer.max_quote_rounds
		visit.trade.patience = customer.patience
		# A visit may reserve extra attempts without changing quote acceptance.
		visit.trade.rounds_left = maxi(visit.trade.rounds_left, int(slot.tutorial.get("min_quote_rounds", 0)))
		visit.trade.patience = maxi(visit.trade.patience, int(slot.tutorial.get("min_patience", 0)))
		var scenario := TradeScenarioService.for_slot(run, slot.id)
		if scenario != null:
			TradeScenarioService.prepare(visit, scenario, state.run_seed)
			var selection := {"visit_id": visit.visit_id, "scenario_id": scenario.id, "variant_id": visit.item.selected_variant_id, "situation_id": visit.situation_id, "reaction_id": visit.reaction_id}
			if selection not in state.scenario_selections: state.scenario_selections.append(selection)
		state.visits.append(visit)
	state.visits.sort_custom(func(a: CustomerVisit, b: CustomerVisit) -> bool: return a.arrival < b.arrival)

func update(state: RunState, pending_quote_visit_id := "") -> void:
	if state.phase == &"pre_open": return
	PawnReturnService.arrive(state)
	for visit in state.visits:
		if visit.status not in ["scheduled", "waiting", "active"]: continue
		if state.phase != &"open":
			finish(state, visit, "shop_closed")
		elif state.game_minutes >= visit.expires_at and visit.visit_id != pending_quote_visit_id:
			finish(state, visit, "timed_out")
		elif state.game_minutes >= visit.arrival and visit.status == "scheduled":
			visit.status = "waiting"
	if active(state) == null and state.phase == &"open" and PawnReturnService.current(state).is_empty():
		for visit in state.visits:
			if visit.status == "waiting":
				visit.status = "active"
				break

func active(state: RunState) -> CustomerVisit:
	for visit in state.visits:
		if visit.status == "active": return visit
	return null

func finish(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if visit.status not in ["scheduled", "waiting", "active"]: return
	visit.status = outcome
	state.visit_history.append({"visit_id": visit.visit_id, "customer_id": visit.customer_id, "night": state.current_night_index, "minute": state.game_minutes, "outcome": outcome})
