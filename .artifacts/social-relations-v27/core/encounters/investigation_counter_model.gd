class_name InvestigationCounterModel
extends RefCounted

static func build(model: Dictionary, day: DayController, catalog: ContentCatalog, visit: CustomerVisit, message: String) -> Dictionary:
	model.active_id = visit.visit_id
	model.customer = "赴约的丈夫\n他没有带货，只将双手放在柜边，等你开口。"
	model.item = "柜上没有货物"
	model["itemless"] = true
	model.context_actions = {"customer": [{"id": "dialogue", "label": "对话", "enabled": true}], "item": []}
	var speech: Array = []
	for row in day.state.investigation.answers:
		var index := InvestigationService.QUESTIONS.find(row.id)
		speech.append({"question": InvestigationService.PROMPTS[index], "answer": InvestigationService.ANSWERS[index]})
	model.visual = {"customer_id": "mirror_husband", "customer_name": "赴约的丈夫", "portrait_asset": "asset.customer_hawker", "item_asset": "", "item_name": "", "item_status": "柜上没有货物", "estimate": "", "clues": [], "speech": speech, "attitude": "只谈旧事", "deadline": "21:30", "introduction": "他没有带货，只将双手放在柜边：‘口信收到了。掌柜想问什么？’", "intent": "应约来谈"}
	model.dialogue = {"body": model.visual.introduction, "buttons": [], "visit_id": visit.visit_id}
	if not speech.is_empty(): model.dialogue.body = speech.back().question + "\n\n" + speech.back().answer
	if not message.is_empty() and not model.dialogue.body.contains(message): model.dialogue.body += "\n\n" + message
	for row in day.state.soul_history:
		if row.visit_id != visit.visit_id or row.result == "expired": continue
		var known := LivingMirror.describe(row)
		if not model.dialogue.body.contains(known): model.dialogue.body += "\n\n" + known
		break
	var count: int = day.state.investigation.answers.size()
	if count < 3:
		var detail: String = InvestigationService.QUESTIONS[count]
		var error := InvestigationService.reason(day, catalog, "meeting_question", visit.visit_id + "|" + detail)
		model.dialogue.buttons.append({"command": "meeting_question", "detail": detail, "label": InvestigationService.PROMPTS[count] + " · 5分钟", "enabled": error.is_empty(), "reason": error})
	var error := InvestigationService.reason(day, catalog, "meeting_end", visit.visit_id)
	model.dialogue.buttons.append({"command": "meeting_end", "detail": "", "label": "结束这次会面", "enabled": error.is_empty(), "reason": error})
	model.trade.body = "这次只谈话，没有货物可买卖。请到对话页问话。"
	model.appraisal.body = "柜上没有货物。"
	return model
