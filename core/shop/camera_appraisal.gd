class_name CameraAppraisal
extends RefCounted

const GROUPS := ["identity","lens","aperture","shutter"]
const LABELS := {"identity":"铭文与镜座","lens":"镜片","aperture":"光圈","shutter":"快门"}

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("camera",{})

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var why:=TieredAppraisal.access(day,id)
	if not why.is_empty():return why
	var item:=LuxuryAppraisalService.target(day,id)
	if not CameraEconomy.handles(day.state,item):return "眼前没有这架相机。"
	if command=="luxury_begin":
		if detail!="2":return "这架相机使用器材鉴定即可。"
		if not row(day.state,id).is_empty():return ""
		why=TieredAppraisal.missing(day,item,2)
		return why if not why.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command!="luxury_camera":return "请在案上查看相机，或记下判断。"
	var p: Variant=JSON.parse_string(detail)
	if not p is Dictionary or not p.get("op") is String:return "查验记录有误。"
	var d:=row(day.state,id)
	if d.is_empty():return "先开始器材鉴定。"
	if p.op in ["draft","seal"] and TieredAppraisal.stage(day.state,id,2).committed:return "手记已落笔，不能改写。"
	match p.op:
		"seal","wind","shutter":pass
		"group":
			if p.get("group") not in GROUPS:return "请选择查验部位。"
		"light":
			if p.get("light") not in ["left","front","right"]:return "请选择灯光位置。"
		"aperture":
			if p.get("value") not in ["open","middle","narrow"]:return "请选择光圈开度。"
		"speed":
			if p.get("value") not in ["slow","fast"]:return "请选择快门挡位。"
		"zoom":
			if not p.get("zoom") is bool:return "请选择放大或缩回。"
		"draft":
			for part in ["identity","lens","mechanism"]:
				if p.get(part)!="unsure" and p.get(part) not in CameraNegotiation.OPTIONS[part]:return "分别记下身份、镜片与运转判断。"
		_:return "没有这项查验操作。"
	return ""

static func perform(day: DayController, command: String, id: String, detail: String) -> ActionResult:
	var why:=reason(day,command,id,detail)
	if not why.is_empty():return ActionResult.new(false,why)
	if command=="luxury_begin":
		if not row(day.state,id).is_empty():return ActionResult.new(true,"")
		var spent:=day.spend_action(10)
		if not spent.ok:return spent
		var all: Dictionary=WealthyCustomers.data(day.state).appraisals
		if not all.has(id):all[id]={"exterior":false,"stages":{}}
		all[id].stages["2"]=TieredAppraisal.blank_stage()
		all[id].stages["2"].identity="unsure";all[id].stages["2"].condition="unsure"
		all[id].stages["2"]["camera"]={"group":"identity","viewed":["identity"],"light":"front","lights":[],"zoom":false,"aperture":"middle","apertures":[],"speed":"slow","wound":false,"tests":[],"last_wound":false,"identity":"unsure","lens":"unsure","mechanism":"unsure"}
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"相机已放在案上，可查镜片、调光圈，过片后试快门。")
	var p: Dictionary=JSON.parse_string(detail);var d:=row(day.state,id)
	match p.op:
		"group":
			d.group=p.group
			if p.group not in d.viewed:d.viewed.append(p.group)
			if p.group=="lens" and d.light not in d.lights:d.lights.append(d.light)
		"light":
			d.light=p.light
			if d.group=="lens" and p.light not in d.lights:d.lights.append(p.light)
		"zoom":
			d.zoom=p.zoom
			if p.zoom and d.group=="identity":d["identity_zoom"]=true
		"aperture":
			d.aperture=p.value
			if p.value not in d.apertures:d.apertures.append(p.value)
		"speed":d.speed=p.value
		"wind":d.wound=true
		"shutter":
			d.last_wound=d.wound
			var key:=String("wound/" if d.wound else "unwound/")+String(d.speed)
			if key not in d.tests:d.tests.append(key)
			d.wound=false
		"draft":
			for part in ["identity","lens","mechanism"]:d[part]=p[part]
		"seal":TieredAppraisal.stage(day.state,id,2).committed=true
	return ActionResult.new(true,"手记已落笔。" if p.op=="seal" else "")

static func observations(state: RunState, item: ItemInstance) -> Array:
	var d:=row(state,item.instance_id);var result:=[]
	for group in d.get("viewed",[]):result.append("已查看"+LABELS[group]+"。")
	if not d.get("apertures",[]).is_empty():result.append("已试调光圈。")
	if not d.get("tests",[]).is_empty():result.append("已按动快门。")
	return result
