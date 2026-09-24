class_name BangleNegotiation
extends RefCounted

const PARTS := ["material","repair","exterior"]
const LABELS := {"material":"金料判断","repair":"修补情况","exterior":"外观"}
const OPTIONS := {
 "material":{"fine":"足色金","lower":"成色不足","plated":"镀金仿品"},
 "repair":{"intact":"未见后期修补","altered":"有接焊修补"},
 "exterior":{"observed":"按查出的外观谈价"}}

static func data(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("bangle_negotiation",{})

static func history(state: RunState, visit: CustomerVisit) -> Array:
	var rows := []
	for response in data(state,visit).get("responses",[]): rows.push_front({"message":response.message,"before":response.before,"after":response.after})
	return rows

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	var n := VarietyService.rng(state.run_seed,visit.visit_id+"/bangle39/personality").randi_range(0,99)
	var rolls := {}
	for part in PARTS: rolls[part] = VarietyService.rng(state.run_seed,visit.visit_id+"/bangle39/claim/"+part).randi_range(0,99)
	WealthyCustomers.trade(state,visit)["bangle_negotiation"] = {"personality":"easy" if n<35 else "careful" if n<80 else "firm","rolls":rolls,"claims":{},"facts":{},"responses":[],"penalized":false,"belief":BangleEconomy.owner(state,visit).belief.duplicate(true),"initial_asking":visit.trade.asking_price,"initial_reserve":visit.trade.reserve_price}

static func strength(state: RunState, visit: CustomerVisit, part: String) -> int:
	var r := BangleAppraisal.row(state,visit.item.instance_id)
	if part == "exterior": return 2
	if part == "repair":
		return 2 if "joint" in r.get("wiped",[]) and "joint" in r.get("finished",[]) and "joint" in r.get("viewed",[]) else 1 if "joint" in r.get("viewed",[]) else 0
	var weighed: bool = r.get("weighed",false)
	var fires: int = r.get("finished",[]).size()
	return 2 if weighed and "stamp" in r.get("viewed",[]) and fires >= 2 else 1 if weighed or fires > 0 else 0

static func truth(item: ItemInstance, part: String) -> String:
	return BangleEconomy.material(item) if part == "material" else BangleEconomy.repair(item) if part == "repair" else "observed"

static func chance(state: RunState, visit: CustomerVisit, part: String, claim: String) -> int:
	var facts: Dictionary = data(state,visit).facts
	if facts.has(part) and facts[part] != claim: return 0
	if part == "exterior": return 100
	var skill := ["expert","ordinary","novice"].find(BangleEconomy.owner(state,visit).skill)
	var table: Array = WatchNegotiation.TRUE_CHANCES if truth(visit.item,part) == claim else WatchNegotiation.FALSE_CHANCES
	return table[strength(state,visit,part)][skill]

static func reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if visit == null or not BangleEconomy.handles(day.state,visit.item): return "眼下没有这笔金镯生意。"
	if amount != 0: return "先说货况，再另报价格。"
	var claims: Variant = JSON.parse_string(detail)
	if not claims is Dictionary or claims.is_empty(): return "请选择要谈的说法。"
	var d := data(day.state,visit)
	for part in claims:
		if not OPTIONS.has(part) or not claims[part] is String or not OPTIONS[part].has(claims[part]): return "这项说法不合适。"
		if d.claims.has(part): return LABELS[part]+"已经谈过，不能再试。"
		if part == "exterior" and not TieredAppraisal.record(day.state,visit.item.instance_id).get("exterior",false): return "先检查外观，再谈外伤。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已不肯再谈。"
	return TieredAppraisal.time_reason(day,visit.item,5)

static func concession(state: RunState, visit: CustomerVisit) -> float:
	var urgent: bool = BangleEconomy.owner(state,visit).urgent
	return {"easy":1.0,"careful":.75 if urgent else .5,"firm":.25 if urgent else 0.0}[data(state,visit).personality]

static func reprice(state: RunState, visit: CustomerVisit) -> void:
	var d := data(state,visit); var o := BangleEconomy.owner(state,visit); var trade := WealthyCustomers.trade(state,visit)
	var value := BangleEconomy.valuation(d.belief.material,d.belief.repair,visit.item.goods.precision.damage)
	var base := WealthyCustomers.reference_price(value,visit.transaction_modes[0])
	var factor := float(o.rate)/100.0*(.85 if o.urgent else 1.0)*float(trade.intimidation)
	var target_reserve := maxi(int(trade.funding),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	var target_asking := maxi(target_reserve,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	var fraction := concession(state,visit)
	var reserve := roundi(d.initial_reserve-fraction*maxi(0,int(d.initial_reserve)-target_reserve))
	var asking := roundi(d.initial_asking-fraction*maxi(0,int(d.initial_asking)-target_asking))
	visit.trade.reserve_price = maxi(int(trade.funding),mini(visit.trade.reserve_price,reserve))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,asking))
	trade.value = BangleEconomy.valuation(d.facts.get("material","fine"),d.facts.get("repair","intact"),visit.item.goods.precision.damage if d.facts.has("exterior") else "intact")
	trade.reference = WealthyCustomers.reference_price(trade.value,visit.transaction_modes[0])

static func submit(day: DayController, visit: CustomerVisit, detail: String) -> String:
	var claims: Dictionary = JSON.parse_string(detail); var d := data(day.state,visit)
	var before := visit.trade.asking_price; var replies := PackedStringArray(); var failed := false; var caught := false; var accepted := false; var results := {}
	for part in PARTS:
		if not claims.has(part): continue
		var claim: String = claims[part]; var correct := truth(visit.item,part) == claim
		var believed: bool = int(d.rolls[part]) < chance(day.state,visit,part,claim)
		d.claims[part] = claim
		if believed:
			accepted = true
			if part != "exterior": d.belief[part] = claim
			if correct: d.facts[part] = claim
		else:
			failed = true; caught = caught or not correct
		replies.append(LABELS[part]+"（"+OPTIONS[part][claim]+"）："+("‘这处我认下。’" if believed else "‘单凭这些，我还信不过。’"))
		results[part] = {"claim":claim,"accepted":believed,"strength":strength(day.state,visit,part)}
	visit.trade.rounds_left -= 1
	if failed:
		var customer: CustomerDefinition = day.state.ghost_catalog.get_definition("customers",visit.customer_id)
		visit.trade.patience -= customer.terms.false_pressure_cost
	if caught and not d.penalized: WatchEconomy.penalize(day.state,visit); d.penalized = true
	reprice(day.state,visit)
	var after := visit.trade.asking_price
	if accepted: replies.append("客人想了想：‘照这个价谈吧。’" if after < before and concession(day.state,visit)==1.0 else "客人摇头：‘只能再让这些。’" if after < before else "客人拢起金镯：‘货况认下，价钱已让到头了。’")
	replies.append("要价：%d → %d 银元。" % [before,after])
	var message := "\n".join(replies)
	d.responses.append({"night":day.state.current_night_index,"minute":day.state.game_minutes,"parts":results,"before":before,"after":after,"message":message})
	return message

static func model(day: DayController, visit: CustomerVisit) -> Dictionary:
	var d := data(day.state,visit); var r := BangleAppraisal.row(day.state,visit.item.instance_id)
	var defaults := {"material":r.get("material","unsure"),"repair":r.get("repair","unsure"),"exterior":"observed" if TieredAppraisal.record(day.state,visit.item.instance_id).get("exterior",false) else "unsure"}
	var rows := []
	for part in PARTS:
		rows.append({"id":part,"label":LABELS[part],"options":OPTIONS[part],"default":defaults[part],"used":d.claims.has(part),"previous":d.claims.get(part,""),"reason":reason(day,visit,JSON.stringify({part:OPTIONS[part].keys()[0]}),0)})
	return {"rows":rows,"reply":d.responses.back().message if not d.responses.is_empty() else ""}
