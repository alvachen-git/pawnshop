class_name CounterReadModels
extends RefCounted

const JUDGEMENTS := {"unknown": "暂不判断", "sound": "完好真品", "damaged": "有修补/瑕疵", "fake": "仿制/材质不符"}
const OUTCOMES := {"redeemed_early": "提前赎回", "redemption_deferred": "约定到期再来", "bought": "成交", "pawned": "活当放款", "rejected": "拒收", "timed_out": "等候超时离场", "shop_closed": "关铺失去机会", "patience_exhausted": "耐心耗尽", "rounds_exhausted": "议价结束"}

static func build(day: DayController, service: CounterService, message: String, message_visit_id := "") -> Dictionary:
	var blank := {"body": "暂无正在接待的顾客。\n请在营业页开铺或等待来客。", "buttons": [], "visit_id": ""}
	var model := {"active_id": "", "customer": "顾客席 · 暂无顾客", "item": "柜台暂空", "queue": "", "context_actions": {"customer": [], "item": []}, "appraisal": blank.duplicate(true), "dialogue": blank.duplicate(true), "trade": blank.duplicate(true), "inventory": {"body": "库存为空。"}, "ledger": {"body": "暂无收购流水。"}}
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
	if next_arrival >= 0 and not SevenNightPlan.enabled(day.definition): model.queue += " · 下一客约 %s" % TimeController.clock_text(day.definition.opening_minute, next_arrival)
	if not state.visit_history.is_empty():
		var last: Dictionary = state.visit_history.back()
		var who := ""
		for ended in state.visits:
			if ended.visit_id == last.visit_id:
				var ended_customer := service.catalog.get_definition("customers", ended.customer_id) as CustomerDefinition
				who = String(ended.person.get("name", ended_customer.terms.display_name))
				break
		if int(last.night) == state.current_night_index and not who.is_empty():
			model.queue += "\n%s · %s：%s" % [TimeController.clock_text(day.definition.opening_minute, int(last.minute)), who, OUTCOMES[last.outcome]]
	var visit := service.customers.active(state)
	# A completed action may have moved the queue to another customer already.
	# Keep its result in the departure/receipt flow, not in the new reception.
	if not message_visit_id.is_empty() and (visit == null or visit.visit_id != message_visit_id): message = ""
	if visit == null:
		for feature in ["appraisal", "dialogue", "trade"]: model[feature].body += "\n\n" + message
		return model
	var customer := service.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := service.catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	model.active_id = visit.visit_id
	model.context_actions.customer = [
		{"id": "dialogue", "label": "对话", "enabled": true},
		{"id": "trade", "label": "交易", "enabled": true},
	]
	model.context_actions.item = [{"id": "appraisal", "label": "鉴定", "enabled": true}]
	model.customer = customer.terms.display_name + "\n" + customer.terms.introduction
	model.item = item.display_name + "\n" + item.description
	var scenario := TradeScenarioService.for_visit(day.definition, visit)
	if scenario != null: model.customer = customer.terms.display_name + "\n" + scenario.introduction
	if not visit.person.is_empty(): model.customer = VarietyService.name_for(visit.person, customer) + "\n" + customer.terms.introduction
	var bounds := service.appraisal.valuation(visit.item, item)
	var evidence_lines: PackedStringArray = []
	for clue_id in visit.item.revealed_clue_ids: evidence_lines.append("• " + item.find_clue(clue_id).text)
	model.appraisal.body = "%s\n证据估值：%d–%d（不是买家报价）\n你的判断：%s\n\n%s" % [item.display_name, bounds.x, bounds.y, JUDGEMENTS[visit.item.judgement], "\n".join(evidence_lines) if not evidence_lines.is_empty() else "尚未取得证据。卖家说法不能替代检查。"]
	for action in item.appraisal_actions:
		model.appraisal.buttons.append(_button(day, service, visit, "appraise", action.id, "%s · %d分钟" % [action.label, action.minutes]))
	if not item.provenance.is_empty():
		model.appraisal.body += "\n" + ProvenanceService.describe(visit.item)
		model.appraisal.buttons.append(_button(day, service, visit, "verify_source", "", "核对来源凭据与原物 · %d分钟" % int(item.provenance.check_minutes)))
	for key in JUDGEMENTS:
		model.appraisal.buttons.append(_button(day, service, visit, "judge", key, "记录判断：" + JUDGEMENTS[key]))
	if scenario == null:
		model.dialogue.body = customer.terms.introduction + "\n\n卖家口供未证实，不自动收窄估值。"
		for question in customer.questions:
			if question.id in visit.asked_question_ids: model.dialogue.body += "\n\n" + question.prompt + "\n" + question.answer
			model.dialogue.buttons.append(_button(day, service, visit, "question", question.id, "%s · %d分钟" % [question.prompt, question.minutes]))
	else:
		model.appraisal.images = TradeScenarioService.known_images(visit, scenario)
		if model.appraisal.images.any(func(row: Dictionary) -> bool: return not row.path.is_empty()): model.appraisal.body += "\n\n翻看正背面、复看细节不耗时；取证另计时间。"
		model.dialogue.body = String(visit.voice.get("introduction", scenario.introduction)) + "\n\n听来的话先记着，物品还须自己掌眼。无凭据地质疑，客人可能不悦。"
		for question in scenario.questions:
			if question.id in visit.asked_question_ids: model.dialogue.body += "\n\n" + question.prompt + "\n" + question.answer(visit)
			elif TradeScenarioService.question_available(day, visit, question):
				var suffix := ""
				if not question.pressure_clue.is_empty() and not TradeScenarioService.used(visit, scenario, question.pressure_clue): suffix = " · 议价一轮"
				model.dialogue.buttons.append(_button(day, service, visit, "question", question.id, "%s · %d分钟%s" % [question.prompt, question.minutes, suffix]))
	model.trade.body = "%s · 要价 %d\n剩余议价轮次 %d · %s\n报价 %d分钟 / 施压 %d分钟，各消耗一轮。\n收购前请自行判断证据与承受价。" % [item.display_name, visit.trade.asking_price, visit.trade.rounds_left, "显得不耐烦" if visit.trade.patience < customer.patience else "尚愿意交谈", customer.terms.quote_minutes, customer.terms.pressure_minutes]
	for clue_id in visit.item.revealed_clue_ids:
		var clue := item.find_clue(clue_id)
		var used: bool = clue_id in visit.trade.used_clue_ids or (scenario != null and TradeScenarioService.used(visit, scenario, clue_id))
		var label := clue.bargain_line if not clue.bargain_line.is_empty() else "拿这条线索试探价格"
		label += " · 已谈过" if used else " · %d分钟 · 议价一轮" % customer.terms.pressure_minutes
		var button := _button(day, service, visit, "pressure", clue_id, label)
		button.evidence = clue.text
		model.trade.buttons.append(button)
	if not customer.belittle.is_empty():
		var label := "“这东西没你说的那么值钱，再让些。”"
		label += " · 已试探" if visit.trade.belittle_used else " · %d分钟 · 议价一轮" % int(customer.belittle.minutes)
		model.trade.buttons.append(_button(day, service, visit, "belittle", "", label))
	if scenario != null and scenario.concession_amount > 0 and (scenario.concession_question in visit.asked_question_ids or ("mirror_verify" in visit.asked_question_ids and scenario.find_question("mirror_verify") != null)):
		model.trade.buttons.append(_button(day, service, visit, "concession", "", "请他为急用再让%d银元 · %d分钟 · 议价一轮" % [scenario.concession_amount, scenario.concession_minutes]))
		model.trade.body += "\n处境与品相分开谈；不赶路的客人可能反感催价。"
	model.trade.body += "\n客人最迟留到 %s。" % TimeController.clock_text(day.definition.opening_minute, visit.expires_at)
	model.trade.buttons.append(_button(day, service, visit, "reject", "", "拒绝收货 · %d分钟" % customer.terms.reject_minutes))
	model.trade.asking_price = visit.trade.asking_price
	model.trade.can_offer = service.reason(day, "offer", visit.visit_id, "", 1).is_empty()
	var terms := service.catalog.get_definition("pawn_terms", VarietyService.terms_for(visit, customer)) as PawnTermsDefinition
	if terms != null:
		model.trade.can_pawn = service.reason(day, "pawn", visit.visit_id, "", 1).is_empty()
		model.trade.pawn_asking = maxi(1, roundi(visit.trade.asking_price * terms.loan_ratio))
		model.trade.body += "\n活当要款 %d · 期限%d夜 · 赎金=本金+向上取整的%.0f%%息费。\n收购/活当共用剩余轮次与耐心。" % [model.trade.pawn_asking, terms.term_nights, terms.redemption_fee_ratio * 100]
		if EarlyRedemption.enabled(day.definition) and terms.id == FamiliarStories.TERMS: model.trade.body += "\n" + EarlyRedemption.AGREEMENT
	for feature in ["appraisal", "dialogue", "trade"]:
		model[feature].visit_id = visit.visit_id
		model[feature].body += "\n\n" + message
	CounterVisualReadModels.enrich(model, day, service, visit)
	for feature in ["appraisal", "dialogue", "trade"]: model[feature].visual.message = message
	if not visit.night_policy.is_empty():
		model.trade.night_policy = visit.night_policy
		if visit.night_policy == "one_quote":
			model.trade.buttons = model.trade.buttons.filter(func(b: Dictionary) -> bool: return b.command not in ["pressure", "belittle", "concession"])
			model.dialogue.buttons = model.dialogue.buttons.filter(func(b: Dictionary) -> bool: return not b.reason.contains("另行压价"))
	EarlyRedemption.enrich(model, day, service, visit)
	return model

static func _button(day: DayController, service: CounterService, visit: CustomerVisit, command: String, detail: String, label: String) -> Dictionary:
	var reason := service.reason(day, command, visit.visit_id, detail)
	return {"command": command, "detail": detail, "label": label, "enabled": reason.is_empty(), "reason": reason}
