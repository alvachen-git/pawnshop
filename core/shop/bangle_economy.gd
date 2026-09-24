class_name BangleEconomy
extends RefCounted

const ITEM := "item_luxury_gold_bangle"
const BASE := {"fine":440,"lower":330,"plated":70}
const WEIGHTS := {"fine":[30,31,32],"lower":[28,30,31],"plated":[24,28,30]}

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("bangle_appraisal_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return item != null and item.definition_id == ITEM and state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func valuation(material_claim: String, repair_claim: String, damage: String) -> int:
	return maxi(1,roundi(float(BASE[material_claim])*(.85 if repair_claim == "altered" else 1.0)*float(TieredAppraisal.RETAIN[damage])/100.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("bangle_value"): return
	var kind: String = {"sound":"fine","mended":"lower","flawed":"plated"}[item.selected_variant_id]
	var key := item.instance_id+"/bangle39/"
	var repaired := VarietyService.rng(state.run_seed,key+"repair").randi_range(0,99)<25
	var weight: int = WEIGHTS[kind][VarietyService.rng(state.run_seed,key+"weight").randi_range(0,2)]
	var angles := {}
	for part in BangleAppraisal.PARTS: angles[part] = VarietyService.rng(state.run_seed,key+"angle/"+part).randi_range(0,2)
	item.goods["bangle_value"] = {"material":kind,"repair":"altered" if repaired else "intact","weight":weight,"angles":angles,"actual":valuation(kind,"altered" if repaired else "intact",item.goods.precision.damage)}

static func material(item: ItemInstance) -> String:
	return item.goods.bangle_value.material

static func repair(item: ItemInstance) -> String:
	return item.goods.bangle_value.repair

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("bangle_owner",{})

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var key := visit.visit_id+"/bangle39/"
	var roll := VarietyService.rng(state.run_seed,key+"skill").randi_range(0,99)
	var skill := "expert" if roll<30 else "ordinary" if roll<80 else "novice"
	var belief := {"material":material(visit.item),"repair":repair(visit.item)}
	for part in ["material","repair"]:
		var rng := VarietyService.rng(state.run_seed,key+"belief/"+part)
		if rng.randi_range(0,99) >= {"expert":100,"ordinary":70,"novice":40}[skill]:
			var others: Array = BASE.keys() if part == "material" else ["intact","altered"]
			others.erase(belief[part]); belief[part] = others[rng.randi_range(0,others.size()-1)]
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var row := WealthyCustomers.trade(state,visit)
	row["bangle_owner"] = {"skill":skill,"rate":rates[VarietyService.rng(state.run_seed,key+"rate").randi_range(0,rates.size()-1)],"urgent":VarietyService.rng(state.run_seed,key+"urgent").randi_range(0,99)<30,"belief":belief}
	reprice_initial(state,visit)
	row.value = 440; row.reference = WealthyCustomers.reference_price(440,visit.transaction_modes[0])
	visit.voice = visit.voice.duplicate(true)
	visit.voice.introduction = LuxuryCarry.origin(state,visit)+("眼下急等现钱，能现付就好商量。" if owner(state,visit).urgent else "这只花雕金镯，请您掌眼。")
	if row.funding > 0: visit.voice.introduction += "\n这回至少需筹%d银元。" % row.funding
	BangleNegotiation.prepare(state,visit)

static func reprice_initial(state: RunState, visit: CustomerVisit) -> void:
	var row := WealthyCustomers.trade(state,visit); var o := owner(state,visit)
	var base := WealthyCustomers.reference_price(valuation(o.belief.material,o.belief.repair,visit.item.goods.precision.damage),visit.transaction_modes[0])
	var factor := float(o.rate)/100.0*(.85 if o.urgent else 1.0)
	visit.trade.reserve_price = maxi(int(row.funding),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.opening_price = visit.trade.asking_price
