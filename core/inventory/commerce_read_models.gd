class_name CommerceReadModels
extends RefCounted

const STATES := {"lost": "湿灰毁损", "owned": "现货", "pledged": "在当（不可售）", "sold": "已售", "redeemed": "已赎回", "transferred": "已转当"}
const TICKETS := {"active": "在当", "redeemed": "已赎回", "transferred": "已转当", "defaulted": "已绝当转现货"}
const KINDS := {"inventory_loss": "损货核销（无现金支出）", "acquisition": "收购", "pawn_loan": "活当放款", "sale": "出售", "redemption": "赎金", "extension": "续当费", "daily_fees": "息费付款", "pawn_transfer": "转当收入", "provenance_inquiry": "来源调查费", "preparation": "准备支出"}

static func build(day: DayController, service: CommerceService, message: String) -> Dictionary:
	var financial := FinancialSummary.build(day.state)
	var inventory := {"body": "库存 %d 件现货 · 成本占款 %d · 在当本金 %d\n估值不是现金。只可出售给当前买家；在当物品不可售。\n" % [financial.inventory_count, financial.inventory_cost, financial.pawn_principal], "buttons": []}
	if not day.state.buyer_appointment.is_empty(): inventory.body += OrdinarySamplePlan.notice(day.state) + "\n"
	for item in day.state.inventory_instances:
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		inventory.body += "\n%s · %s · 成本 %d\n" % [definition.display_name, STATES[item.ownership_state], item.acquisition_price]
		if item.ownership_state != "owned": continue
		if not definition.provenance.is_empty() and not item.provenance.investigated and item.provenance.status not in ["verified", "mismatch"]:
			inventory.buttons.append(_button("inquire", item.instance_id, "", "委托来源调查 · %d银元 / %d分钟" % [definition.provenance.inquiry_fee, definition.provenance.inquiry_minutes], ProvenanceService.inquiry_reason(day, item, definition)))
		var bounds := AppraisalSystem.new().valuation(item, definition)
		inventory.body += "已知估值 %d–%d（未出售，盈亏未实现）\n" % [bounds.x, bounds.y]
		for buyer_id in day.definition.buyer_ids:
			var buyer := service.catalog.get_definition("buyers", buyer_id) as BuyerDefinition
			var reason := service.sale_reason(day, item, buyer)
			var window := "%s–%s" % [TimeController.clock_text(day.definition.opening_minute, buyer.window_start), TimeController.clock_text(day.definition.opening_minute, buyer.window_end)]
			if buyer.id == PreparationService.BUYER and not PreparationService.requirements_known(day.state): window = "第六夜，时段待打听"
			var label := "%s → %s" % [definition.display_name, buyer.display_name]
			if reason.is_empty(): label += "：%d · %d分钟" % [service.quote(item, buyer), buyer.action_minutes]
			else: label += "：不可用"
			inventory.body += "%s（%s，%s）：%s\n" % [buyer.display_name, window, "不限量" if buyer.capacity_per_night == 0 else "每夜%d件" % buyer.capacity_per_night, "可成交" if reason.is_empty() else reason]
			inventory.buttons.append(_button("sell", item.instance_id, buyer_id, label, reason))
	var ledger := {"body": "现银 %d · 本夜已实现盈亏 %+d\n收购支出/活当本金不是已实现亏损。\n" % [day.state.cash, financial.realized_profit], "buttons": []}
	if day.definition.fee_policy.enabled:
		ledger.body = FeeService.describe(day.state, day.definition) + "\n现银 %d · 本夜交易毛利 %+d\n当夜利息 %d · 铺面开支 %d · 经营净收益 %+d\n本夜实际付息费 %d\n" % [day.state.cash, financial.realized_profit, financial.interest_expense, financial.shop_expense, financial.operating_profit, financial.fees_paid]
	if financial.has("preparation_expense"): ledger.body += "本夜准备支出 %d 大洋（经营费用）\n" % financial.preparation_expense
	if financial.has("provenance_expense"): ledger.body += "本夜来源调查费 %d 银元（经营费用）\n" % financial.provenance_expense
	for entry in day.state.ledger_entries:
		ledger.body += "\n第%d夜 %s · %s %+d · 余额 %d · 盈亏 %+d" % [entry.night, TimeController.clock_text(day.definition.opening_minute, entry.minute), KINDS[entry.kind], entry.amount, entry.balance, entry.realized_profit]
	ledger.body += "\n\n当票（到期无人来赎，夜末核票处置）\n"
	for ticket in day.state.pawn_tickets:
		var terms := service.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		var customer := service.catalog.get_definition("customers", ticket.customer_id) as CustomerDefinition
		var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		ledger.body += "\n%s · %s（第%d夜入当）\n本金 %d · 赎金 %d · 第%d夜到期 · %s\n" % [VarietyService.name_for(ticket.person, customer), definition.display_name, ticket.started_night, ticket.principal, ticket.redemption_amount, ticket.due_night, TICKETS[ticket.status]]
		if ticket.status != "active": continue
		ledger.body += "约定到期日开铺后验票办理；无人来赎，夜末核票处置。\n"
		var visit := PawnReturnService.current(day.state)
		if not visit.is_empty() and visit.ticket_id == ticket.ticket_id:
			ledger.buttons.append(_button("return_counter", ticket.ticket_id, "", "到柜台接待原当户", ""))

	inventory.body += "\n" + message
	if day.definition.fee_policy.enabled: ledger.body += FeeService.archive_text(day.state)
	ledger.body += "\n" + message
	var model := {"inventory": inventory, "ledger": ledger}
	var flow := CashFlowReadModel.build(day.state, day.definition)
	if not flow.is_empty():
		model.inventory.cash_flow = flow
		model.ledger.cash_flow = flow
	CommerceVisualReadModels.enrich(model, day, service, message)
	if day.definition.batch_selling: model.inventory.sales = BatchSaleReadModel.build(day, service)
	return model

static func _button(command: String, target: String, detail: String, label: String, reason: String) -> Dictionary:
	return {"command": command, "target_id": target, "detail": detail, "label": label, "reason": reason, "enabled": reason.is_empty()}
