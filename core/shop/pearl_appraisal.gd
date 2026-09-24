class_name PearlAppraisal
extends RefCounted

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("pearl",{})

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var why := TieredAppraisal.access(day,id)
	if not why.is_empty(): return why
	var item := LuxuryAppraisalService.target(day,id)
	if not PearlEconomy.handles(day.state,item): return "眼前不是这件珠串。"
	if command == "luxury_begin":
		if detail != "2": return "这件珠串使用器材鉴定即可。"
		if not row(day.state,id).is_empty(): return ""
		why = TieredAppraisal.missing(day,item,2)
		return why if not why.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command != "luxury_pearl": return "请在验珠台转珠、比较或记下判断。"
	var p: Variant = JSON.parse_string(detail)
	if not p is Dictionary or not p.get("op") is String: return "验珠记录有误。"
	var data := row(day.state,id)
	if data.is_empty(): return "先开始器材鉴定。"
	if p.op in ["draft","seal"] and TieredAppraisal.stage(day.state,id,2).committed: return "手记已落笔，不能改写。"
	match p.op:
		"select","turn","light","hole","compare":
			if not RunSchema.integer(p.get("index")) or p.index < 0 or p.index >= 32: return "请选珠串中的一颗。"
			if p.op == "select":
				if p.has("angle") and (not RunSchema.integer(p.angle) or int(p.angle) not in [0,1,2]): return "请转到有效角度。"
				if p.has("hole") and not p.hole is bool: return "验珠记录有误。"
			if p.op == "turn" and (not RunSchema.integer(p.get("angle")) or int(p.angle) not in [0,1,2]): return "请转到有效角度。"
			if p.op == "light" and p.get("light") not in ["left","front","right"]: return "请调整灯的位置。"
			if p.op == "compare" and (not RunSchema.integer(p.get("other")) or p.other < 0 or p.other >= 32 or p.other == p.index): return "请选择两颗不同的珠子。"
		"draft":
			if p.get("material") not in ["none","few","some","most","all","unsure"] or p.get("repair") not in ["intact","altered","unsure"]: return "请记下材质与换配判断。"
		"seal": pass
		_: return "没有这项验珠操作。"
	return ""

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
		all[id].stages["2"]["pearl"] = {"selected":0,"angles":{},"light":"front","holes":[],"pairs":[],"viewed":[],"material":"unsure","repair":"unsure","compare":-1}
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"珠串已放稳，可以转珠看光，也可以放大孔口。")
	var p: Dictionary = JSON.parse_string(detail); var data := row(day.state,id)
	match p.op:
		"select","turn","light","hole","compare":
			data.selected = int(p.index)
			# New selections carry the desk setup in one saved action; old logs remain unchanged.
			if p.op == "select":
				if p.has("angle"): data.angles[str(int(p.index))] = int(p.angle)
				if p.get("hole",false) and int(p.index) not in data.holes: data.holes.append(int(p.index))
			if p.op == "turn": data.angles[str(int(p.index))] = int(p.angle)
			if p.op == "light": data.light = p.light
			if p.op == "hole" and int(p.index) not in data.holes: data.holes.append(int(p.index))
			if p.op == "compare":
				var pair := [int(p.index),int(p.other)]; pair.sort()
				if pair not in data.pairs: data.pairs.append(pair)
				data.compare = int(p.other)
			if int(p.index) not in data.viewed: data.viewed.append(int(p.index))
		"draft": data.material = p.material; data.repair = p.repair
		"seal": TieredAppraisal.stage(day.state,id,2).committed = true
	return ActionResult.new(true,"手记已落笔。" if p.op == "seal" else "")

static func observations(state: RunState, item: ItemInstance) -> Array:
	var data := row(state,item.instance_id)
	if data.is_empty(): return []
	var result := []
	if not data.holes.is_empty(): result.append("已放大查看%d颗珠子的孔口。" % data.holes.size())
	if not data.pairs.is_empty(): result.append("已并排比较%d组珠子。" % data.pairs.size())
	return result

static func observation(bead: Dictionary, angle: int, hole: bool, hidden: bool) -> String:
	if hole and (not hidden or angle == int(bead.hole_angle)):
		return {"fine":"孔壁与珠面相接，边缘有细小自然起伏。","lower":"孔口一侧磨耗，珠面的光泽较散。","imitation":"孔边表层翘起，缺口下露出另一层底色。"}[bead.quality]
	return "转到侧光处，再留意表层与孔口的交界。" if hidden else {"fine":"转动时，光泽沿弧面缓缓移动，细小纹理并不完全一致。","lower":"光泽较散，局部纹理粗些；还须和邻珠比较。","imitation":"表面颇齐整，单看光泽仍难定论。"}[bead.quality]
