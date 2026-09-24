class_name PorcelainAppraisal
extends RefCounted

const GROUPS := ["body","painting","foot"]
const LABELS := {"body":"整器","painting":"绘纹","foot":"底足"}

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("porcelain",{})

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var why := TieredAppraisal.access(day,id)
	if not why.is_empty(): return why
	var item := LuxuryAppraisalService.target(day,id)
	if not PorcelainEconomy.handles(day.state,item): return "眼前没有这只青花瓶。"
	if command == "luxury_begin":
		if detail != "2": return "这只瓶子使用器材鉴定即可。"
		if not row(day.state,id).is_empty(): return ""
		why = TieredAppraisal.missing(day,item,2)
		return why if not why.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command != "luxury_porcelain": return "请在案上转瓶、看底足，或记下判断。"
	var p: Variant = JSON.parse_string(detail)
	if not p is Dictionary or not p.get("op") is String: return "查验记录有误。"
	var d := row(day.state,id)
	if d.is_empty(): return "先开始器材鉴定。"
	if p.op in ["draft","seal"] and TieredAppraisal.stage(day.state,id,2).committed: return "手记已落笔，不能改写。"
	match p.op:
		"seal": pass
		"group":
			if p.get("group") not in GROUPS: return "请选择整器、绘纹或底足。"
		"turn":
			if not RunSchema.integer(p.get("angle")) or int(p.angle) not in [0,1,2,3]: return "请选择有效角度。"
		"light":
			if p.get("light") not in ["left","front","right"]: return "请选择灯光位置。"
		"zoom":
			if not p.get("zoom") is bool: return "请选择放大或缩回。"
		"reference":
			if p.get("era") not in PorcelainEconomy.BASE: return "请选择图录年代。"
		"sample":
			if not RunSchema.integer(p.get("sample")) or int(p.sample) not in [0,1]: return "请选择图录样本。"
		"draft":
			if p.get("era") not in ["yuan","ming","qing","republic","unsure"] or p.get("craft") not in ["rough","standard","fine","unsure"]: return "分别记下年代和工艺判断。"
		_: return "没有这项查验操作。"
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
		all[id].stages["2"]["porcelain"] = {"group":"body","angle":0,"light":"front","zoom":false,"reference":"ming","sample":0,"viewed":["body"],"era":"unsure","craft":"unsure"}
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"瓶子已放在案上，可转看整器、绘纹和底足。")
	var p: Dictionary = JSON.parse_string(detail); var d := row(day.state,id)
	match p.op:
		"group":
			d.group = p.group
			if p.group not in d.viewed: d.viewed.append(p.group)
		"turn":
			d.angle = int(p.angle)
			d.group = "body"
			if "body" not in d.viewed: d.viewed.append("body")
		"light": d.light = p.light
		"zoom": d.zoom = p.zoom
		"reference": d.reference = p.era
		"sample": d.sample = int(p.sample)
		"draft": d.era = p.era; d.craft = p.craft
		"seal": TieredAppraisal.stage(day.state,id,2).committed = true
	return ActionResult.new(true,"手记已落笔。" if p.op=="seal" else "")

static func observations(state: RunState, item: ItemInstance) -> Array:
	var result := []
	for group in row(state,item.instance_id).get("viewed",[]): result.append("已查看"+LABELS[group]+"。")
	return result
