class_name WatchEconomy
extends RefCounted

const RETAIN := {"stable":100,"positional":80,"stopping":50}
const VALUES := {"sound":500,"mended":350,"flawed":100}
const BLUFF := "这表恐怕算不上原厂货，价钱得再让些"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("watch_economy_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return WatchAppraisal.handles(state,item) and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func valuation(variant: String, damage: String, operation: String) -> int:
	return maxi(1,roundi(float(VALUES[variant])*float(TieredAppraisal.RETAIN[damage])*float(RETAIN[operation])/10000.0))

static func attach(state: RunState, item: ItemInstance) -> void:
	if not handles(state,item) or item.goods.has("watch_value"): return
	var rng := VarietyService.rng(state.run_seed,item.instance_id+"/watch34/operation")
	var n := rng.randi_range(0,99)
	var operation := "stable" if n < 70 else "positional" if n < 90 else "stopping"
	item.goods.watch_value = {"operation":operation,"actual":valuation(item.selected_variant_id,item.goods.precision.damage,operation),
		"offset":VarietyService.rng(state.run_seed,item.instance_id+"/watch34/offset").randi_range(0,4)*0.2,
		"arrival_empty":VarietyService.rng(state.run_seed,item.instance_id+"/watch34/winding").randi_range(0,1) == 0}
	WatchMovementPatterns.attach(state,item)

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	attach(state,visit.item)
	var rng := VarietyService.rng(state.run_seed,visit.visit_id+"/watch34/owner")
	var n := rng.randi_range(0,99)
	var skill := "expert" if n < 30 else "ordinary" if n < 80 else "novice"
	var belief := visit.item.selected_variant_id
	var chance: int = {"expert":100,"ordinary":70,"novice":40}[skill]
	if rng.randi_range(0,99) >= chance:
		var others := ["sound","mended","flawed"]; others.erase(belief); belief = others[rng.randi_range(0,1)]
	var rates: Array = {"expert":[100],"ordinary":[80,100,120],"novice":[60,80,120,140]}[skill]
	var urgent := VarietyService.rng(state.run_seed,visit.visit_id+"/watch34/urgency").randi_range(0,99) < 30
	var row := WealthyCustomers.trade(state,visit)
	row.watch_owner = {"skill":skill,"belief":belief,"rate":rates[rng.randi_range(0,rates.size()-1)],"urgent":urgent,"used":[],"accepted":[],"bluff_used":false,"bluff_accepted":false,
		"bluff_roll":VarietyService.rng(state.run_seed,visit.visit_id+"/watch34/bluff").randi_range(0,99)}
	visit.voice = visit.voice.duplicate(true)
	var claim: String = {"sound":"这块表我一直当原厂金表留着。","mended":"听说里头换过机芯，价钱您再掂量。","flawed":"我只当普通仿表使，值几个钱就出手。"}[belief]
	visit.voice.introduction = claim + ("这会儿等钱办事，能现付，我愿再让些。" if urgent else "您看看，合适就谈。")
	if row.funding > 0: visit.voice.introduction += "\n这回至少需筹%d银元。" % row.funding
	row.reference = WealthyCustomers.reference_price(500,visit.transaction_modes[0])
	reprice(state,visit,true)
	visit.trade.opening_price = visit.trade.asking_price
	if WatchNegotiation.handles(state,visit.item): WatchNegotiation.prepare(state,visit)

static func owner(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("watch_owner",{})

static func reprice(state: RunState, visit: CustomerVisit, initial := false) -> void:
	if not initial and WatchNegotiation.handles(state,visit.item):
		WatchNegotiation.reprice(state,visit); return
	var row := WealthyCustomers.trade(state,visit); var o: Dictionary = row.watch_owner
	var accepted: Array = o.accepted
	var real_variant := visit.item.selected_variant_id
	var variant: String = real_variant if "identity" in accepted else o.belief
	var operation: String = visit.item.goods.watch_value.operation if "running" in accepted else "stable"
	var believed := valuation(variant,visit.item.goods.precision.damage,operation)
	var reference := WealthyCustomers.reference_price(believed,visit.transaction_modes[0])
	var factor: float = float(o.rate)/100.0*(0.85 if o.urgent else 1.0)*(0.85 if o.bluff_accepted else 1.0)*float(row.intimidation)
	var reserve := maxi(int(row.funding),roundi(reference*LuxuryCarry.percent(state,visit,"reserve")*factor))
	var asking := maxi(reserve,roundi(reference*LuxuryCarry.percent(state,visit,"asking")*factor))
	visit.trade.reserve_price = reserve if initial else mini(visit.trade.reserve_price,reserve)
	visit.trade.asking_price = asking if initial else maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,asking))
	var public_value := valuation(real_variant if "identity" in accepted else "sound",visit.item.goods.precision.damage if "exterior" in accepted else "intact",operation)
	row.reference = WealthyCustomers.reference_price(public_value,visit.transaction_modes[0]); row.value = public_value

static func pending(state: RunState, visit: CustomerVisit) -> Array[String]:
	var o := owner(state,visit); var result: Array[String] = []
	var record := TieredAppraisal.record(state,visit.item.instance_id)
	var stage := TieredAppraisal.stage(state,visit.item.instance_id,2)
	var w := WatchAppraisal.row(state,visit.item.instance_id)
	if record.get("exterior",false) and "exterior" not in o.used: result.append("exterior")
	if stage.get("identity","unsure") != "unsure" and stage.get("condition","unsure") != "unsure" and "identity" not in o.used: result.append("identity")
	if w.get("running","unsure") != "unsure" and "running" not in o.used: result.append("running")
	return result

static func pressure(day: DayController, visit: CustomerVisit) -> String:
	var o := owner(day.state,visit); var stage := TieredAppraisal.stage(day.state,visit.item.instance_id,2)
	var w := WatchAppraisal.row(day.state,visit.item.instance_id)
	var book := LuxuryAppraisalService.info(day.state,visit.item)
	var failed := false; var passed := 0
	for evidence in pending(day.state,visit):
		var valid := evidence == "exterior"
		if evidence == "identity": valid = w.get("spots",[]).size() == 2 and stage.identity == book.identity[visit.item.selected_variant_id] and stage.condition == book.condition[visit.item.selected_variant_id]
		if evidence == "running": valid = "wound/flat" in w.get("listened",[]) and "wound/vertical" in w.get("listened",[]) and w.running == visit.item.goods.watch_value.operation and WatchAppraisal.anomaly_marked(day.state,visit.item,w)
		o.used.append(evidence)
		if valid: o.accepted.append(evidence); passed += 1
		else: failed = true
	visit.trade.rounds_left -= 1
	if failed:
		var customer := day.state.ghost_catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
		visit.trade.patience -= customer.terms.false_pressure_cost
	reprice(day.state,visit)
	return ("客人认下有凭据的部分，其余仍不肯认。" if failed and passed > 0 else "客人摇头：‘这还不足为凭。’" if failed else "客人核过证据，点了点头。")+"\n要价%d银元。" % visit.trade.asking_price

static func bluff_reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if visit != null and WatchNegotiation.handles(day.state,visit.item): return "请在商量价钱中选择要谈的说法。"
	if not handles(day.state,visit.item) or owner(day.state,visit).is_empty(): return "眼下不适合这样谈价。"
	if not detail.is_empty() or amount != 0: return "先谈货，再另行报价。"
	if owner(day.state,visit).bluff_used: return "这个说法已经用过。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已不肯再谈。"
	return TieredAppraisal.time_reason(day,visit.item,5)

static func bluff(day: DayController, visit: CustomerVisit) -> String:
	var o := owner(day.state,visit)
	var false_claim := visit.item.selected_variant_id != "flawed"
	var spotted: bool = int(o.bluff_roll) < int({"expert":80,"ordinary":45,"novice":15}[o.skill]) or ("identity" in o.accepted and false_claim)
	o.bluff_used = true; o.bluff_accepted = not spotted; o["bluff_spotted"] = spotted
	visit.trade.rounds_left -= 1
	if spotted:
		var customer := day.state.ghost_catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
		visit.trade.patience -= customer.terms.false_pressure_cost
		if false_claim: penalize(day.state,visit)
		return "客人把表收近：‘您这说法，我信不过。价钱不让。’"
	visit.trade.reserve_price = maxi(int(WealthyCustomers.trade(day.state,visit).funding),roundi(visit.trade.reserve_price*.85))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,roundi(visit.trade.asking_price*.85))
	return "客人犹豫了一阵：‘那就再让些。’\n要价%d银元。" % visit.trade.asking_price

static func penalize(state: RunState, visit: CustomerVisit) -> void:
	if not state.social_enabled: return
	var event_id := visit.visit_id+"/watch_bluff"
	if state.social.trades.any(func(r: Dictionary) -> bool: return r.visit_id == event_id): return
	var spent := 0
	for r in state.social.trades:
		if r.night == state.current_night_index: spent += maxi(0,-int(r.delta))
	var delta := -mini(2,maxi(0,int(SocialRules.config().reputation.negative_cap)-spent))
	state.social.trades.append({"visit_id":event_id,"night":state.current_night_index,"opening":visit.trade.opening_price,"flaw_discount":0,"basis":0,"price":0,"mode":"watch_bluff","outcome":"bluff_spotted","delta":delta})
	if delta != 0: SocialRules.change(state,"reputation",delta,event_id)
	SocialRules.notice(state,"客人识破贬价的说辞，出门时摇了摇头。商誉%+d。" % delta)

static func sample_ticks(operation: String, pose: String, offset := 0.0, empty := false) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for i in 39:
		var t := .2+i*.2
		if empty and t > 1.4: continue
		if operation == "stopping" and t >= 3.4+offset: continue
		if operation == "positional" and pose == "vertical" and ((t >= 2.2+offset and t < 2.8+offset) or (t >= 5.0+offset and t < 5.6+offset)): continue
		result.append(t)
	return result
