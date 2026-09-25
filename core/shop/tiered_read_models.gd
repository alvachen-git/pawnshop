class_name TieredReadModels
extends RefCounted

static func enrich(model: Dictionary, day: DayController, visit: CustomerVisit) -> void:
	var item := visit.item
	var record := TieredAppraisal.record(day.state,item.instance_id)
	var definition := day.state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
	model.appraisal.body = definition.display_name+"\n"+TieredAppraisal.exterior_text(day.state,item)
	model.appraisal.buttons = []
	for spec in [["luxury_exterior","", "复看外观 · 不耗时" if record.get("exterior",false) else "检查外观 · 5分钟"], ["luxury_begin","2", "器材鉴定"], ["luxury_begin","3","深入查验"]]:
		if (WatchAppraisal.handles(day.state,item) or PearlEconomy.handles(day.state,item) or BangleEconomy.handles(day.state,item) or PorcelainEconomy.handles(day.state,item) or GramophoneEconomy.handles(day.state,item) or CameraEconomy.handles(day.state,item)) and spec[1] == "3": continue
		var command: String = spec[0]; var detail: String = spec[1]; var label: String = spec[2]
		var why := TieredAppraisal.reason(day,command,item.instance_id,detail)
		if command == "luxury_begin":
			var cost := TieredAppraisal.minutes(day.state,item.instance_id,int(detail))
			label += " · %d分钟" % cost if cost > 0 else " · 复看记录"
		model.appraisal.buttons.append({"command":command,"detail":detail,"label":label,"enabled":why.is_empty(),"reason":why})
		if not why.is_empty(): model.appraisal.body += "\n"+String(spec[2])+" · "+why
	for button in model.trade.buttons:
		if button.command == "luxury_pressure": button.label = "拿新证据谈价 · 5分钟 / 1轮"
	if WatchEconomy.handles(day.state,item) and not WatchNegotiation.handles(day.state,item):
		var reason := WatchEconomy.bluff_reason(day,visit,"",0)
		model.trade.buttons.append({"command":"watch_bluff","detail":"","label":WatchEconomy.BLUFF+" · 5分钟 / 1轮","enabled":reason.is_empty(),"reason":reason})
	var paid := 3 if not TieredAppraisal.stage(day.state,item.instance_id,3).is_empty() else 2
	var current := TieredAppraisal.stage(day.state,item.instance_id,paid)
	var context := "外观："+TieredAppraisal.exterior_text(day.state,item)
	if WatchEconomy.handles(day.state,item):
		var accepted: Array = WatchEconomy.owner(day.state,visit).accepted
		if not accepted.is_empty(): context += "\n已认下："+"、".join(accepted.map(func(part: String) -> String: return {"exterior":"外观","identity":"身份与修配","running":"运转"}[part]))
	if current.get("committed",false):
		context += "\n自鉴："+String(TieredAppraisal.identities(day.state,item).get(current.identity,"暂难定论"))+" · "+String(TieredAppraisal.conditions().get(current.condition,"暂难定论"))
		if WatchEconomy.handles(day.state,item): context = context.replace("与声称相符","原厂真品")
	for visual: Dictionary in [model.visual,model.appraisal.visual,model.dialogue.visual,model.trade.visual]:
		visual["luxury_context"] = context
		visual["clues"] = []
		if record.get("exterior",false): visual.clues.append({"id":"exterior","text":TieredAppraisal.exterior_text(day.state,item)})
		var observations := TieredAppraisal.observations(day.state,item,paid)
		for index in observations.size(): visual.clues.append({"id":"precision/%d/%d" % [paid,index],"text":observations[index]})
		visual["tiered_atlas"] = TieredAppraisal.config(day.state,item).atlas
		if WatchAppraisal.handles(day.state,item): visual["watch_art"] = true
		visual["tiered_exterior"] = ["intact","minor","major"].find(item.goods.precision.damage) if record.get("exterior",false) else 0
		var trade := WealthyCustomers.trade(day.state,visit)
		visual["estimate"] = str(trade.value) if trade.get("precision_identity",false) else "尚未定值"
		if WatchEconomy.handles(day.state,item) and not WatchEconomy.owner(day.state,visit).accepted.is_empty(): visual["estimate"] = "暂估%d" % trade.value
	# Older versions retain their concise drawer; v34 shares the ordinary summary.
	model.appraisal.visual = {}
	if WatchEconomy.enabled(day.definition):
		var bounds := estimate_bounds(day.state,item,definition)
		var judgment := PackedStringArray()
		if current.get("identity","") not in ["","unsure"]:
			judgment.append(String(TieredAppraisal.identities(day.state,item).get(current.identity,"暂难定论")))
		if current.get("condition","") not in ["","unsure"]:
			judgment.append(String(TieredAppraisal.conditions().get(current.condition,"暂难定论")))
		var watch: Dictionary = WatchAppraisal.row(day.state,item.instance_id) if WatchAppraisal.handles(day.state,item) else {}
		if watch.get("running","unsure") != "unsure": judgment.append(WatchAppraisal.running_labels(day.state,item)[watch.running])
		for visual: Dictionary in [model.visual,model.dialogue.visual,model.trade.visual]:
			visual["estimate"] = "%d–%d" % [bounds.x,bounds.y]
			visual["estimate_is_range"] = true
			visual["judgement"] = " · ".join(judgment) if not judgment.is_empty() else "暂不判断"
			for pose in ["flat","vertical"]:
				if "wound/"+pose in watch.get("listened",[]):
					visual.clues.append({"id":"watch/listen/"+pose,"text":"上弦后，已完整听过%s走时。" % ("平放" if pose == "flat" else "竖放")})
			if WatchNegotiation.handles(day.state,item):
				for clip in watch.get("started",[]):
					visual.clues.append({"id":"watch/start/"+clip,"text":("上弦后" if clip.begins_with("wound/") else "上弦前")+"，已试听"+("平放" if clip.ends_with("flat") else "竖放")+"走时。"})
		# Share the ordinary item, estimate, judgment and clues presentation.
		model.appraisal.visual = model.visual.duplicate(true)
		model.appraisal.visual.message = String(model.trade.visual.get("message",""))
	var funding := int(WealthyCustomers.trade(day.state,visit).funding)
	if funding > 0: model.trade.visual.luxury_context += "\n客人至少需筹%d银元。" % funding
	if WatchNegotiation.handles(day.state,item):
		model.trade.buttons = model.trade.buttons.filter(func(b: Dictionary) -> bool: return b.command not in ["luxury_pressure","watch_bluff"])
		model.trade["watch_claims"] = WatchNegotiation.model(day,visit)

	if PearlEconomy.handles(day.state,item): PearlReadModels.enrich(model,day,visit)
	if BangleEconomy.handles(day.state,item): BangleReadModels.enrich(model,day,visit)
	if GramophoneEconomy.handles(day.state,item): GramophoneReadModels.enrich(model,day,visit)
	if CameraEconomy.handles(day.state,item): CameraReadModels.enrich(model,day,visit)
	if PorcelainEconomy.handles(day.state,item): PorcelainReadModels.enrich(model,day,visit)

static func estimate_bounds(state: RunState, item: ItemInstance, definition: ItemDefinition) -> Vector2i:
	# Only inspected exterior damage narrows this public range. Never consult the
	# actual variant, hidden operation, owner belief or the player's unverified guess.
	var checked: bool = TieredAppraisal.record(state,item.instance_id).get("exterior",false)
	var lower_damage := float(TieredAppraisal.RETAIN[item.goods.precision.damage])/100.0 if checked else .5
	var upper_damage := lower_damage if checked else 1.0
	var lower_operation := .5 if WatchEconomy.handles(state,item) else 1.0
	return Vector2i(maxi(1,roundi(definition.unknown_min*lower_damage*lower_operation)),maxi(1,roundi(definition.unknown_max*upper_damage)))
