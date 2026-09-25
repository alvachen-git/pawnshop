class_name GramophoneReadModels
extends RefCounted

static func enrich(model: Dictionary, day: DayController, visit: CustomerVisit) -> void:
	var item := visit.item; var record := TieredAppraisal.record(day.state,item.instance_id); var r := GramophoneAppraisal.row(day.state,item.instance_id)
	var factor := float(TieredAppraisal.RETAIN[item.goods.precision.damage])/100.0 if record.get("exterior",false) else 1.0
	var estimate := "%d–%d" % [roundi(33*factor),roundi(700*factor)]
	var notes := PackedStringArray()
	for part in ["identity","sound","motor"]:
		if r.get(part,"unsure") != "unsure": notes.append(GramophoneNegotiation.OPTIONS[part][r[part]])
	for visual: Dictionary in [model.visual,model.appraisal.visual,model.dialogue.visual,model.trade.visual]:
		visual["gramophone_art"] = item.goods.gramophone_value.duplicate(true)
		visual.gramophone_art.erase("actual")
		visual.gramophone_art["damage"] = item.goods.precision.damage
		visual.estimate = estimate; visual.estimate_is_range = true
		visual.judgement = " · ".join(notes) if not notes.is_empty() else "暂不判断"
		visual.luxury_context = "外观："+TieredAppraisal.exterior_text(day.state,item)
		if TieredAppraisal.stage(day.state,item.instance_id,2).get("committed",false): visual.luxury_context += "\n自己的手记："+visual.judgement
	var funding: int = WealthyCustomers.trade(day.state,visit).funding
	if funding > 0: model.trade.visual.luxury_context += "\n客人至少需筹%d银元。" % funding
	model.trade.buttons = model.trade.buttons.filter(func(b: Dictionary) -> bool: return b.command not in ["luxury_pressure","watch_bluff"])
	model.trade["gramophone_claims"] = GramophoneNegotiation.model(day,visit)
