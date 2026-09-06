class_name VarietyService
extends RefCounted

static func rng(seed_value: int, key: String) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = (seed_value + int(key.hash())) & 0x7fffffff
	return random

static func pick(values: Array, seed_value: int, key: String) -> Variant:
	return values[rng(seed_value, key).randi_range(0, values.size() - 1)]

static func plan(run: RunDefinition, catalog: ContentCatalog, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if run.variety.is_empty(): return result
	var names: Array = []
	for night in range(1, run.total_nights + 1):
		for slot in run.customer_slots:
			if night < slot.night_min or night > slot.night_max: continue
			var id := "%s/%d/%s" % [run.id, night, slot.id]
			var fixed: bool = slot.id in run.variety.fixed_slots
			var constrained: bool = slot.id in run.variety.constrained_slots
			var candidates: Array = run.variety.customer_ids.duplicate()
			if constrained:
				candidates = candidates.filter(func(key: String) -> bool: return slot.item_id in (catalog.get_definition("customers", key) as CustomerDefinition).item_pool)
			var customer_id: String = slot.customer_id if fixed else pick(candidates, seed_value, id + "/customer")
			var customer := catalog.get_definition("customers", customer_id) as CustomerDefinition
			var pool: Array = customer.item_pool.filter(func(key: String) -> bool: return (catalog.get_definition("items", key) as ItemDefinition).item_type == "normal")
			var item_id: String = slot.item_id if fixed or constrained else pick(pool, seed_value, id + "/item")
			var item := catalog.get_definition("items", item_id) as ItemDefinition
			var variant_id: String = slot.variant_id if fixed or constrained else pick(item.possible_variants.map(func(v: ItemVariantDefinition) -> String: return v.id), seed_value, id + "/variant")
			var name := customer.terms.display_name
			if not fixed:
				var surname: Array = run.variety.surnames
				var given: Array = customer.persona.names
				var first := rng(seed_value, id + "/name").randi_range(0, surname.size() * given.size() - 1)
				for offset in surname.size() * given.size():
					var index := (first + offset) % (surname.size() * given.size())
					name = surname[int(index / given.size())] + given[index % given.size()]
					if name not in names: break
				names.append(name)
			var source := ""
			if not item.provenance.is_empty():
				var weights: Dictionary = item.provenance.weights
				var total := 0
				for key in ["none", "authentic", "mismatch"]: total += int(weights[key])
				var roll := rng(seed_value, id + "/source").randi_range(0, total - 1)
				for key in ["none", "authentic", "mismatch"]:
					roll -= int(weights[key])
					if roll < 0: source = key; break
			result.append({"visit_id": id, "night": night, "arrival": slot.arrival, "customer_id": customer_id,
				"person": {"id": "person/" + id, "name": name, "portrait": customer.portrait_asset_id},
				"item_id": item_id, "variant_id": variant_id, "source": source,
				"situation": "ordinary" if fixed or constrained else pick(["ordinary", "urgent"], seed_value, id + "/situation"),
				"reaction": pick(["admit", "explain", "evade"], seed_value, id + "/reaction"),
				"terms_id": customer.pawn_terms_id if fixed else pick(run.variety.terms_ids, seed_value, id + "/terms")})
	return OrdinarySamplePlan.apply(result, run, catalog, seed_value) if OrdinarySamplePlan.enabled(run) else result

static func prepare(state: RunState, run: RunDefinition, catalog: ContentCatalog, delay: int) -> void:
	var rows := plan(run, catalog, state.run_seed)
	if OrdinarySamplePlan.enabled(run):
		state.sample_plan.assign(rows)
		state.buyer_appointment = OrdinarySamplePlan.appointment(rows, catalog, state.run_seed)
	for row in rows:
		if row.night != state.current_night_index: continue
		if not state.ordinary_selections.any(func(old: Dictionary) -> bool: return old.visit_id == row.visit_id): state.ordinary_selections.append(row.duplicate(true))
		var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
		var item := catalog.get_definition("items", row.item_id) as ItemDefinition
		var visit := CustomerVisit.new()
		visit.visit_id = row.visit_id
		visit.customer_id = row.customer_id
		visit.person = row.person.duplicate(true)
		visit.voice = customer.persona
		if not item.provenance.is_empty(): visit.voice["source_claim"] = item.provenance.claim
		visit.pawn_terms_id = row.terms_id
		visit.arrival = int(row.arrival) + delay
		visit.expires_at = visit.arrival + customer.terms.wait_minutes
		visit.item = ItemInstance.new()
		visit.item.instance_id = "item/" + visit.visit_id
		visit.item.definition_id = item.id
		visit.item.selected_variant_id = row.variant_id
		if not row.source.is_empty(): visit.item.provenance = {"truth": row.source, "status": "unchecked", "evidence": [], "investigated": false}
		visit.trade.opening_price = maxi(1, roundi(item.base_value * customer.terms.ask_multiplier))
		visit.trade.asking_price = visit.trade.opening_price
		visit.trade.reserve_price = maxi(1, roundi(visit.trade.opening_price * customer.terms.reserve_ratio))
		visit.trade.rounds_left = customer.max_quote_rounds
		visit.trade.patience = customer.patience
		var scenario := TradeScenarioService.for_item(run, item.id)
		if scenario != null:
			visit.scenario_id = scenario.id
			visit.situation_id = row.situation
			visit.reaction_id = row.reaction
			if row.situation == "urgent" and not run.variety.get("profession_wait", false): visit.expires_at = visit.arrival + mini(customer.terms.wait_minutes, scenario.urgent_wait_minutes)
			var selection := {"visit_id": visit.visit_id, "scenario_id": scenario.id, "variant_id": row.variant_id, "situation_id": row.situation, "reaction_id": row.reaction}
			if selection not in state.scenario_selections: state.scenario_selections.append(selection)
		if row.has("wait_minutes"): visit.expires_at = visit.arrival + int(row.wait_minutes)
		visit.transaction_modes.assign(row.get("transaction_modes", customer.transaction_modes))
		if row.get("sample_role") == "pawn": visit.voice["introduction"] = "这件旧物舍不得卖。我只办活当，三夜后带票来赎。"
		if row.get("sample_role") == "urgent": visit.voice["introduction"] = "车子不等人。我只留三十分钟，掌柜挑要紧的看。"
		state.visits.append(visit)
	state.visits.sort_custom(func(a: CustomerVisit, b: CustomerVisit) -> bool: return a.arrival < b.arrival)

static func name_for(person: Dictionary, customer: CustomerDefinition) -> String:
	return customer.terms.display_name if person.is_empty() or person.name == customer.terms.display_name else String(person.name) + " · " + customer.terms.display_name

static func terms_for(visit: CustomerVisit, customer: CustomerDefinition) -> String:
	return customer.pawn_terms_id if visit.pawn_terms_id.is_empty() else visit.pawn_terms_id
