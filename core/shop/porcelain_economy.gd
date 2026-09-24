class_name PorcelainEconomy
extends RefCounted

const ITEM := "item_luxury_porcelain_vase"
const BASE := {"yuan":900,"ming":600,"qing":300,"republic":90}
const CRAFT := {"rough":0.6,"standard":1.0,"fine":1.4}

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("porcelain_appraisal_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return item != null and item.definition_id == ITEM and state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func valuation(era_claim: String, craft_claim: String, damage: String) -> int:
	return maxi(1,roundi(float(BASE[era_claim])*float(CRAFT[craft_claim])*float(TieredAppraisal.RETAIN[damage])/100.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("porcelain_value"): return
	var key := item.instance_id+"/porcelain41/"
	var age: String = "qing" if item.selected_variant_id == "mended" else "republic" if item.selected_variant_id == "flawed" else "yuan" if VarietyService.rng(state.run_seed,key+"era").randi_range(0,99)<20 else "ming"
	var roll := VarietyService.rng(state.run_seed,key+"craft").randi_range(0,99)
	var quality := "rough" if roll<20 else "standard" if roll<80 else "fine"
	var damage_roll := VarietyService.rng(state.run_seed,key+"damage").randi_range(0,99)
	var damage := "intact" if damage_roll<60 else "minor" if damage_roll<90 else "major"
	var hidden := VarietyService.rng(state.run_seed,key+"difficulty").randi_range(0,99)>=70
	item.goods["precision"] = {"damage":damage,"hidden":hidden}
	item.goods["porcelain_value"] = {"era":age,"craft":quality,"sample":VarietyService.rng(state.run_seed,key+"sample").randi_range(0,1),"hidden":hidden,"actual":valuation(age,quality,damage)}

static func era(item: ItemInstance) -> String:
	return item.goods.porcelain_value.era

static func craft(item: ItemInstance) -> String:
	return item.goods.porcelain_value.craft

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("porcelain_owner",{})

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var key := visit.visit_id+"/porcelain41/"
	var roll := VarietyService.rng(state.run_seed,key+"skill").randi_range(0,99)
	var skill := "expert" if roll<30 else "ordinary" if roll<80 else "novice"
	var belief := {"era":era(visit.item),"craft":craft(visit.item)}
	for part in ["era","craft"]:
		var rng := VarietyService.rng(state.run_seed,key+"belief/"+part)
		if rng.randi_range(0,99) >= {"expert":100,"ordinary":70,"novice":40}[skill]:
			var others: Array = BASE.keys() if part == "era" else CRAFT.keys()
			others.erase(belief[part]); belief[part] = others[rng.randi_range(0,others.size()-1)]
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var row := WealthyCustomers.trade(state,visit)
	row["porcelain_owner"] = {"skill":skill,"rate":rates[VarietyService.rng(state.run_seed,key+"rate").randi_range(0,rates.size()-1)],"urgent":VarietyService.rng(state.run_seed,key+"urgent").randi_range(0,99)<30,"belief":belief}
	row.funding = 0
	if visit.transaction_modes[0] == "pawn":
		row.funding = 293 if visit.customer_id == "customer_wealthy_factory" else 338 if visit.customer_id == "customer_wealthy_comprador" else 0
	reprice_initial(state,visit)
	row.value = 1260; row.reference = WealthyCustomers.reference_price(1260,visit.transaction_modes[0])
	visit.voice = visit.voice.duplicate(true)
	visit.voice.introduction = LuxuryCarry.origin(state,visit)+"这只青花瓶，我按"+PorcelainNegotiation.OPTIONS.era[belief.era]+"时的物件收来的，请您掌眼。"+("眼下急等现钱，能现付就好商量。" if owner(state,visit).urgent else "")
	if row.funding > 0: visit.voice.introduction += "\n这回至少需筹%d银元。" % row.funding
	PorcelainNegotiation.prepare(state,visit)

static func reprice_initial(state: RunState, visit: CustomerVisit) -> void:
	var row := WealthyCustomers.trade(state,visit); var o := owner(state,visit)
	var base := WealthyCustomers.reference_price(valuation(o.belief.era,o.belief.craft,visit.item.goods.precision.damage),visit.transaction_modes[0])
	var factor := float(o.rate)/100.0*(.85 if o.urgent else 1.0)
	visit.trade.reserve_price = maxi(int(row.funding),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.opening_price = visit.trade.asking_price
