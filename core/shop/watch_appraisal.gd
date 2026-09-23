class_name WatchAppraisal
extends RefCounted

const ITEM := "item_luxury_gold_watch"
const RUNNING := {"stable":"两种姿态均连续","positional":"换姿态后反复停顿","stopping":"上弦后仍中途停走","unsure":"尚难判断"}
const LENGTH := 8.0

static func running_labels(state: RunState, item: ItemInstance) -> Dictionary:
	if WatchNegotiation.handles(state,item):
		return {"stable":"走时连续","positional":"换姿态停顿","stopping":"中途停走","unsure":"尚难判断"}
	return RUNNING

static func handles(state: RunState, item: ItemInstance) -> bool:
	if item == null or item.definition_id != ITEM or state.ghost_catalog == null: return false
	var run := state.ghost_catalog.get_definition("runs",state.run_definition_id) as RunDefinition
	return run != null and run.variety.get("watch_appraisal_version",0) == 1

static func row(state: RunState, id: String) -> Dictionary:
	return TieredAppraisal.stage(state,id,2).get("watch",{})

static func profile(state: RunState, item: ItemInstance) -> String:
	if WatchEconomy.handles(state,item): return item.goods.watch_value.operation
	var n := VarietyService.rng(state.run_seed,item.instance_id+"/watch/operation").randi_range(0,2)
	if item.selected_variant_id == "sound": return "stable"
	return ["stable","positional","stopping"][n]

static func blank() -> Dictionary:
	return {"wound":false,"pose":"flat","opened":false,"listened":[],"marks":{},"spots":[],"running":"unsure"}

static func key(data: Dictionary) -> String:
	return ("wound/" if data.get("wound",false) else "arrival/")+String(data.get("pose","flat"))

# Short acoustic demonstrations, not a precision timing instrument. Same specimen
# always emits the same sequence; truth is never exposed through an asset path.
static func ticks(state: RunState, item: ItemInstance, clip: String) -> PackedFloat32Array:
	if WatchEconomy.handles(state,item):
		var facts: Dictionary = item.goods.watch_value
		return WatchEconomy.sample_ticks(facts.operation,"vertical" if clip.ends_with("vertical") else "flat",facts.offset,clip.begins_with("arrival/") and facts.arrival_empty)
	var times := PackedFloat32Array()
	var behavior := profile(state,item)
	var arrival_empty := VarietyService.rng(state.run_seed,item.instance_id+"/watch/winding").randi_range(0,1) == 0
	for i in 39:
		var t := .2+i*.2
		if clip.begins_with("arrival/") and arrival_empty and t > 1.4: continue
		if behavior == "stopping" and t >= 4.0: continue
		if behavior == "positional" and clip.ends_with("vertical") and ((t >= 2.6 and t < 3.2) or (t >= 5.4 and t < 6.0)): continue
		times.append(t)
	return times

static func anomaly_marked(state: RunState, item: ItemInstance, data: Dictionary) -> bool:
	# v34 records the player's listening judgment without a timeline marking step.
	# Keep legacy mark commands and old-version requirements for replay compatibility.
	if WatchEconomy.handles(state,item):
		return "wound/flat" in data.get("listened",[]) and "wound/vertical" in data.get("listened",[])
	var behavior := profile(state,item)
	if behavior == "stable": return true
	var clip := "wound/vertical" if behavior == "positional" else "wound/flat"
	for mark in data.marks.get(clip,[]):
		if behavior == "stopping" and float(mark) >= 4.0 and float(mark) <= LENGTH: return true
		if behavior == "positional" and ((float(mark) >= 2.6 and float(mark) <= 3.5) or (float(mark) >= 5.4 and float(mark) <= 6.3)): return true
	return false

static func reason(day: DayController, command: String, id: String, detail: String) -> String:
	var access := TieredAppraisal.access(day,id)
	if not access.is_empty(): return access
	if command == "luxury_begin":
		if detail != "2": return "这只怀表使用器材鉴定即可。"
		if not row(day.state,id).is_empty(): return ""
		var item := LuxuryAppraisalService.target(day,id)
		var missing := TieredAppraisal.missing(day,item,2)
		return missing if not missing.is_empty() else TieredAppraisal.time_reason(day,item,10)
	if command != "luxury_watch": return "请在验表台操作器材并记下判断。"
	var parser := JSON.new()
	if parser.parse(detail) != OK or not parser.data is Dictionary: return "验表记录有误。"
	var p: Dictionary = parser.data
	var data := row(day.state,id)
	if data.is_empty(): return "先开始器材鉴定。"
	var sealed: bool = TieredAppraisal.stage(day.state,id,2).get("committed",false)
	if sealed and p.get("op") not in ["pose","wind","open","listen","listen_start"]: return "手记已经落笔，可复看，不能改写。"
	match p.get("op",""):
		"wind","open": pass
		"pose":
			if p.get("pose") not in ["flat","vertical"]: return "请选择平放或竖放。"
		"listen","listen_start":
			var modern := WatchNegotiation.handles(day.state,LuxuryAppraisalService.target(day,id))
			if (p.op == "listen_start") != modern: return "请使用当前验表台试听。"
			if p.get("clip") != key(data): return "表的位置已经改变，请重新听音。"
		"mark":
			if p.get("clip") not in data.listened: return "先完整听过这一段，再标记疑点。"
			var t: Variant = p.get("time")
			if not (t is int or t is float) or not is_finite(float(t)) or t < 0 or t > LENGTH: return "标记须落在试听片段内。"
			if data.marks.get(p.clip,[]).size() >= 3: return "每段最多记三处，可先清除再标记。"
		"clear_marks":
			if p.get("clip") not in data.listened: return "这一段尚未听过。"
		"inspect":
			if not data.opened: return "先打开后盖。"
			if not TieredAppraisal.valid_point(p.get("point")): return "请在机芯上落下放大镜。"
		"draft":
			if p.get("identity") not in ["original","imitation","unsure"] or p.get("condition") not in ["intact","altered","unsure"] or not RUNNING.has(p.get("running")): return "请分别记下身份、修配与运转表现。"
			var target := LuxuryAppraisalService.target(day,id)
			var visit := CustomerManager.new().active(day.state)
			if WatchEconomy.handles(day.state,target) and visit != null and visit.item == target:
				var used: Array = WatchEconomy.owner(day.state,visit).used
				var stage := TieredAppraisal.stage(day.state,id,2)
				if "identity" in used and (p.identity != stage.identity or p.condition != stage.condition): return "已用于谈价的判断不能改写。"
				if "running" in used and p.running != data.running: return "已用于谈价的判断不能改写。"
		"seal":
			if not WatchEconomy.handles(day.state,LuxuryAppraisalService.target(day,id)):
				if not ("wound/flat" in data.listened and "wound/vertical" in data.listened): return "先上弦，分别听过平放和竖放。"
				if data.spots.size() < 2: return "再用放大镜查看夹板与机芯座。"
		_: return "没有这项验表操作。"
	return ""

static func perform(day: DayController, command: String, id: String, detail: String) -> ActionResult:
	var why := reason(day,command,id,detail)
	if not why.is_empty(): return ActionResult.new(false,why)
	if command == "luxury_begin":
		if not row(day.state,id).is_empty(): return ActionResult.new(true,"已将怀表重新放上鉴物台。")
		var spent := day.spend_action(10)
		if not spent.ok: return spent
		var all: Dictionary = WealthyCustomers.data(day.state).appraisals
		if not all.has(id): all[id] = {"exterior":false,"stages":{}}
		all[id].stages["2"] = TieredAppraisal.blank_stage()
		all[id].stages["2"]["watch"] = blank()
		all[id].stages["2"].identity = "unsure"; all[id].stages["2"].condition = "unsure"
		CustomerManager.new().update(day.state)
		return ActionResult.new(true,"怀表已放稳。可以上弦、听音，或开盖核对。")
	var p: Dictionary = JSON.parse_string(detail)
	var data := row(day.state,id)
	var stage := TieredAppraisal.stage(day.state,id,2)
	match p.op:
		"wind": data.wound = true
		"pose": data.pose = p.pose
		"open": data.opened = true
		"listen":
			if p.clip not in data.listened: data.listened.append(p.clip)
		"listen_start":
			if not data.has("started"): data.started = []
			if p.clip not in data.started: data.started.append(p.clip)
		"mark":
			if not data.marks.has(p.clip): data.marks[p.clip] = []
			data.marks[p.clip].append(snappedf(float(p.time),.01))
		"clear_marks": data.marks[p.clip] = []
		"inspect":
			var point := Vector2(p.point[0],p.point[1])
			var target := LuxuryAppraisalService.target(day,id)
			var radius := .045 if WatchMovementPatterns.kind(target) == "gears" else .085
			for i in 2:
				if point.distance_to(spot(target,i)) <= radius and i not in data.spots: data.spots.append(i)
		"draft":
			stage.identity = p.identity; stage.condition = p.condition; data.running = p.running
		"seal": stage.committed = true
	return ActionResult.new(true,"手记已落笔。" if p.op == "seal" else "")

static func spot(item: ItemInstance, index: int) -> Vector2:
	var pattern_points := WatchMovementPatterns.points(item)
	if not pattern_points.is_empty(): return pattern_points[index]
	var points := {"sound":[Vector2(.53,.425),Vector2(.711,.457)],"mended":[Vector2(.53,.415),Vector2(.698,.533)],"flawed":[Vector2(.557,.501),Vector2(.728,.585)]}
	return points[item.selected_variant_id][index]

static func correct(state: RunState, item: ItemInstance) -> bool:
	var stage := TieredAppraisal.stage(state,item.instance_id,2)
	var data := row(state,item.instance_id)
	if not stage.get("committed",false): return false
	var book := LuxuryAppraisalService.info(state,item)
	return stage.identity == book.identity[item.selected_variant_id] and stage.condition == book.condition[item.selected_variant_id] and data.running == profile(state,item) and anomaly_marked(state,item,data)

static func observations(state: RunState, item: ItemInstance) -> Array:
	var result := []
	var data := row(state,item.instance_id)
	if data.is_empty(): return result
	var lines := {
		"sound":["夹板轮廓与图录的转折位置相应。","机芯边缘与座圈贴合，固定处未见另加垫片。"],
		"mended":["夹板分成几条，外沿与图录所绘不同。","机芯外缘多了一圈转接件，固定螺钉旁留有改装痕迹。"],
		"flawed":["夹板与轮系布局和图录有多处差别。","机芯较小，外缘靠一圈宽垫圈填满。"]}
	var pattern_lines := WatchMovementPatterns.lines(item)
	if not pattern_lines.is_empty(): lines.flawed = pattern_lines
	for i in data.spots: result.append(lines[item.selected_variant_id][int(i)])
	return result
