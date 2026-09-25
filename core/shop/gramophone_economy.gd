class_name GramophoneEconomy
extends RefCounted

const ITEM := "item_luxury_mantel_clock"
const BASE := {"original":700,"rebuilt":420,"imitation":100}
const SOUND := {"clear":1.0,"rasping":.8,"muffled":.65}
const MOTOR := {"steady":1.0,"wavering":.8,"stopping":.5}
const ENGRAVINGS := ["letter_swap"]

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("gramophone_appraisal_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return item != null and item.definition_id == ITEM and state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func valuation(identity: String, sound: String, motor: String, damage: String) -> int:
	return maxi(1,roundi(float(BASE[identity])*float(SOUND[sound])*float(MOTOR[motor])*float(TieredAppraisal.RETAIN[damage])/100.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("gramophone_value"): return
	var key := item.instance_id+"/gramophone44/"
	var identity: String = {"sound":"original","mended":"rebuilt","flawed":"imitation"}[item.selected_variant_id]
	var l := VarietyService.rng(state.run_seed,key+"sound").randi_range(0,99)
	var m := VarietyService.rng(state.run_seed,key+"motor").randi_range(0,99)
	var sound := "clear" if l<70 else "rasping" if l<90 else "muffled"
	var motor := "steady" if m<70 else "wavering" if m<90 else "stopping"
	item.goods["gramophone_value"] = {"identity":identity,"sound":sound,"motor":motor,"record_worn":VarietyService.rng(state.run_seed,key+"record").randi_range(0,99)<40,"initial_wound":VarietyService.rng(state.run_seed,key+"winding").randi_range(0,99)<50,"actual":valuation(identity,sound,motor,item.goods.precision.damage)}
	item.goods.gramophone_value["engraving"] = VarietyService.pick(ENGRAVINGS,state.run_seed,key+"engraving") if identity=="imitation" else "standard"

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("gramophone_owner",{})

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var key := visit.visit_id+"/gramophone44/"
	var n := VarietyService.rng(state.run_seed,key+"skill").randi_range(0,99)
	var skill := "expert" if n<30 else "ordinary" if n<80 else "novice"
	var identity: String = visit.item.goods.gramophone_value.identity
	var rng := VarietyService.rng(state.run_seed,key+"belief")
	if rng.randi_range(0,99) >= {"expert":100,"ordinary":70,"novice":40}[skill]:
		var others := BASE.keys(); others.erase(identity); identity=others[rng.randi_range(0,1)]
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var row := WealthyCustomers.trade(state,visit)
	row["gramophone_owner"] = {"skill":skill,"rate":rates[VarietyService.rng(state.run_seed,key+"rate").randi_range(0,rates.size()-1)],"urgent":VarietyService.rng(state.run_seed,key+"urgent").randi_range(0,99)<30,"belief":{"identity":identity,"sound":"clear","motor":"steady"}}
	reprice_initial(state,visit)
	row.value=700; row.reference=WealthyCustomers.reference_price(700,visit.transaction_modes[0])
	visit.voice=visit.voice.duplicate(true)
	visit.voice.introduction=LuxuryCarry.origin(state,visit)+"这架留声机，请您掌眼。"+("眼下急等现钱，现付便好商量。" if owner(state,visit).urgent else "")
	if row.funding>0: visit.voice.introduction+="\n这回至少需筹%d银元。" % row.funding
	GramophoneNegotiation.prepare(state,visit)

static func reprice_initial(state: RunState, visit: CustomerVisit) -> void:
	var row:=WealthyCustomers.trade(state,visit);var o:=owner(state,visit)
	var base:=WealthyCustomers.reference_price(valuation(o.belief.identity,o.belief.sound,o.belief.motor,visit.item.goods.precision.damage),visit.transaction_modes[0])
	var factor:=float(o.rate)/100.0*(.85 if o.urgent else 1.0)
	visit.trade.reserve_price=maxi(WealthyCustomers.minimum_price(state,visit),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	visit.trade.asking_price=maxi(visit.trade.reserve_price,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.opening_price=visit.trade.asking_price
