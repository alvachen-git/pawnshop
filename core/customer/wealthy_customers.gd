class_name WealthyCustomers
extends RefCounted

const COMPRADOR := "customer_wealthy_comprador"
const NAMES := {
	"customer_wealthy_silk":"周锦生", "customer_wealthy_factory":"李衡",
	"customer_wealthy_opera":"程玉笙", "customer_wealthy_antique":"沈季安",
	"customer_wealthy_comprador":"Edward"}
const TIERS := [[80,10,55,35,25],[60,20,55,25,20],[40,35,50,15,15],[20,50,50,0,10],[10,70,30,0,0],[1,85,15,0,0],[0,100,0,0,0]]

static func fixed_people(run: RunDefinition) -> bool:
	return run.variety.get("wealthy_fixed_people", 0) == 1

static func person(customer: CustomerDefinition) -> Dictionary:
	return {"id":"wealthy/" + customer.id, "name":NAMES[customer.id], "portrait":customer.portrait_asset_id}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("luxury", {}).get("version", 0) == 1

static func active(state: RunState) -> bool:
	return state.shop_growth.has("luxury")

static func initial() -> Dictionary:
	return {"nights": {}, "advertisements": [], "transactions": [], "milestones": [], "appraisals": {}, "trades": {}}

static func data(state: RunState) -> Dictionary:
	return state.shop_growth.get("luxury", {})

static func config(state: RunState) -> Dictionary:
	var run := state.ghost_catalog.get_definition("runs", state.run_definition_id) as RunDefinition
	return run.variety.luxury

static func is_customer(id: String) -> bool:
	return id.begins_with("customer_wealthy_")

static func is_item(id: String) -> bool:
	return id.begins_with("item_luxury_")

static func tier(reputation: int) -> Array:
	for row in TIERS:
		if reputation >= int(row[0]): return row
	return TIERS.back()

static func draw(seed_value: int, night: int, reputation: int, profiles: Dictionary) -> Array[String]:
	var policy := tier(reputation)
	var key := "wealthy/%d/" % night
	var roll := VarietyService.rng(seed_value, key + "count").randi_range(0,99)
	var count := 0 if roll < int(policy[1]) else 1 if roll < int(policy[1]) + int(policy[2]) else 2
	var result: Array[String] = []
	if count == 0: return result
	if VarietyService.rng(seed_value, key + "comprador").randi_range(0,99) < int(policy[4]): result.append(COMPRADOR)
	while result.size() < count:
		var pool: Array = []
		for id in profiles:
			if id in result: continue
			for index in int(profiles[id].weight): pool.append(id)
		result.append(VarietyService.pick(pool, seed_value, key + "profession/%d" % result.size()))
	return result

static func replaceable(row: Dictionary) -> bool:
	return ReputationService.ordinary(row) and not row.has("seven_role") and not row.get("wealthy", false) and not row.visit_id.ends_with("/prep_extra")

static func invited(state: RunState, row: Dictionary) -> bool:
	# Explicit appointments keep their protection when a closure moves them to another night.
	return state.preparation_history.any(func(entry: Dictionary) -> bool: return entry.action in ["attract","target","seek"] and row.visit_id in entry.get("visit_ids",[]))

static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not enabled(run): return rows
	var records: Dictionary = data(state).nights
	var key := str(state.current_night_index)
	if not records.has(key):
		var reputation := int(SocialRules.night(state).reputation)
		var selected := draw(state.run_seed, state.current_night_index, reputation, run.variety.luxury.profiles)
		var pool := rows.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index and replaceable(row) and not invited(state,row))
		var changes: Array = []
		for id in selected:
			if pool.is_empty(): break
			var old: Dictionary = VarietyService.pick(pool, state.run_seed, "wealthy/slot/" + key + id)
			pool.erase(old)
			changes.append(make_row(state, run, catalog, old, id, rows + changes))
		records[key] = {"reputation": reputation, "selected": selected, "replacements": changes}
	var result: Array[Dictionary] = rows.duplicate(true)
	for change in records[key].replacements:
		for index in result.size():
			if result[index].visit_id == change.visit_id: result[index] = change.duplicate(true); break
	return result

static func make_row(state: RunState, run: RunDefinition, catalog: ContentCatalog, old: Dictionary, id: String, names: Array) -> Dictionary:
	var customer := catalog.get_definition("customers", id) as CustomerDefinition
	var profile: Dictionary = run.variety.luxury.profiles[id]
	var key: String = old.visit_id + "/wealthy/" + id
	var roll := VarietyService.rng(state.run_seed, key + "/condition").randi_range(0,99)
	var variant := "sound" if roll < int(profile.weights[0]) else "mended" if roll < int(profile.weights[0]) + int(profile.weights[1]) else "flawed"
	var modes := ["pawn"] if VarietyService.rng(state.run_seed,key + "/mode").randi_range(0,99) < int(profile.pawn_percent) else ["sell"]
	var name := ""
	var used: Array = names.map(func(r: Dictionary) -> String: return r.person.name)
	var surnames: Array = run.variety.surnames
	var given: Array = customer.persona.names
	var start := VarietyService.rng(state.run_seed,key + "/name").randi_range(0,surnames.size()*given.size()-1)
	for offset in surnames.size()*given.size():
		var index := (start + offset) % (surnames.size()*given.size())
		name = surnames[index / given.size()] + given[index % given.size()]
		if name not in used and name not in FamiliarStories.NAMES: break
	return {"visit_id": old.visit_id, "night": old.night, "arrival": old.arrival, "wealthy": true,
		"customer_id": id, "context_id": "wealthy/" + id, "item_id": LuxuryCarry.pick(run,customer,state.run_seed,key),
		"variant_id": variant, "source": "", "situation": "ordinary", "reaction": "explain", "transaction_modes": modes,
		"wait_minutes": customer.terms.wait_minutes, "terms_id": PawnRedemptionPolicy.terms_for(run,customer,state.run_seed,old.visit_id,customer.pawn_terms_id),
		"person": person(customer) if fixed_people(run) else {"id": "person/" + old.visit_id, "name": name, "portrait": customer.portrait_asset_id}}

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	if not active(state) or not is_customer(visit.customer_id): return
	TieredAppraisal.attach(state,visit.item,visit.visit_id)
	var profile: Dictionary = config(state).profiles[visit.customer_id]
	var item := state.ghost_catalog.get_definition("items",visit.item.definition_id) as ItemDefinition
	var mode: String = visit.transaction_modes[0]
	var reference := reference_price(int(item.base_value),mode)
	var funding := roundi(item.base_value * 0.5 * float(profile.funding_percent) / 100.0) if mode == "pawn" else 0
	data(state).trades[visit.visit_id] = {"value": int(item.base_value), "reference": reference, "funding": funding, "evidence_used": false, "intimidation": 1.0}
	visit.trade.opening_price = roundi(reference * float(profile.asking_percent) / 100.0)
	visit.trade.asking_price = visit.trade.opening_price
	visit.trade.reserve_price = maxi(funding,roundi(reference * float(profile.reserve_percent) / 100.0))
	if funding > 0: visit.voice.introduction += "\n‘这回至少要筹到%d银元，少了办不成。’" % funding
	if LuxuryCarry.enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id)):
		visit.voice = visit.voice.duplicate(true)
		visit.voice.introduction = LuxuryCarry.origin(state,visit) + ("\n这回至少需筹%d银元。" % funding if funding > 0 else "")
	if WatchEconomy.handles(state,visit.item): WatchEconomy.prepare(state,visit)
	if PearlEconomy.handles(state,visit.item): PearlEconomy.prepare(state,visit)

static func reference_price(value: int, mode: String) -> int:
	return roundi(value * (0.5 if mode == "pawn" else 0.7))

static func trade(state: RunState, visit: CustomerVisit) -> Dictionary:
	return data(state).get("trades",{}).get(visit.visit_id,{})

static func quote(state: RunState, visit: CustomerVisit, customer: CustomerDefinition, amount: int) -> bool:
	visit.trade.rounds_left -= 1
	visit.trade.offers.append(amount)
	if amount >= visit.trade.reserve_price: return true
	visit.trade.patience -= customer.terms.failed_quote_cost
	visit.trade.asking_price = maxi(visit.trade.reserve_price,visit.trade.asking_price - maxi(1,roundi(int(trade(state,visit).reference)*0.05)))
	return false
