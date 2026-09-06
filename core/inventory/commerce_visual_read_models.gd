class_name CommerceVisualReadModels
extends RefCounted

# Presentation facts only. Sale and pawn commands remain in CommerceReadModels.
static func enrich(model: Dictionary, day: DayController, service: CommerceService, message: String) -> void:
	var financial := FinancialSummary.build(day.state)
	var stock: Array = []
	for item in day.state.inventory_instances:
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		var bounds := AppraisalSystem.new().valuation(item, definition)
		var clues: Array = []
		for id in item.revealed_clue_ids: clues.append(definition.find_clue(id).text)
		var buyers: Dictionary = {}
		if item.ownership_state == "owned":
			for id in day.definition.buyer_ids:
				var buyer := service.catalog.get_definition("buyers", id) as BuyerDefinition
				buyers[id] = "%s–%s · 每夜最多收%d件" % [TimeController.clock_text(day.definition.opening_minute, buyer.window_start), TimeController.clock_text(day.definition.opening_minute, buyer.window_end), buyer.capacity_per_night]
				if id == "buyer_appointment": buyers[id] = OrdinarySamplePlan.notice(day.state)
				if service.sale_reason(day, item, buyer).is_empty() and not item.provenance.is_empty():
					var base := maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))
					buyers[id] += "\n基础报价 %d · 来源溢价 %d 银元" % [base, ProvenanceService.premium(item, buyer, base)]
		stock.append({"id": item.instance_id, "name": definition.display_name, "asset": definition.visual_asset_id,
			"state": item.ownership_state, "stamp": CommerceReadModels.STATES[item.ownership_state],
			"cost": item.acquisition_price, "cost_label": "放款" if item.acquisition_type == "pawn" else "成本", "estimate": "%d–%d" % [bounds.x, bounds.y],
			"provenance": ProvenanceService.known_text(item, definition), "clues": clues, "buyers": buyers, "night": item.acquired_night, "ghost": not definition.ghost_rule_id.is_empty()})
	var tickets: Array = []
	for index in day.state.pawn_tickets.size():
		var ticket := day.state.pawn_tickets[index]
		var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
		var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		var customer := service.catalog.get_definition("customers", ticket.customer_id) as CustomerDefinition
		var terms := service.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		var request := "约定到期日开铺后验票办理。无人来赎，夜末核票处置。"
		if ticket.status == "redeemed": request = "第%d夜收妥赎金，原物交还。" % ticket.closed_night
		elif ticket.status == "defaulted": request = "第%d夜销票留货，原物转为铺中现货。" % ticket.closed_night
		elif ticket.status == "transferred": request = "第%d夜折价转当，原物与当票一并交给同行。" % ticket.closed_night
		else:
			request += "\n赎回办理 %d 分钟。" % terms.redeem_minutes
			var visit := PawnReturnService.current(day.state)
			if not visit.is_empty() and visit.ticket_id == ticket.ticket_id: request = "原当户已持票到店，请到柜台办理。"

		tickets.append({"id": ticket.ticket_id, "number": "%03d" % (index + 1), "item": definition.display_name,
			"customer": VarietyService.name_for(ticket.person, customer), "principal": ticket.principal, "redemption": ticket.redemption_amount,
			"start": ticket.started_night, "due": ticket.due_night, "state": ticket.status,
			"stamp": CommerceReadModels.TICKETS[ticket.status], "request": request})
	var entries: Array = []
	for entry in day.state.ledger_entries:
		var subject := "铺面息费"
		var item := InventoryManager.new().find(day.state, entry.item_instance_id)
		if item != null: subject = (service.catalog.get_definition("items", item.definition_id) as ItemDefinition).display_name
		entries.append({"night": entry.night, "clock": TimeController.clock_text(day.definition.opening_minute, entry.minute),
			"kind": CommerceReadModels.KINDS[entry.kind], "item": subject, "amount": entry.amount, "balance": entry.balance,
			"profit": entry.realized_profit})
	model.inventory.visual = {"stock": stock, "financial": financial, "message": message}
	model.ledger.visual = {"cash": day.state.cash, "night": day.state.current_night_index, "financial": financial,
		"tickets": tickets, "entries": entries, "message": message,
		"debt": FeeService.describe(day.state, day.definition) if day.definition.fee_policy.enabled else "本局没有每日息费约定。",
		"archive": FeeService.archive_text(day.state) if not day.state.bankruptcy_archive.is_empty() else ""}
