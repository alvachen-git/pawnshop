class_name CommerceReadModels
extends RefCounted

const STATES := {"owned": "现货", "pledged": "在当（不可售）", "sold": "已售", "redeemed": "已赎回"}
const TICKETS := {"active": "在当", "redeemed": "已赎回", "defaulted": "已绝当转现货"}
const KINDS := {"acquisition": "收购", "pawn_loan": "活当放款", "sale": "出售", "redemption": "赎金", "extension": "续当费", "daily_fees": "息费付款"}

static func build(day: DayController, service: CommerceService, message: String) -> Dictionary:
	var financial := FinancialSummary.build(day.state)
	var inventory := {"body": "库存 %d 件现货 · 成本占款 %d · 在当本金 %d\n估值不是现金。只可出售给当前买家；在当物品不可售。\n" % [financial.inventory_count, financial.inventory_cost, financial.pawn_principal], "buttons": []}
	for item in day.state.inventory_instances:
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		inventory.body += "\n%s · %s · 成本 %d\n" % [definition.display_name, STATES[item.ownership_state], item.acquisition_price]
		if item.ownership_state != "owned": continue
		var bounds := AppraisalSystem.new().valuation(item, definition)
		inventory.body += "已知估值 %d–%d（未出售，盈亏未实现）\n" % [bounds.x, bounds.y]
		for buyer_id in day.definition.buyer_ids:
			var buyer := service.catalog.get_definition("buyers", buyer_id) as BuyerDefinition
			var reason := service.sale_reason(day, item, buyer)
			var window := "%s–%s" % [TimeController.clock_text(day.definition.opening_minute, buyer.window_start), TimeController.clock_text(day.definition.opening_minute, buyer.window_end)]
			var label := "%s → %s" % [definition.display_name, buyer.display_name]
			if reason.is_empty(): label += "：%d · %d分钟" % [service.quote(item, buyer), buyer.action_minutes]
			else: label += "：不可用"
			inventory.body += "%s（%s，每夜%d件）：%s\n" % [buyer.display_name, window, buyer.capacity_per_night, "可成交" if reason.is_empty() else reason]
			inventory.buttons.append(_button("sell", item.instance_id, buyer_id, label, reason))
	var ledger := {"body": "现银 %d · 本夜已实现盈亏 %+d\n收购支出/活当本金不是已实现亏损。\n" % [day.state.cash, financial.realized_profit], "buttons": []}
	if day.definition.fee_policy.enabled:
		ledger.body = FeeService.describe(day.state, day.definition) + "\n现银 %d · 本夜交易毛利 %+d\n当夜利息 %d · 铺面开支 %d · 经营净收益 %+d\n本夜实际付息费 %d\n" % [day.state.cash, financial.realized_profit, financial.interest_expense, financial.shop_expense, financial.operating_profit, financial.fees_paid]
	for entry in day.state.ledger_entries:
		ledger.body += "\n第%d夜 %s · %s %+d · 余额 %d · 盈亏 %+d" % [entry.night, TimeController.clock_text(day.definition.opening_minute, entry.minute), KINDS[entry.kind], entry.amount, entry.balance, entry.realized_profit]
	ledger.body += "\n\n当票（到期未赎，转为铺中现货）\n"
	for ticket in day.state.pawn_tickets:
		var terms := service.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		var customer := service.catalog.get_definition("customers", ticket.customer_id) as CustomerDefinition
		var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		ledger.body += "\n%s · %s（第%d夜入当）\n本金 %d · 赎金 %d · 第%d夜到期 · %s\n" % [customer.terms.display_name, definition.display_name, ticket.started_night, ticket.principal, ticket.redemption_amount, ticket.due_night, TICKETS[ticket.status]]
		if ticket.status != "active": continue
		var command := service.pawns.request_kind(ticket, terms)
		if command.is_empty():
			ledger.body += "暂无当户返店请求；到期夜末未赎则转现货。\n"
			continue
		var reason := service.pawns.reason(day, ticket, terms, command)
		ledger.body += "当户约定第%d夜 %s–%s 办理%s。\n" % [ticket.due_night, TimeController.clock_text(day.definition.opening_minute, terms.window_start), TimeController.clock_text(day.definition.opening_minute, terms.window_end), "赎回" if command == "redeem" else "续当"]
		var label := "收赎金 %d 并交还原物" % ticket.redemption_amount if command == "redeem" else "同意当户续当申请"
		ledger.buttons.append(_button(command, ticket.ticket_id, "", label, reason))
	inventory.body += "\n" + message
	if day.definition.fee_policy.enabled: ledger.body += FeeService.archive_text(day.state)
	ledger.body += "\n" + message
	var model := {"inventory": inventory, "ledger": ledger}
	CommerceVisualReadModels.enrich(model, day, service, message)
	return model

static func _button(command: String, target: String, detail: String, label: String, reason: String) -> Dictionary:
	return {"command": command, "target_id": target, "detail": detail, "label": label, "reason": reason, "enabled": reason.is_empty()}
