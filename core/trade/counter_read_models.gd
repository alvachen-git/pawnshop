class_name CounterReadModels
extends RefCounted

const JUDGEMENTS := {"unknown": "暂不判断", "sound": "完好真品", "damaged": "有修补/瑕疵", "fake": "仿制/材质不符"}
const OUTCOMES := {"bought": "成交", "pawned": "活当放款", "rejected": "拒收", "timed_out": "等候超时离场", "shop_closed": "关铺失去机会", "patience_exhausted": "耐心耗尽", "rounds_exhausted": "议价结束"}

static func build(day: DayController, service: CounterService, message: String) -> Dictionary:
	var blank := {"body": "暂无正在接待的顾客。\n请在营业页开铺或等待来客。", "buttons": [], "visit_id": ""}
	var model := {"active_id": "", "customer": "顾客席 · 暂无顾客", "item": "柜台暂空", "queue": "", "appraisal": blank.duplicate(true), "dialogue": blank.duplicate(true), "trade": blank.duplicate(true), "inventory": {"body": "库存为空。"}, "ledger": {"body": "暂无收购流水。"}}
	model.trade.can_offer = false
	model.trade.asking_price = 1
	model.trade.max_input = 1000000
	model.trade.can_pawn = false
	model.trade.pawn_asking = 1
	if service == null: return model
	var state := day.state
	var waiting := 0
	var next_arrival := -1
	for visit in state.visits:
		if visit.status == "waiting": waiting += 1
		if visit.status == "scheduled" and (next_arrival < 0 or visit.arrival < next_arrival): next_arrival = visit.arrival
	model.queue = "等待中 %d 人" % waiting
	if next_arrival >= 0: model.queue += " · 下一客约 %s" % TimeController.clock_text(day.definition.opening_minute, next_arrival)
	if not state.visit_history.is_empty():
		var last: Dictionary = state.visit_history.back()
		model.queue += "\n最近结果：" + OUTCOMES[last.outcome]
	var visit := service.customers.active(state)
	if visit == null:
		for feature in ["appraisal", "dialogue", "trade"]: model[feature].body += "\n\n" + message
		return model
	var customer := service.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := service.catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	model.active_id = visit.visit_id
	model.customer = customer.terms.display_name + "\n" + customer.terms.introduction
	model.item = item.display_name + "\n" + item.description
	var bounds := service.appraisal.valuation(visit.item, item)
	var evidence_lines: PackedStringArray = []
	for clue_id in visit.item.revealed_clue_ids: evidence_lines.append("• " + item.find_clue(clue_id).text)
	model.appraisal.body = "%s\n证据估值：%d–%d（不是买家报价）\n你的判断：%s\n\n%s" % [item.display_name, bounds.x, bounds.y, JUDGEMENTS[visit.item.judgement], "\n".join(evidence_lines) if not evidence_lines.is_empty() else "尚未取得证据。卖家说法不能替代检查。"]
	for action in item.appraisal_actions:
		model.appraisal.buttons.append(_button(day, service, visit, "appraise", action.id, "%s · %d分钟" % [action.label, action.minutes]))
	for key in JUDGEMENTS:
		model.appraisal.buttons.append(_button(day, service, visit, "judge", key, "记录判断：" + JUDGEMENTS[key]))
	model.dialogue.body = customer.terms.introduction + "\n\n卖家口供未证实，不自动收窄估值。"
	for question in customer.questions:
		if question.id in visit.asked_question_ids: model.dialogue.body += "\n\n" + question.prompt + "\n" + question.answer
		model.dialogue.buttons.append(_button(day, service, visit, "question", question.id, "%s · %d分钟" % [question.prompt, question.minutes]))
	model.trade.body = "%s · 要价 %d\n剩余议价轮次 %d · %s\n报价 %d分钟 / 施压 %d分钟，各消耗一轮。\n收购前请自行判断证据与承受价。" % [item.display_name, visit.trade.asking_price, visit.trade.rounds_left, "显得不耐烦" if visit.trade.patience < customer.patience else "尚愿意交谈", customer.terms.quote_minutes, customer.terms.pressure_minutes]
	for clue_id in visit.item.revealed_clue_ids:
		var clue := item.find_clue(clue_id)
		var button := _button(day, service, visit, "pressure", clue_id, "据此压价：" + clue.text.left(16) + "…")
		if button.enabled: button.reason = clue.text
		model.trade.buttons.append(button)
	model.trade.buttons.append(_button(day, service, visit, "reject", "", "拒绝收货 · %d分钟" % customer.terms.reject_minutes))
	model.trade.asking_price = visit.trade.asking_price
	model.trade.can_offer = service.reason(day, "offer", visit.visit_id, "", 1).is_empty()
	var terms := service.catalog.get_definition("pawn_terms", customer.pawn_terms_id) as PawnTermsDefinition
	if terms != null:
		model.trade.can_pawn = service.reason(day, "pawn", visit.visit_id, "", 1).is_empty()
		model.trade.pawn_asking = maxi(1, roundi(visit.trade.asking_price * terms.loan_ratio))
		model.trade.body += "\n活当要款 %d · 期限%d夜 · 赎金=本金+向上取整的%.0f%%息费。\n收购/活当共用剩余轮次与耐心。" % [model.trade.pawn_asking, terms.term_nights, terms.redemption_fee_ratio * 100]
	for feature in ["appraisal", "dialogue", "trade"]:
		model[feature].visit_id = visit.visit_id
		model[feature].body += "\n\n" + message
	return model

static func _button(day: DayController, service: CounterService, visit: CustomerVisit, command: String, detail: String, label: String) -> Dictionary:
	var reason := service.reason(day, command, visit.visit_id, detail)
	return {"command": command, "detail": detail, "label": label, "enabled": reason.is_empty(), "reason": reason}
