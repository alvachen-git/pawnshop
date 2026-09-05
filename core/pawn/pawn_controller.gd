class_name PawnController
extends RefCounted

func issue(state: RunState, visit: CustomerVisit, terms: PawnTermsDefinition, amount: int) -> void:
	var ticket := PawnTicket.new()
	ticket.ticket_id = "ticket/" + visit.visit_id
	ticket.terms_id = terms.id
	ticket.customer_id = visit.customer_id
	ticket.item_instance_id = visit.item.instance_id
	ticket.source_visit_id = visit.visit_id
	ticket.principal = amount
	ticket.started_night = state.current_night_index
	ticket.due_night = ticket.started_night + terms.term_nights
	ticket.redemption_amount = amount + ceili(amount * terms.redemption_fee_ratio)
	EconomyManager.new().commit(state, -amount, visit.item.instance_id, "loan/" + visit.visit_id, "pawn_loan")
	InventoryManager.new().acquire(state, visit.item, visit.visit_id, amount)
	visit.item.acquisition_type = "pawn"
	visit.item.ownership_state = "pledged"
	state.pawn_tickets.append(ticket)

func find(state: RunState, id: String) -> PawnTicket:
	for ticket in state.pawn_tickets:
		if ticket.ticket_id == id: return ticket
	return null

func request_kind(ticket: PawnTicket, terms: PawnTermsDefinition) -> String:
	if terms.return_mode == "absent": return ""
	if terms.return_mode == "extend_once" and ticket.extensions.is_empty(): return "extend"
	return "redeem"

func reason(day: DayController, ticket: PawnTicket, terms: PawnTermsDefinition, command: String) -> String:
	if ticket == null or terms == null: return "当票不存在。"
	if day.state.phase != &"open" or ticket.status != "active": return "当票不在营业可处理状态。"
	var visit := PawnReturnService.current(day.state)
	if visit.is_empty() or visit.ticket_id != ticket.ticket_id or visit.customer_id != ticket.customer_id or visit.item_instance_id != ticket.item_instance_id or visit.command != command or ticket.due_night != day.state.current_night_index: return "请先接待柜前持票的原当户。"
	if command != request_kind(ticket, terms) or command not in ["redeem", "extend"]: return "没有此类当户请求；不能凭空收取赎金。"
	var cost := terms.redeem_minutes if command == "redeem" else terms.extend_minutes
	if not TimeController.new().can_spend(day.state, day.definition, cost): return "时间不足。"
	return ""

func execute(day: DayController, ticket: PawnTicket, terms: PawnTermsDefinition, command: String) -> ActionResult:
	var error := reason(day, ticket, terms, command)
	if not error.is_empty(): return ActionResult.new(false, error)
	var visit := PawnReturnService.current(day.state)
	visit.start = day.state.game_minutes
	day.spend_action(terms.redeem_minutes if command == "redeem" else terms.extend_minutes)
	visit.minute = day.state.game_minutes
	visit.status = "completed"
	var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
	if command == "redeem":
		EconomyManager.new().commit(day.state, ticket.redemption_amount, item.instance_id, "redeem/" + ticket.ticket_id, "redemption", ticket.redemption_amount - ticket.principal)
		ticket.status = "redeemed"
		ticket.closed_night = day.state.current_night_index
		ticket.closed_minute = day.state.game_minutes
		item.ownership_state = "redeemed"
		return ActionResult.new(true, "收取赎金 %d，原物已交还当户。" % ticket.redemption_amount)
	var fee := ceili(ticket.principal * terms.extension_fee_ratio)
	EconomyManager.new().commit(day.state, fee, item.instance_id, "extend/" + ticket.ticket_id, "extension", fee)
	ticket.extensions.append({"night": day.state.current_night_index, "minute": day.state.game_minutes, "fee": fee, "previous_due": ticket.due_night, "new_due": ticket.due_night + terms.extension_nights})
	ticket.due_night += terms.extension_nights
	return ActionResult.new(true, "已收续当费 %d，延至第%d夜到期。" % [fee, ticket.due_night])

func maturities(state: RunState) -> Array[PawnTicket]:
	var result: Array[PawnTicket] = []
	for ticket in state.pawn_tickets:
		if ticket.status == "active" and ticket.due_night <= state.current_night_index: result.append(ticket)
	return result

func transfer_quote(ticket: PawnTicket, terms: PawnTermsDefinition) -> int:
	return maxi(1, floori(ticket.principal * terms.transfer_ratio))

func disposal_reason(state: RunState, catalog: ContentCatalog, choices: Dictionary) -> String:
	if state.phase != &"night_resolution": return "封铺后才可核销到期当票。"
	var due := maturities(state)
	if choices.size() != due.size(): return "请逐张选好留货或转当，再合账。"
	for ticket in due:
		var terms := catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		if terms.return_mode != "absent": return "持票到店的当户尚未办结，不能绝当。"
		if choices.get(ticket.ticket_id, "") not in ["keep", "transfer"]: return "请逐张选好留货或转当，再合账。"
	return ""

func resolve_maturities(state: RunState, night_minutes: int, catalog: ContentCatalog, choices: Dictionary) -> void:
	for ticket in maturities(state):
		var item := InventoryManager.new().find(state, ticket.item_instance_id)
		ticket.closed_night = state.current_night_index
		ticket.closed_minute = night_minutes
		if choices[ticket.ticket_id] == "keep":
			ticket.status = "defaulted"
			item.ownership_state = "owned"
		else:
			var terms := catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
			var amount := transfer_quote(ticket, terms)
			ticket.status = "transferred"
			item.ownership_state = "transferred"
			EconomyManager.new().commit(state, amount, item.instance_id, "transfer/" + ticket.ticket_id, "pawn_transfer", amount - ticket.principal)
