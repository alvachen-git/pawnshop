class_name BangleAppraisal
extends RefCounted

const PARTS := ["stamp","inner","body","joint"]
const LABELS := {"stamp":"戳记","inner":"内圈","body":"镯身","joint":"接合处"}
const DENOMINATIONS := [1,2,5,10,20]

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("bangle",{})

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var why := TieredAppraisal.access(day,id)
	if not why.is_empty(): return why
	var item := LuxuryAppraisalService.target(day,id)
	if not BangleEconomy.handles(day.state,item): return "眼前不是这只金镯。"
	if command == "luxury_begin":
		if detail != "2": return "这只金镯使用器材鉴定即可。"
		if not row(day.state,id).is_empty(): return ""
		why = TieredAppraisal.missing(day,item,2)
		return why if not why.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command != "luxury_bangle": return "请在验金台称重、查看或记下判断。"
	var p: Variant = JSON.parse_string(detail)
	if not p is Dictionary or not p.get("op") is String: return "验金记录有误。"
	var d := row(day.state,id)
	if d.is_empty(): return "先开始器材鉴定。"
	if p.op in ["draft","seal"] and TieredAppraisal.stage(day.state,id,2).committed: return "手记已落笔，不能改写。"
	if not d.active.is_empty() and p.op not in ["fire_stop","fire_finish"]: return "先收火，让金镯冷却。"
	match p.op:
		"place","clear","seal": pass
		"weight":
			if not RunSchema.integer(p.get("grams")) or int(p.grams) not in DENOMINATIONS or not RunSchema.integer(p.get("direction")) or int(p.direction) not in [-1,1]: return "请选择有效砝码。"
			if p.direction == -1 and int(d.weights.get(str(int(p.grams)),0)) == 0: return "盘上没有这枚砝码。"
			if p.direction == 1 and total(d)+int(p.grams)>200: return "盘上砝码已足够。"
		"select":
			if p.get("part") not in PARTS: return "请选择金镯上的部位。"
		"turn":
			if not RunSchema.integer(p.get("angle")) or int(p.angle) not in [0,1,2]: return "请选择有效角度。"
		"view": pass
		"fire_start":
			if d.part == "stamp": return "请选内圈、镯身或接合处火试。"
		"fire_stop","fire_finish":
			if d.active.is_empty(): return "眼下没有火试。"
		"wipe","compare":
			if d.part not in d.finished: return "先在这处完成火试，冷却后再比较。"
			if p.op == "compare" and d.part not in d.wiped: return "先擦去表面烟污，再比较痕迹。"
		"draft":
			if p.get("material") not in ["fine","lower","plated","unsure"] or p.get("repair") not in ["intact","altered","unsure"]: return "分别记下金料与修补判断。"
		_: return "没有这项验金操作。"
	return ""

static func total(d: Dictionary) -> int:
	var result := 0
	for weight in d.get("weights",{}): result += int(weight)*int(d.weights[weight])
	return result

static func perform(day: DayController, command: String, id: String, detail: String) -> ActionResult:
	var why := reason(day,command,id,detail)
	if not why.is_empty(): return ActionResult.new(false,why)
	if command == "luxury_begin":
		if not row(day.state,id).is_empty(): return ActionResult.new(true,"")
		var spent := day.spend_action(10)
		if not spent.ok: return spent
		var all: Dictionary = WealthyCustomers.data(day.state).appraisals
		if not all.has(id): all[id] = {"exterior":false,"stages":{}}
		all[id].stages["2"] = TieredAppraisal.blank_stage()
		all[id].stages["2"].identity = "unsure"; all[id].stages["2"].condition = "unsure"
		all[id].stages["2"]["bangle"] = {"placed":false,"weights":{},"weighed":false,"measured":0,"part":"inner","angle":0,"viewed":[],"started":[],"finished":[],"wiped":[],"compared":[],"active":"","material":"unsure","repair":"unsure"}
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"金镯已放在案上，可以称重、看戳记与火试。")
	var p: Dictionary = JSON.parse_string(detail); var d := row(day.state,id)
	match p.op:
		"place": d.placed = not d.placed
		"clear": d.weights.clear()
		"weight":
			var key := str(int(p.grams)); d.weights[key] = int(d.weights.get(key,0))+int(p.direction)
			if d.weights[key]==0: d.weights.erase(key)
		"select": d.part = p.part
		"turn": d.angle = int(p.angle)
		"view":
			if d.part not in d.viewed: d.viewed.append(d.part)
		"fire_start":
			d.active = d.part
			if d.part not in d.started: d.started.append(d.part)
		"fire_stop": d.active = ""
		"fire_finish":
			if d.active not in d.finished: d.finished.append(d.active)
			d.active = ""
		"wipe":
			if d.part not in d.wiped: d.wiped.append(d.part)
		# Keep the former explicit action readable in existing v39 action logs.
		"compare":
			if d.part not in d.compared: d.compared.append(d.part)
		"draft": d.material = p.material; d.repair = p.repair
		"seal": TieredAppraisal.stage(day.state,id,2).committed = true
	if p.op in ["place","weight","clear"] and d.placed and total(d)==int(LuxuryAppraisalService.target(day,id).goods.bangle_value.weight):
		d.weighed = true; d.measured = total(d)
	return ActionResult.new(true,"手记已落笔。" if p.op=="seal" else "")

static func visible_detail(item: ItemInstance, d: Dictionary) -> bool:
	return not item.goods.precision.hidden or int(d.angle)==int(item.goods.bangle_value.angles[d.part])

static func observations(state: RunState, item: ItemInstance) -> Array:
	var d := row(state,item.instance_id); var result := []
	if d.get("weighed",false): result.append("称得重量%d克。" % d.measured)
	for part in d.get("viewed",[]): result.append("已放大查看"+LABELS[part]+"。")
	for part in d.get("finished",[]): result.append(LABELS[part]+"已火试。"+("已擦拭比较。" if part in d.wiped else ""))
	return result
