class_name CounterService
extends RefCounted

var catalog: ContentCatalog
var customers := CustomerManager.new()
var appraisal := AppraisalSystem.new()
var trades := TradeController.new()
var inventory := InventoryManager.new()
var economy := EconomyManager.new()

func _init(content: ContentCatalog) -> void:
	catalog = content

func reason(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> String:
	if not PawnReturnService.current(day.state).is_empty(): return "请先接待持票回访的原当户。"
	var visit := customers.active(day.state)
	if day.state.phase != &"open" or visit == null or visit.visit_id != visit_id:
		return "当前顾客已离开或柜台未营业。"
	var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var scenario := TradeScenarioService.for_visit(day.definition, visit)
	var cost := 0
	match command:
		"appraise":
			if not appraisal.can_perform(visit.item, item, detail, day.definition.tools): return "动作已做过、工具缺失或前置证据不足。"
			cost = item.find_action(detail).minutes
		"question":
			if scenario != null:
				var question := scenario.find_question(detail)
				if question == null or detail in visit.asked_question_ids: return "这话已经问过，或不适合眼前这件东西。"
				if not TradeScenarioService.prerequisites(visit, question): return "尚未听到相关说法，或没有对应的实物证据。"
				if not question.pressure_clue.is_empty() and not TradeScenarioService.used(visit, scenario, question.pressure_clue) and (visit.trade.rounds_left <= 0 or visit.trade.patience <= 0): return "客人已经不肯再谈价。"
				cost = question.minutes
			else:
				if customer.find_question(detail) == null or detail in visit.asked_question_ids: return "问题不存在或已经问过。"
				cost = customer.find_question(detail).minutes
		"concession":
			if scenario == null or scenario.concession_amount <= 0: return "眼下没有这桩让价可谈。"
			if visit.concession_used: return "这份让价已经谈过。"
			if scenario.concession_question not in visit.asked_question_ids: return "先问清客人何时动身。"
			if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已经不肯再谈价。"
			cost = scenario.concession_minutes
		"judge":
			if detail not in ["unknown", "sound", "damaged", "fake"]: return "判断类型无效。"
			return ""
		"belittle":
			if customer.belittle.is_empty(): return "这位客人不接受这样的试探。"
			if visit.trade.belittle_used: return "已试探过，不能再说一遍。"
			if not detail.is_empty() or amount != 0: return "试探不接受报价或证据。"
			if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "本次议价已经结束。"
			cost = int(customer.belittle.minutes)
		"offer", "pawn", "pressure":
			if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "本次议价已经结束。"
			if command in ["offer", "pawn"]:
				if command == "pawn" and ("pawn" not in customer.transaction_modes or not catalog.has_definition("pawn_terms", customer.pawn_terms_id)): return "此顾客不接受活当。"
				if amount <= 0 or amount > 1000000: return "报价必须是正整数。"
				if not economy.can_pay(day.state, amount, ("loan/" if command == "pawn" else "purchase/") + visit_id): return "现金不足或交易已处理，未提交报价。"
				if inventory.contains(day.state, visit.item.instance_id): return "物品已经入库。"
				cost = customer.terms.quote_minutes
			else:
				if detail not in visit.item.revealed_clue_ids or detail in visit.trade.used_clue_ids: return "证据未获得或已经使用，不能重复试探。"
				if scenario != null and TradeScenarioService.used(visit, scenario, detail): return "这处毛病已经折进价里。"
				cost = customer.terms.pressure_minutes
		"reject": cost = customer.terms.reject_minutes
		_: return "未知柜台操作。"
	if not TimeController.new().can_spend(day.state, day.definition, cost): return "剩余营业时间不足，不能开始该动作。"
	return ""

func execute(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	var error := reason(day, command, visit_id, detail, amount)
	if not error.is_empty(): return ActionResult.new(false, error)
	var visit := customers.active(day.state)
	var start := day.state.game_minutes
	var result := _execute(day, command, visit_id, detail, amount)
	if not visit.scenario_id.is_empty() or not (catalog.get_definition("customers", visit.customer_id) as CustomerDefinition).belittle.is_empty(): TradeScenarioService.record(day, visit, command, detail, amount, start, result)
	return result

func _execute(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	var error := reason(day, command, visit_id, detail, amount)
	if not error.is_empty(): return ActionResult.new(false, error)
	var visit := customers.active(day.state)
	var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	if command == "judge":
		visit.item.judgement = detail
		return ActionResult.new(true, "已记录你的判断；判断本身不会揭露真相或改变物品价值。")
	var scenario := TradeScenarioService.for_visit(day.definition, visit)
	var cost := 0
	match command:
		"appraise": cost = item.find_action(detail).minutes
		"question": cost = scenario.find_question(detail).minutes if scenario != null else customer.find_question(detail).minutes
		"concession": cost = scenario.concession_minutes
		"offer", "pawn": cost = customer.terms.quote_minutes
		"pressure": cost = customer.terms.pressure_minutes
		"belittle": cost = int(customer.belittle.minutes)
		"reject": cost = customer.terms.reject_minutes
	day.spend_action(cost)
	customers.update(day.state)
	# An action taking us to the customer's deadline or sealing time has no late effect.
	if visit.status != "active": return ActionResult.new(false, "消耗 %d 分钟，但顾客在完成前已离场；未取得证据或成交。" % cost)
	var message := ""
	match command:
		"appraise": message = appraisal.perform(visit.item, item, detail)
		"question":
			visit.asked_question_ids.append(detail)
			if scenario != null:
				var question := scenario.find_question(detail)
				message = question.answer(visit)
				visit.trade.patience -= question.patience_cost
				if not question.pressure_clue.is_empty():
					if not TradeScenarioService.used(visit, scenario, question.pressure_clue): trades.pressure(visit.trade, customer, item.find_clue(question.pressure_clue))
					else: message += "\n这处毛病已经折进价里，价钱没有再变。"
			else:
				message = "卖家口供（未证实）：" + customer.find_question(detail).answer
		"concession": message = TradeScenarioService.concede(visit, scenario)
		"reject":
			customers.finish(day.state, visit, "rejected")
			message = "拒绝收货，送客消耗 %d 分钟。" % cost
		"belittle": message = BelittleService.apply(visit, customer)
		"pressure":
			var before := visit.trade.asking_price
			var clue := item.find_clue(detail)
			var valid := trades.pressure(visit.trade, customer, clue)
			message = clue.bargain_response
			if message.is_empty(): message = "他仔细看了那处：“这毛病确实在，价钱可以再谈。”" if valid else "他摇摇头：“这只能说明东西的来路和样子，算不上毛病。”"
			message += "\n要价 %d → %d 银元。" % [before, visit.trade.asking_price]
			if not valid: message += " 他显得不耐烦了。"
		"offer", "pawn":
			var terms := catalog.get_definition("pawn_terms", customer.pawn_terms_id) as PawnTermsDefinition
			var threshold := maxi(1, roundi(visit.trade.reserve_price * terms.loan_ratio)) if command == "pawn" else -1
			if trades.quote(visit.trade, customer, amount, threshold):
				if command == "pawn":
					PawnController.new().issue(day.state, visit, terms, amount)
					customers.finish(day.state, visit, "pawned")
					customers.update(day.state)
					return ActionResult.new(true, "活当放款 %d；当票已生成，在当物品不可出售。" % amount)
				# All guards have passed. These synchronous, non-failing writes emit no signals mid-commit.
				economy.pay_acquisition(day.state, amount, visit.item.instance_id, "purchase/" + visit_id)
				inventory.acquire(day.state, visit.item, visit_id, amount)
				customers.finish(day.state, visit, "bought")
				message = "成交：支付 %d，物品已入库。估值不等于现金，尚未出售。" % amount
			else:
				message = "对方拒绝了报价，提出新的要价。"
	if visit.status == "active":
		if visit.trade.patience <= 0:
			customers.finish(day.state, visit, "patience_exhausted")
			message += " 耐心耗尽，顾客离场。"
		elif visit.trade.rounds_left <= 0:
			customers.finish(day.state, visit, "rounds_exhausted")
			message += " 议价轮次用尽，顾客离场。"
	customers.update(day.state)
	return ActionResult.new(true, message)
