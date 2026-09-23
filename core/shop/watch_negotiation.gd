class_name WatchNegotiation
extends RefCounted

const PARTS := ["identity","repair","running","exterior"]
const LABELS := {"identity":"身份","repair":"修配","running":"运转","exterior":"外观"}
const OPTIONS := {
	"identity":{"original":"原厂真品","imitation":"仿制或冒名"},
	"repair":{"intact":"未见修配","altered":"有修补或替换"},
	"running":{"stable":"走时连续","positional":"换姿态停顿","stopping":"中途停走"},
	"exterior":{"observed":"按查出的外观谈价"}}
const TRUE_CHANCES := [[60,70,80],[85,90,95],[100,100,100]]
const FALSE_CHANCES := [[20,55,85],[10,35,65],[5,20,40]]

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("watch_negotiation_version",0) == 1

static func handles(state: RunState, item: ItemInstance) -> bool:
	return WatchEconomy.handles(state,item) and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func data(state: RunState, visit: CustomerVisit) -> Dictionary:
	return WealthyCustomers.trade(state,visit).get("watch_negotiation",{})

static func history(state: RunState, visit: CustomerVisit) -> Array:
	var rows := []
	for response in data(state,visit).get("responses",[]):
		rows.push_front({"message":response.message,"before":response.before,"after":response.after})
	return rows

static func prepare(state: RunState, visit: CustomerVisit) -> void:
	var o := WatchEconomy.owner(state,visit)
	var n := VarietyService.rng(state.run_seed,visit.visit_id+"/watch35/personality").randi_range(0,99)
	var rolls := {}
	for part in PARTS: rolls[part] = VarietyService.rng(state.run_seed,visit.visit_id+"/watch35/claim/"+part).randi_range(0,99)
	WealthyCustomers.trade(state,visit).watch_negotiation = {
		"personality":"easy" if n < 35 else "careful" if n < 80 else "firm",
		"rolls":rolls,"claims":{},"facts":{},"responses":[],"penalized":false,
		"belief":{"identity":"imitation" if o.belief == "flawed" else "original","repair":"altered" if o.belief == "mended" else "intact","running":"stable"},
		"initial_asking":visit.trade.asking_price,"initial_reserve":visit.trade.reserve_price}

static func strength(state: RunState, visit: CustomerVisit, part: String) -> int:
	var w := WatchAppraisal.row(state,visit.item.instance_id)
	if part in ["identity","repair"]: return mini(2,w.get("spots",[]).size())
	if part == "exterior": return 2
	var clips: Array = w.get("started",[])
	return int("wound/flat" in clips)+int("wound/vertical" in clips)

static func truth(visit: CustomerVisit, part: String) -> String:
	match part:
		"identity": return "imitation" if visit.item.selected_variant_id == "flawed" else "original"
		"repair": return "altered" if visit.item.selected_variant_id == "mended" else "intact"
		"running": return visit.item.goods.watch_value.operation
	return "observed"

static func chance(state: RunState, visit: CustomerVisit, part: String, claim: String) -> int:
	var known: Dictionary = data(state,visit).facts
	if known.has(part) and known[part] != claim: return 0
	if part == "exterior": return 100
	var skill := ["expert","ordinary","novice"].find(WatchEconomy.owner(state,visit).skill)
	return (TRUE_CHANCES if truth(visit,part) == claim else FALSE_CHANCES)[strength(state,visit,part)][skill]

static func reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if visit == null or not handles(day.state,visit.item): return "眼下没有这笔怀表生意。"
	if amount != 0: return "先说货况，再另报价格。"
	var parsed := JSON.new()
	if parsed.parse(detail) != OK or not parsed.data is Dictionary: return "请选择要谈的说法。"
	var claims: Dictionary = parsed.data
	if claims.is_empty(): return "请至少选一项要谈的说法。"
	var d := data(day.state,visit)
	for part in claims:
		if not OPTIONS.has(part) or not claims[part] is String or not OPTIONS[part].has(claims[part]): return "这项说法不合适。"
		if d.claims.has(part): return LABELS[part]+"已经谈过，不能再试。"
		if part == "running" and WatchAppraisal.row(day.state,visit.item.instance_id).get("started",[]).is_empty(): return "先点一次听音，再谈运转。"
		if part == "exterior" and not TieredAppraisal.record(day.state,visit.item.instance_id).get("exterior",false): return "先检查外观，再谈外伤。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已不肯再谈。"
	return TieredAppraisal.time_reason(day,visit.item,5)

static func concession(state: RunState, visit: CustomerVisit) -> float:
	var urgent: bool = WatchEconomy.owner(state,visit).urgent
	return {"easy":1.0,"careful":.75 if urgent else .5,"firm":.25 if urgent else 0.0}[data(state,visit).personality]

static func belief_variant(belief: Dictionary) -> String:
	return "flawed" if belief.identity == "imitation" else "mended" if belief.repair == "altered" else "sound"

static func reprice(state: RunState, visit: CustomerVisit) -> void:
	var d := data(state,visit); var o := WatchEconomy.owner(state,visit); var row := WealthyCustomers.trade(state,visit)
	var believed := WatchEconomy.valuation(belief_variant(d.belief),visit.item.goods.precision.damage,d.belief.running)
	var reference := WealthyCustomers.reference_price(believed,visit.transaction_modes[0])
	var factor: float = float(o.rate)/100.0*(.85 if o.urgent else 1.0)*float(row.intimidation)
	var target_reserve := maxi(int(row.funding),roundi(reference*.95*factor))
	var target_asking := maxi(target_reserve,roundi(reference*1.10*factor))
	var fraction := concession(state,visit)
	var reserve := roundi(d.initial_reserve-fraction*maxi(0,int(d.initial_reserve)-target_reserve))
	var asking := roundi(d.initial_asking-fraction*maxi(0,int(d.initial_asking)-target_asking))
	visit.trade.reserve_price = maxi(int(row.funding),mini(visit.trade.reserve_price,reserve))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,asking))
	# Public reputation basis uses only true, acknowledged observations; not beliefs.
	var proven := {"identity":d.facts.get("identity","original"),"repair":d.facts.get("repair","intact")}
	row.value = WatchEconomy.valuation(belief_variant(proven),visit.item.goods.precision.damage if d.facts.has("exterior") else "intact",d.facts.get("running","stable"))
	row.reference = WealthyCustomers.reference_price(row.value,visit.transaction_modes[0])

static func submit(day: DayController, visit: CustomerVisit, detail: String) -> String:
	var claims: Dictionary = JSON.parse_string(detail)
	var d := data(day.state,visit)
	var before := visit.trade.asking_price
	var replies := PackedStringArray(); var failed := false; var caught := false; var accepted := false
	var results := {}
	# Fixed order prevents JSON key ordering from changing responses or pricing.
	for part in PARTS:
		if not claims.has(part): continue
		var claim: String = claims[part]
		var correct := truth(visit,part) == claim
		var believed: bool = int(d.rolls[part]) < chance(day.state,visit,part,claim)
		var subject: String = LABELS[part]+"（"+OPTIONS[part][claim]+"）"
		d.claims[part] = claim
		if believed:
			accepted = true
			if part != "exterior": d.belief[part] = claim
			if correct: d.facts[part] = claim
			replies.append(subject+"：‘这处我认下。’")
		else:
			failed = true; caught = caught or not correct
			replies.append(subject+("：‘这番话我信不过。’" if correct else "：‘您这说法对不上，不能这么算。’"))
		results[part] = {"claim":claim,"accepted":believed,"strength":strength(day.state,visit,part)}
	visit.trade.rounds_left -= 1
	if failed:
		var customer := day.state.ghost_catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
		visit.trade.patience -= customer.terms.false_pressure_cost
	if caught and not d.penalized:
		WatchEconomy.penalize(day.state,visit); d.penalized = true
	reprice(day.state,visit)
	var after := visit.trade.asking_price
	if accepted:
		if after < before: replies.append("客人想了想：‘%s’" % ("既然如此，照这个价谈。" if concession(day.state,visit) == 1.0 else "只能再让这一点，再低就不成了。"))
		else: replies.append("客人把表推近：‘货况我认，价钱已压得低了，不能再让。’")
	replies.append("要价：%d → %d 银元。" % [before,after])
	var message := "\n".join(replies)
	d.responses.append({"night":day.state.current_night_index,"minute":day.state.game_minutes,"parts":results,"before":before,"after":after,"message":message})
	return message

static func model(day: DayController, visit: CustomerVisit) -> Dictionary:
	var d := data(day.state,visit); var id := visit.item.instance_id
	var stage := TieredAppraisal.stage(day.state,id,2); var watch := WatchAppraisal.row(day.state,id)
	var defaults := {"identity":stage.get("identity","unsure"),"repair":stage.get("condition","unsure"),"running":watch.get("running","unsure"),"exterior":"observed" if TieredAppraisal.record(day.state,id).get("exterior",false) else "unsure"}
	var rows := []
	for part in PARTS:
		var why := reason(day,visit,JSON.stringify({part:OPTIONS[part].keys()[0]}),0)
		rows.append({"id":part,"label":LABELS[part],"options":OPTIONS[part],"default":defaults[part],"used":d.claims.has(part),"previous":d.claims.get(part,""),"reason":why})
	return {"rows":rows,"reply":d.responses.back().message if not d.responses.is_empty() else ""}
