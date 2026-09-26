class_name LuxuryReadModels
extends RefCounted

static func enrich(model: Dictionary, day: DayController, service: CounterService, visit: CustomerVisit, message: String) -> void:
	if not WealthyCustomers.active(day.state) or (not WealthyCustomers.is_customer(visit.customer_id) and not (SpecialGuests.late(day.state, visit) and WealthyCustomers.is_item(visit.item.definition_id))): return
	var appraisal := LuxuryAppraisalService.record(day.state,visit.item.instance_id)
	var item := day.state.ghost_catalog.get_definition("items",visit.item.definition_id) as ItemDefinition
	model.appraisal.body = item.display_name + "\n\n已查%d/2处。" % appraisal.get("checks",[]).size()
	if FanAppraisalService.bench_level(day.state) < 2: model.appraisal.body += "\n二级鉴物台建成后可细查。"
	var label := "查看鉴定记录" if appraisal.get("committed",false) else "继续鉴定" if not appraisal.is_empty() else "开始鉴定 · 每处10分钟"
	model.appraisal.buttons = [{"command":"luxury_open","detail":visit.item.instance_id,"label":label,"enabled":true,"reason":""}]
	# The ordinary appraisal panel replaces body with its generic visual summary.
	# Keep the luxury evidence and the player's two independent decisions intact.
	model.appraisal.visual = {}
	var modes: Array = visit.transaction_modes
	var pawn := "pawn" in modes
	model.trade.asking_price = visit.trade.asking_price
	model.trade.pawn_asking = visit.trade.asking_price
	var reference := int(WealthyCustomers.trade(day.state,visit).reference)
	model.trade.body = "%s%d银元\n剩余议价%d轮 · %s\n报价和举证各5分钟、各用一轮。" % ["活当要款" if pawn else "出售要价",visit.trade.asking_price,visit.trade.rounds_left,"显得不耐烦" if visit.trade.patience < 2 else "尚愿交谈"]
	if pawn: model.trade.body += "\n当期3夜，息费按选定档位计算，零头向上取整。" if PawnInterestPolicy.enabled(day.definition) else "\n当期3夜，赎金为本金加向上取整的10%息费。"
	var funding := int(WealthyCustomers.trade(day.state,visit).funding)
	if funding > 0: model.trade.body += "\n客人说这回至少需筹%d银元。" % funding
	model.trade.body += "\n\n" + message
	model.dialogue.body = String(visit.voice.introduction) + "\n\n" + model.dialogue.body
	var error := LuxuryAppraisalService.pressure_reason(day,visit,"",0)
	model.trade.buttons.push_front({"command":"luxury_pressure","detail":"","label":"拿鉴定记录谈价 · 5分钟 / 1轮","enabled":error.is_empty(),"reason":error})
	for feature in ["dialogue","trade"]:
		model[feature].visual.asking = visit.trade.asking_price
		model[feature].visual.original_pawn_basis = reference
		model[feature].visual.original_purchase_basis = reference
		model[feature].visual["luxury"] = true
		model[feature].visual["luxury_pawn_asking"] = visit.trade.asking_price
	model.visual.asking = visit.trade.asking_price
	model.visual["luxury"] = true
	model.visual["luxury_pawn_asking"] = visit.trade.asking_price
	var record := LuxuryAppraisalService.record(day.state,visit.item.instance_id)
	var book := LuxuryAppraisalService.info(day.state,visit.item)
	for visual: Dictionary in [model.visual,model.dialogue.visual,model.trade.visual]:
		visual.clues.clear()
		for index in record.get("checks",[]):
			visual.clues.append({"id":"luxury/"+index,"text":book.observations[visit.item.selected_variant_id][int(index)]})
		visual["luxury_context"] = "身份：" + String(LuxuryAppraisalService.IDENTITIES.get(record.get("identity",""),"尚未判断")) + " · 品相：" + String(LuxuryAppraisalService.CONDITIONS.get(record.get("condition",""),"尚未判断"))
		if funding > 0: visual.luxury_context += "\n客人明确说，至少需筹%d银元。" % funding
		if WealthyCustomers.trade(day.state,visit).evidence_used and LuxuryAppraisalService.correct(day.state,visit.item): visual.estimate = str(WealthyCustomers.trade(day.state,visit).value)
	if TieredAppraisal.enabled(day.definition): TieredReadModels.enrich(model,day,visit)
