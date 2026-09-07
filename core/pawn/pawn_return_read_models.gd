class_name PawnReturnReadModels
extends RefCounted

static func enrich(model: Dictionary, day: DayController, service: CommerceService) -> void:
	if service == null: return
	var visit := PawnReturnService.current(day.state)
	if visit.is_empty(): return
	var ticket := service.pawns.find(day.state, visit.ticket_id)
	var customer := service.catalog.get_definition("customers", ticket.customer_id) as CustomerDefinition
	var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
	var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
	var terms := service.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
	var number := "%03d" % (day.state.pawn_tickets.find(ticket) + 1)
	var speech := "掌柜的，当票带来了。劳烦验一验，我来赎回原物。" if visit.command == "redeem" else "掌柜的，钱还没凑齐。先付息费，再续一夜可好？"
	if not ticket.person.is_empty(): speech = customer.persona.get("redeem" if visit.command == "redeem" else "extend", speech)
	if SevenNightPlan.enabled(day.definition): speech = "掌柜，先前第%d夜押下的%s，我带原票来赎了。说好三夜，如今钱凑齐了。" % [ticket.started_night, definition.display_name]
	var description := "当票 %s · %s\n当户：%s\n本金 %d 银元 · 约定赎金 %d 银元\n办理 %d 分钟。原物仍在铺内，验票后交还。" % [number, definition.display_name, VarietyService.name_for(ticket.person, customer), ticket.principal, ticket.redemption_amount, visit.minutes]
	if visit.command == "extend": description = "当票 %s · %s\n当户：%s\n续当费 %d 银元 · 延长 %d 夜\n办理 %d 分钟，原物继续留铺。" % [number, definition.display_name, VarietyService.name_for(ticket.person, customer), ceili(ticket.principal * terms.extension_fee_ratio), terms.extension_nights, visit.minutes]
	var clues: Array[Dictionary] = []
	for id in item.revealed_clue_ids: clues.append({"id": id, "text": definition.find_clue(id).text})
	var bounds := AppraisalSystem.new().valuation(item, definition)
	model.active_id = visit.id
	model.customer = VarietyService.name_for(ticket.person, customer) + "\n持票回访"
	model.item = definition.display_name
	model.queue = "原当户优先接待 · 核妥当票后再迎新客"
	model.context_actions = {"customer": [{"id": "dialogue", "label": "看当票", "enabled": true}, {"id": "trade", "label": "办理赎当" if visit.command == "redeem" else "办理续当", "enabled": true}], "item": [{"id": "appraisal", "label": "查看原物", "enabled": true}]}
	model.visual = {"pawn_return": true, "customer_name": VarietyService.name_for(ticket.person, customer), "portrait_asset": ticket.person.get("portrait", customer.portrait_asset_id),
		"item_name": definition.display_name, "item_asset": definition.visual_asset_id, "item_description": definition.description,
		"introduction": speech, "speech": [], "clues": clues, "estimate": "%d–%d" % [bounds.x, bounds.y],
		"attitude": "持票回访", "deadline": "验票办结", "judgement": CounterReadModels.JUDGEMENTS[item.judgement]}
	for feature in ["appraisal", "dialogue", "trade"]:
		model[feature].visit_id = visit.id
		model[feature].body = description if feature != "dialogue" else speech + "\n\n" + description
		model[feature].buttons = []
		model[feature].erase("visual")
	model.trade.pawn_return = true
	model.trade.can_offer = false
	model.trade.can_pawn = false
	var reason := service.pawns.reason(day, ticket, terms, visit.command)
	model.trade.buttons = [{"command": visit.command, "detail": "", "label": "验票收赎，交还原物" if visit.command == "redeem" else "验票收息，续当留物", "enabled": reason.is_empty(), "reason": reason}]
