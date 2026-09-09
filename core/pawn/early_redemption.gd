class_name EarlyRedemption
extends RefCounted

const AGREEMENT := "三夜为期，提前取赎须与掌柜商议；仍按票面赎金结清。"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("early_redemption", false)

static func ticket_data(data: Dictionary, story: Dictionary) -> Dictionary:
	for ticket in data.get("pawn_tickets", []):
		if ticket.get("source_visit_id") == story.get("first", {}).get("visit_id") and ticket.get("terms_id") == FamiliarStories.TERMS: return ticket
	return {}

static func qualifies(data: Dictionary, story: Dictionary) -> bool:
	var ticket := ticket_data(data, story)
	return data.get("familiar_plan", {}).get("early_redemption", false) and story.get("id") == "seamstress" and not ticket.is_empty() and int(story.funds) >= int(ticket.redemption_amount)

static func is_visit(visit: CustomerVisit) -> bool:
	return visit != null and visit.voice.get("early_redemption", false)

static func recorded(ticket: Dictionary, data: Dictionary) -> Dictionary:
	var story := FamiliarStories.story_for(data, "seamstress")
	if not qualifies(data, story) or ticket.get("source_visit_id") != story.first.visit_id: return {}
	for row in data.get("scenario_history", []) + data.get("bargaining_history", []):
		if row.get("visit_id") == story.follow.visit_id and row.get("command") == "early_redeem" and row.get("ok") == true and int(row.night) == int(story.follow_night):
			return row if CounterSaveCodec._integers(row, ["start", "minute", "amount"]) else {}
	return {}

static func ticket_for(state: RunState) -> PawnTicket:
	var story := FamiliarStories.story_for(FamiliarStories.history_data(state), "seamstress")
	for ticket in state.pawn_tickets:
		if ticket.source_visit_id == story.get("first", {}).get("visit_id"): return ticket
	return null

static func reason(day: DayController, visit: CustomerVisit, command: String, detail: String, amount: int) -> String:
	if not enabled(day.definition) or not is_visit(visit): return "眼下没有提前取赎的请求。"
	if command not in ["early_redeem", "defer_redeem"]: return "原当户来商议提前取赎，请先办理或约定按期再来。"
	if not detail.is_empty() or amount != 0: return "提前取赎按原票结算，不能改填金额。"
	var ticket := ticket_for(day.state)
	if ticket == null or ticket.status != "active" or ticket.person != visit.person or day.state.current_night_index >= ticket.due_night: return "原票已办结或不在提前取赎期间。"
	var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
	if item == null or item.ownership_state != "pledged": return "原当物不在保管状态。"
	if command == "early_redeem" and not TimeController.new().can_spend(day.state, day.definition, 10): return "剩余营业时间不足，不能开始办理。"
	return ""

static func execute(day: DayController, service: CounterService, visit: CustomerVisit, command: String) -> ActionResult:
	var ticket := ticket_for(day.state)
	if command == "early_redeem": day.spend_action(10)
	service.customers.update(day.state)
	if visit.status != "active": return ActionResult.new(false, "办理尚未完成，当户已等不及离开。原票仍有效，按原日期再来。")
	if command == "defer_redeem":
		service.customers.finish(day.state, visit, "redemption_deferred")
		service.customers.update(day.state)
		return ActionResult.new(true, "姜素云收好当票：‘那就照票上的日子来，钱我留着。’\n仍按第%d夜办理，赎金%d银元，原票未变。" % [ticket.due_night, ticket.redemption_amount])
	var item := service.inventory.find(day.state, ticket.item_instance_id)
	service.economy.commit(day.state, ticket.redemption_amount, item.instance_id, "redeem/" + ticket.ticket_id, "redemption", ticket.redemption_amount - ticket.principal)
	ticket.status = "redeemed"
	ticket.closed_night = day.state.current_night_index
	ticket.closed_minute = day.state.game_minutes
	item.ownership_state = "redeemed"
	service.customers.finish(day.state, visit, "redeemed_early")
	service.customers.update(day.state)
	return ActionResult.new(true, "姜素云接过银簪，在帕子上轻轻擦了擦：‘这回心里踏实了。’\n收取赎金%d银元，原票已结，银簪交还原主。" % ticket.redemption_amount)

# The counter replay owns private copies of the original collateral and ticket.
static func prepare_replay(replay: RunState, validated: RunState, visit: CustomerVisit, data: Dictionary) -> void:
	if not is_visit(visit): return
	replay.familiar_plan = validated.familiar_plan.duplicate(true)
	for original in validated.pawn_tickets:
		if original.source_visit_id != FamiliarStories.story_for(data, "seamstress").first.visit_id: continue
		var ticket := PawnTicket.new()
		for key in original.to_data(): ticket.set(key, original.to_data()[key])
		ticket.status = "active"; ticket.closed_night = 0; ticket.closed_minute = -1
		replay.pawn_tickets.append(ticket)
		var original_item := InventoryManager.new().find(validated, ticket.item_instance_id)
		var item := ItemInstance.new()
		for key in original_item.to_data(): item.set(key, original_item.to_data()[key])
		item.ownership_state = "pledged"
		replay.inventory_instances.append(item)

static func enrich(model: Dictionary, day: DayController, service: CounterService, visit: CustomerVisit) -> void:
	if not is_visit(visit): return
	var ticket := ticket_for(day.state)
	if ticket == null: return
	var text := "%s\n\n当票%03d · 银簪\n放款%d银元 · 票面赎金%d银元 · 第%d夜到期\n%s" % [visit.voice.introduction, day.state.pawn_tickets.find(ticket) + 1, ticket.principal, ticket.redemption_amount, ticket.due_night, AGREEMENT]
	model.context_actions.customer = [{"id": "dialogue", "label": "看当票", "enabled": true}, {"id": "trade", "label": "商议提前取赎", "enabled": true}]
	model.context_actions.item = []
	for feature in ["appraisal", "dialogue", "trade"]:
		model[feature].body = text
		model[feature].buttons = []
		model[feature].erase("visual")
	model.trade.pawn_return = true
	model.trade.can_offer = false; model.trade.can_pawn = false
	for action in [["early_redeem", "验票收赎，交还银簪 · 10分钟"], ["defer_redeem", "仍按票上的日子来 · 不耗时"]]:
		var blocked := service.reason(day, action[0], visit.visit_id)
		model.trade.buttons.append({"command": action[0], "detail": "", "label": action[1], "enabled": blocked.is_empty(), "reason": blocked})
	model.visual.introduction = visit.voice.introduction
	model.visual.attitude = "持原票商议取赎"
	model.visual.speech = []
	model.visual.clues = []
	model.visual.item_status = "银簪\n原物仍在铺内保管\n票面赎金%d银元" % ticket.redemption_amount
