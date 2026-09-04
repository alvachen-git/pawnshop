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
	var visit := customers.active(day.state)
	if day.state.phase != &"open" or visit == null or visit.visit_id != visit_id:
		return "当前顾客已离开或柜台未营业。"
	var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var cost := 0
	match command:
		"appraise":
			if not appraisal.can_perform(visit.item, item, detail, day.definition.tools): return "动作已做过、工具缺失或前置证据不足。"
			cost = item.find_action(detail).minutes
		"question":
			if customer.find_question(detail) == null or detail in visit.asked_question_ids: return "问题不存在或已经问过。"
			cost = customer.find_question(detail).minutes
		"judge":
			if detail not in ["unknown", "sound", "damaged", "fake"]: return "判断类型无效。"
			return ""
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
				cost = customer.terms.pressure_minutes
		"reject": cost = customer.terms.reject_minutes
		_: return "未知柜台操作。"
	if not TimeController.new().can_spend(day.state, day.definition, cost): return "剩余营业时间不足，不能开始该动作。"
	return ""

func execute(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	var error := reason(day, command, visit_id, detail, amount)
	if not error.is_empty(): return ActionResult.new(false, error)
	var visit := customers.active(day.state)
	var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	if command == "judge":
		visit.item.judgement = detail
		return ActionResult.new(true, "已记录你的判断；判断本身不会揭露真相或改变物品价值。")
	var cost := 0
	match command:
		"appraise": cost = item.find_action(detail).minutes
		"question": cost = customer.find_question(detail).minutes
		"offer", "pawn": cost = customer.terms.quote_minutes
		"pressure": cost = customer.terms.pressure_minutes
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
			message = "卖家口供（未证实）：" + customer.find_question(detail).answer
		"reject":
			customers.finish(day.state, visit, "rejected")
			message = "拒绝收货，送客消耗 %d 分钟。" % cost
		"pressure":
			var valid := trades.pressure(visit.trade, customer, item.find_clue(detail))
			message = "对方认可了瑕疵，降低要价。" if valid else "这条证据不能证明瑕疵，对方不满；已消耗轮次和耐心。"
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
