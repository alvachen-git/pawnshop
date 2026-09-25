class_name CameraNegotiation
extends RefCounted

const PARTS := ["identity","lens","mechanism","exterior"]
const LABELS := {"identity":"型号身份","lens":"镜片状态","mechanism":"机械运转","exterior":"外观"}
const OPTIONS := {
 "identity":{"original":"原装徕卡","rebuilt":"拼配或改装","imitation":"仿制或冒名"},
 "lens":{"clear":"镜片清透","haze":"镜内雾化","scratched":"镜片有划伤"},
 "mechanism":{"smooth":"开合顺畅","sticky":"开合迟滞","stuck":"开合卡住"},
 "exterior":{"observed":"按查出的外伤谈价"}}

static func data(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("camera_negotiation",{})

static func history(state: RunState, visit: CustomerVisit) -> Array:
	var rows := []
	for response in data(state,visit).get("responses",[]): rows.push_front({"message":response.message,"before":response.before,"after":response.after})
	return rows

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	var n := VarietyService.rng(state.run_seed,visit.visit_id+"/camera43/personality").randi_range(0,99)
	var rolls := {}
	for part in PARTS: rolls[part] = VarietyService.rng(state.run_seed,visit.visit_id+"/camera43/claim/"+part).randi_range(0,99)
	WealthyCustomers.trade(state,visit)["camera_negotiation"] = {"personality":"easy" if n<35 else "careful" if n<80 else "firm","rolls":rolls,"claims":{},"facts":{},"responses":[],"penalized":false,"belief":CameraEconomy.owner(state,visit).belief.duplicate(true),"initial_asking":visit.trade.asking_price,"initial_reserve":visit.trade.reserve_price}

static func strength(state: RunState, visit: CustomerVisit, part: String) -> int:
	var d:=CameraAppraisal.row(state,visit.item.instance_id)
	if part=="exterior":return 2
	if part=="identity":return 2 if d.get("identity_zoom",false) else 1 if "identity" in d.get("viewed",[]) else 0
	if part=="lens":return 2 if d.get("lights",[]).size()>=2 else 1 if not d.get("lights",[]).is_empty() else 0
	var apertures: Array=d.get("apertures",[])
	var tested:=false
	for entry in d.get("tests",[]):
		if String(entry).begins_with("wound/"):tested=true
	return int(apertures.size()>=2)+int(tested)

static func truth(item: ItemInstance, part: String) -> String:
	return "observed" if part=="exterior" else String(item.goods.camera_value[part])

static func chance(state: RunState, visit: CustomerVisit, part: String, claim: String) -> int:
	var facts: Dictionary = data(state,visit).facts
	if facts.has(part) and facts[part] != claim: return 0
	if part == "exterior": return 100
	var skill := ["expert","ordinary","novice"].find(CameraEconomy.owner(state,visit).skill)
	var table: Array = WatchNegotiation.TRUE_CHANCES if truth(visit.item,part) == claim else WatchNegotiation.FALSE_CHANCES
	return table[strength(state,visit,part)][skill]

static func reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if visit == null or not CameraEconomy.handles(day.state,visit.item): return "眼下没有这笔相机生意。"
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
	var urgent: bool = CameraEconomy.owner(state,visit).urgent
	return {"easy":1.0,"careful":.75 if urgent else .5,"firm":.25 if urgent else 0.0}[data(state,visit).personality]

static func reprice(state: RunState, visit: CustomerVisit) -> Dictionary:
	var d := data(state,visit); var o := CameraEconomy.owner(state,visit); var trade := WealthyCustomers.trade(state,visit)
	var value := CameraEconomy.valuation(d.belief.identity,d.belief.lens,d.belief.mechanism,visit.item.goods.precision.damage)
	var base := WealthyCustomers.reference_price(value,visit.transaction_modes[0])
	var factor := float(o.rate)/100.0*(.85 if o.urgent else 1.0)*float(trade.intimidation)
	var target_reserve := maxi(WealthyCustomers.minimum_price(state,visit),roundi(base*LuxuryCarry.percent(state,visit,"reserve")*factor))
	var target_asking := maxi(target_reserve,roundi(base*LuxuryCarry.percent(state,visit,"asking")*factor))
	var fraction := concession(state,visit)
	var reserve := roundi(d.initial_reserve-fraction*maxi(0,int(d.initial_reserve)-target_reserve))
	var asking := roundi(d.initial_asking-fraction*maxi(0,int(d.initial_asking)-target_asking))
	visit.trade.reserve_price = maxi(WealthyCustomers.minimum_price(state,visit),mini(visit.trade.reserve_price,reserve))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,asking))
	trade.value = CameraEconomy.valuation(d.facts.get("identity","original"),d.facts.get("lens","clear"),d.facts.get("mechanism","smooth"),visit.item.goods.precision.damage if d.facts.has("exterior") else "intact")
	trade.reference = WealthyCustomers.reference_price(trade.value,visit.transaction_modes[0])
	return {"target":target_asking,"fraction":fraction,"funding":int(trade.funding)}

static func unchanged_reply(d: Dictionary, pricing: Dictionary, before: int, belief_before: Dictionary, results: Dictionary) -> String:
	if pricing.funding > 0 and before <= pricing.funding and pricing.target <= pricing.funding:
		return "客人按住当票：‘货况我认，可这趟至少得筹到 %d 银元。少了这笔钱，我宁可先不当。’" % pricing.funding
	if d.belief == belief_before:
		if results.size() == 1 and results.has("exterior") and results.exterior.accepted:
			return "客人摇头：‘这点外伤，开价时已经算进去了，不能再扣一回。’"
		return "客人点头：‘这货况我原先就是这么看的，开价时已经算进去了。’"
	if pricing.target >= d.initial_asking:
		return "客人摆摆手：‘照您认下的货况，也没有再往下折的道理。仍按方才的价谈。’"
	if pricing.fraction == 0.0:
		return "客人拢起相机：‘您说的货况我认。不过这架相机，我仍要这个价，少了便先留着。’"
	if before < d.initial_asking:
		return "客人摇头：‘方才已经让过价了。您这回说的，我认，但在眼下这个价上不能再让。’"
	return "客人想了想：‘这处我认，只是照这点差别，还不足以再少一银元。’"

static func submit(day: DayController, visit: CustomerVisit, detail: String) -> String:
	var claims: Dictionary = JSON.parse_string(detail); var d := data(day.state,visit)
	var belief_before: Dictionary = d.belief.duplicate(true)
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
			failed = true; caught = caught or (not correct and devalues(visit.item,part,claim))
		replies.append(LABELS[part]+"（"+OPTIONS[part][claim]+"）："+("‘这处我认下。’" if believed else "‘单凭这些，我还信不过。’"))
		results[part] = {"claim":claim,"accepted":believed,"strength":strength(day.state,visit,part)}
	visit.trade.rounds_left -= 1
	if failed:
		var customer: CustomerDefinition = day.state.ghost_catalog.get_definition("customers",visit.customer_id)
		visit.trade.patience -= customer.terms.false_pressure_cost
	if caught and not d.penalized: WatchEconomy.penalize(day.state,visit); d.penalized = true
	var pricing := reprice(day.state,visit)
	var after := visit.trade.asking_price
	if accepted and WealthyCustomers.item_minimum(day.state,visit) > 0 and after <= WealthyCustomers.minimum_price(day.state,visit):
		replies.append(WealthyCustomers.minimum_reply(day.state,visit))
	elif accepted: replies.append("客人想了想：‘照这个价谈吧。’" if after < before and concession(day.state,visit)==1.0 else "客人摇头：‘只能再让这些。’" if after < before else unchanged_reply(d,pricing,before,belief_before,results))
	replies.append("要价：%d → %d 银元。" % [before,after])
	var message := "\n".join(replies)
	d.responses.append({"night":day.state.current_night_index,"minute":day.state.game_minutes,"parts":results,"before":before,"after":after,"message":message})
	return message

static func model(day: DayController, visit: CustomerVisit) -> Dictionary:
	var d := data(day.state,visit); var r := CameraAppraisal.row(day.state,visit.item.instance_id)
	var defaults := {"identity":r.get("identity","unsure"),"lens":r.get("lens","unsure"),"mechanism":r.get("mechanism","unsure"),"exterior":"observed" if TieredAppraisal.record(day.state,visit.item.instance_id).get("exterior",false) else "unsure"}
	var rows := []
	for part in PARTS:
		rows.append({"id":part,"label":LABELS[part],"options":OPTIONS[part],"default":defaults[part],"used":d.claims.has(part),"previous":d.claims.get(part,""),"reason":reason(day,visit,JSON.stringify({part:OPTIONS[part].keys()[0]}),0)})
	return {"rows":rows,"reply":d.responses.back().message if not d.responses.is_empty() else ""}

static func devalues(item: ItemInstance, part: String, claim: String) -> bool:
	if part=="exterior":return false
	var table: Dictionary={"identity":CameraEconomy.BASE,"lens":CameraEconomy.LENS,"mechanism":CameraEconomy.MECHANISM}[part]
	return table[claim]<table[truth(item,part)]
