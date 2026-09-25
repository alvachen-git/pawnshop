class_name CameraEconomy
extends RefCounted

const ITEM := "item_luxury_embroidery"
const BASE := {"original":800,"rebuilt":480,"imitation":120}
const LENS := {"clear":1.0,"haze":.8,"scratched":.65}
const MECHANISM := {"smooth":1.0,"sticky":.8,"stuck":.5}
const ENGRAVINGS := ["legacy", "letter_swap", "extra_letter", "city_swap"]

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("camera_appraisal_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return item != null and item.definition_id == ITEM and state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func valuation(identity: String, lens: String, mechanism: String, damage: String) -> int:
	return maxi(1,roundi(float(BASE[identity])*float(LENS[lens])*float(MECHANISM[mechanism])*float(TieredAppraisal.RETAIN[damage])/100.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("camera_value"): return
	var key := item.instance_id+"/camera43/"
	var identity: String = {"sound":"original","mended":"rebuilt","flawed":"imitation"}[item.selected_variant_id]
	var l := VarietyService.rng(state.run_seed,key+"lens").randi_range(0,99)
	var m := VarietyService.rng(state.run_seed,key+"mechanism").randi_range(0,99)
	var lens := "clear" if l<70 else "haze" if l<90 else "scratched"
	var mechanism := "smooth" if m<70 else "sticky" if m<90 else "stuck"
	item.goods["camera_value"] = {"identity":identity,"lens":lens,"mechanism":mechanism,"fault_at":VarietyService.pick(["aperture","shutter","both"],state.run_seed,key+"fault"),"actual":valuation(identity,lens,mechanism,item.goods.precision.damage)}
	item.goods.camera_value["engraving"] = VarietyService.pick(ENGRAVINGS,state.run_seed,key+"engraving") if identity=="imitation" else "standard"

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("camera_owner",{})

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var key := visit.visit_id+"/camera43/"
	var n := VarietyService.rng(state.run_seed,key+"skill").randi_range(0,99)
	var skill := "expert" if n<30 else "ordinary" if n<80 else "novice"
	var identity: String = visit.item.goods.camera_value.identity
	var rng := VarietyService.rng(state.run_seed,key+"belief")
	if rng.randi_range(0,99) >= {"expert":100,"ordinary":70,"novice":40}[skill]:
		var others := BASE.keys(); others.erase(identity); identity=others[rng.randi_range(0,1)]
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var row := WealthyCustomers.trade(state,visit)
	row["camera_owner"] = {"skill":skill,"rate":rates[VarietyService.rng(state.run_seed,key+"rate").randi_range(0,rates.size()-1)],"urgent":VarietyService.rng(state.run_seed,key+"urgent").randi_range(0,99)<30,"belief":{"identity":identity,"lens":"clear","mechanism":"smooth"}}
	reprice_initial(state,visit)
	row.value=800; row.reference=WealthyCustomers.reference_price(800,visit.transaction_modes[0])
	visit.voice=visit.voice.duplicate(true)
	visit.voice.introduction=LuxuryCarry.origin(state,visit)+"这架洋相机，请您掌眼。"+("眼下急等现钱，现付便好商量。" if owner(state,visit).urgent else "")
	if row.funding>0: visit.voice.introduction+="\n这回至少需筹%d银元。" % row.funding
	CameraNegotiation.prepare(state,visit)

static func reprice_initial(state: RunState, visit: CustomerVisit) -> void:
	var row:=WealthyCustomers.trade(state,visit);var o:=owner(state,visit)
	var base:=WealthyCustomers.reference_price(valuation(o.belief.identity,o.belief.lens,o.belief.mechanism,visit.item.goods.precision.damage),visit.transaction_modes[0])
	var factor:=float(o.rate)/100.0*(.85 if o.urgent else 1.0)
	visit.trade.reserve_price=maxi(int(row.funding),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	visit.trade.asking_price=maxi(visit.trade.reserve_price,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.opening_price=visit.trade.asking_price

static func operation(item: ItemInstance, part: String) -> String:
	var f: Dictionary=item.goods.camera_value
	return f.mechanism if f.fault_at in [part,"both"] else "smooth"
