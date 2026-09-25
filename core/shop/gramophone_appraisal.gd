class_name GramophoneAppraisal
extends RefCounted

const GROUPS := ["identity","soundbox","playback"]
const LABELS := {"identity":"铭牌与装配","soundbox":"唱头与振膜","playback":"上弦与试听"}

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("gramophone",{})

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var why:=TieredAppraisal.access(day,id)
	if not why.is_empty():return why
	var item:=LuxuryAppraisalService.target(day,id)
	if not GramophoneEconomy.handles(day.state,item):return "眼前没有这架留声机。"
	if command=="luxury_begin":
		if detail!="2":return "这架留声机使用器材鉴定即可。"
		if not row(day.state,id).is_empty():return ""
		why=TieredAppraisal.missing(day,item,2)
		return why if not why.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command!="luxury_gramophone":return "请在案上查验留声机，或记下判断。"
	var p: Variant=JSON.parse_string(detail)
	if not p is Dictionary or not p.get("op") is String:return "查验记录有误。"
	var d:=row(day.state,id)
	if d.is_empty():return "先开始器材鉴定。"
	if p.op in ["draft","seal"] and TieredAppraisal.stage(day.state,id,2).committed:return "手记已落笔，不能改写。"
	match p.op:
		"seal","wind","listen","stop":pass
		"group":
			if p.get("group") not in GROUPS:return "请选择查验部位。"
		"record":
			if p.get("value") not in ["customer","reference"]:return "请选择唱片。"
		"speed":
			if p.get("value") not in ["slow","nominal","fast"]:return "请选择调速位置。"
		"zoom":
			if not p.get("zoom") is bool:return "请选择放大或缩回。"
		"draft":
			for part in ["identity","sound","motor"]:
				if p.get(part)!="unsure" and p.get(part) not in GramophoneNegotiation.OPTIONS[part]:return "分别记下身份、发声与动力判断。"
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
		var item:=LuxuryAppraisalService.target(day,id)
		all[id].stages["2"]["gramophone"]={"group":"identity","viewed":["identity"],"zoom":false,"speed":"nominal","speeds":[],"record":"customer","wound":item.goods.gramophone_value.initial_wound,"tests":[],"identity":"unsure","sound":"unsure","motor":"unsure"}
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"留声机已放稳，可查看部件、摇柄上弦，换片试听。")
	var p: Dictionary=JSON.parse_string(detail);var d:=row(day.state,id)
	match p.op:
		"group":
			d.group=p.group
			if p.group not in d.viewed:d.viewed.append(p.group)
		"zoom":
			d.zoom=p.zoom
			if p.zoom and d.group=="identity":d["identity_zoom"]=true
		"record":d.record=p.value
		"speed":
			d.speed=p.value
			if p.value not in d.speeds:d.speeds.append(p.value)
		"wind":d.wound=true
		"listen":
			# Record on click; play duration and stopping never alter evidence or item facts.
			var key:=String("wound/" if d.wound else "unwound/")+String(d.record)+"/"+String(d.speed)
			if key not in d.tests:d.tests.append(key)
		"draft":
			for part in ["identity","sound","motor"]:d[part]=p[part]
		"seal":TieredAppraisal.stage(day.state,id,2).committed=true
	return ActionResult.new(true,"手记已落笔。" if p.op=="seal" else "")

static func observations(state: RunState, item: ItemInstance) -> Array:
	var d:=row(state,item.instance_id);var result:=[]
	for group in d.get("viewed",[]):result.append("已查看"+LABELS[group]+"。")
	if not d.get("tests",[]).is_empty():result.append("已落针试听；听到的表现请自行判断。")
	return result
