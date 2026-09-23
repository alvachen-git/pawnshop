class_name PearlEconomy
extends RefCounted

const ITEM := "item_luxury_pearl_necklace"
const QUALITY := {"fine":1.0,"lower":.6,"imitation":.05}
const COUNTS := {"none":0,"few":2,"some":8,"most":24,"all":32}

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("pearl_appraisal_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return item != null and item.definition_id == ITEM and state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func bucket(count: int) -> String:
	return "none" if count == 0 else "few" if count <= 3 else "some" if count <= 15 else "most" if count < 32 else "all"

static func value(beads: Array, damage: String) -> int:
	var total := 0.0
	for bead in beads: total += float(bead.weight)*float(QUALITY[bead.quality])
	return maxi(1,roundi((40.0+400.0*total/52.0)*float(TieredAppraisal.RETAIN[damage])/100.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("pearl_value"): return
	var rng := VarietyService.rng(state.run_seed,item.instance_id+"/pearl38/composition")
	var kind: String = "fine" if item.selected_variant_id == "sound" else "imitation" if item.selected_variant_id == "flawed" else ["lower","mixed"][rng.randi_range(0,1)]
	var count := 0
	if kind == "lower": count = [2,4,8][rng.randi_range(0,2)]
	if kind == "mixed": count = [1,2,4,8,16][rng.randi_range(0,4)]
	if kind == "imitation": count = 32
	var order := range(32)
	for i in range(31,0,-1):
		var j := rng.randi_range(0,i); var saved: int = order[i]; order[i] = order[j]; order[j] = saved
	var beads := []
	for i in 32:
		var size := 3 if i in [14,15,16,17] else 2 if i >= 8 and i <= 23 else 1
		var quality := "fine"
		if i in order.slice(0,count): quality = "lower" if kind == "lower" else "imitation"
		beads.append({"index":i,"weight":size,"quality":quality,"texture":rng.randi_range(0,2),"hole_angle":rng.randi_range(0,2),"tint":rng.randi_range(0,4)})
	item.goods["pearl_value"] = {"kind":kind,"beads":beads,"actual":value(beads,item.goods.precision.damage)}

static func material(item: ItemInstance) -> String:
	return bucket(item.goods.pearl_value.beads.filter(func(b: Dictionary) -> bool: return b.quality == "imitation").size())

static func repair(item: ItemInstance) -> String:
	return "altered" if item.goods.pearl_value.beads.any(func(b: Dictionary) -> bool: return b.quality == "lower") else "intact"

static func valuation(material_claim: String, repair_claim: String, damage: String) -> int:
	var fraction := float(COUNTS[material_claim])/32.0
	var coefficient := fraction*.05+(1.0-fraction)*(.9 if repair_claim == "altered" else 1.0)
	return maxi(1,roundi((40+400*coefficient)*float(TieredAppraisal.RETAIN[damage])/100.0))

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("pearl_owner",{})

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var rng := VarietyService.rng(state.run_seed,visit.visit_id+"/pearl38/owner")
	var roll := rng.randi_range(0,99)
	var skill := "expert" if roll < 30 else "ordinary" if roll < 80 else "novice"
	var kind: String = visit.item.goods.pearl_value.kind
	if rng.randi_range(0,99) >= {"expert":100,"ordinary":70,"novice":40}[skill]:
		var others := ["fine","lower","mixed","imitation"]; others.erase(kind); kind = others[rng.randi_range(0,2)]
	var materials := "all" if kind == "imitation" else "none"
	if kind == "mixed": materials = material(visit.item) if visit.item.goods.pearl_value.kind == "mixed" else "some"
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var row := WealthyCustomers.trade(state,visit)
	row["pearl_owner"] = {"skill":skill,"rate":rates[rng.randi_range(0,rates.size()-1)],"urgent":VarietyService.rng(state.run_seed,visit.visit_id+"/pearl38/urgency").randi_range(0,99)<30,"belief":{"material":materials,"repair":"altered" if kind == "lower" else "intact"}}
	reprice_initial(state,visit)
	var o := owner(state,visit)
	row.value = 440; row.reference = WealthyCustomers.reference_price(440,visit.transaction_modes[0])
	visit.voice = visit.voice.duplicate(true)
	visit.voice.introduction = LuxuryCarry.origin(state,visit)+("眼下急等现钱，能现付就好商量。" if o.urgent else "您看过再谈。")
	if row.funding > 0: visit.voice.introduction += "\n这回至少需筹%d银元。" % row.funding
	PearlNegotiation.prepare(state,visit)


static func reprice_initial(state: RunState, visit: CustomerVisit) -> void:
	var row := WealthyCustomers.trade(state,visit)
	var o := owner(state,visit)
	var base := WealthyCustomers.reference_price(valuation(o.belief.material,o.belief.repair,visit.item.goods.precision.damage),visit.transaction_modes[0])
	var factor := float(o.rate)/100.0*(.85 if o.urgent else 1.0)
	visit.trade.reserve_price = maxi(int(row.funding),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.opening_price = visit.trade.asking_price
