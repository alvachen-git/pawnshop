class_name GhostGuests
extends RefCounted

const CLOSED := "ghost_closed_bundle"
const SWAP := "ghost_swap_guest"

static func target_ticket(state: RunState) -> PawnTicket:
	if state.ghost_visits.is_empty(): return null
	return PawnController.new().find(state, state.ghost_visits[0].ticket_id)

static func eligible(state: RunState) -> Array[PawnTicket]:
	var result: Array[PawnTicket] = []
	for ticket in state.pawn_tickets:
		var item := InventoryManager.new().find(state, ticket.item_instance_id)
		if ticket.status != "active" or not ticket.replacement_instance_id.is_empty() or item == null or item.ownership_state != "pledged": continue
		var definition := state.ghost_catalog.get_definition("items", item.definition_id) as ItemDefinition
		if definition.item_type == "normal": result.append(ticket)
	result.sort_custom(func(a: PawnTicket, b: PawnTicket) -> bool: return a.ticket_id < b.ticket_id)
	return result

# Called only when a waiting visitor takes the counter, never by a read model.
static func arrive(state: RunState, visit: CustomerVisit) -> void:
	if state.ghost_version != 1 or state.ghost_catalog == null: return
	if not visit.purpose.is_empty() or not visit.night_policy.is_empty(): return
	if state.person_deaths.any(func(row: Dictionary) -> bool: return row.person_id == visit.person.get("id", "")):
		CustomerManager.new().finish(state, visit, "person_deceased")
		return
	if not state.ghost_visits.is_empty() or state.current_night_index not in [5, 6] or state.game_minutes < 300 or visit.arrival < 300: return
	var planned := VarietySaveCodec.selection(state, visit.visit_id)
	if planned.is_empty() or planned.get("context_id", "").is_empty() or not String(planned.get("seven_role", "")).is_empty() or planned.get("familiar_reserved", false): return
	var run := state.ghost_catalog.get_definition("runs", state.run_definition_id) as RunDefinition
	if not run.customer_slots.any(func(slot: VisitSlotDefinition) -> bool: return visit.visit_id.ends_with("/" + slot.id)): return
	if OpeningPreparation.known_ids(state, state.current_night_index).has(visit.visit_id): return
	for row in state.preparation_history:
		if row.action in ["attract", "target", "seek"] and row.change.get("visit_id", "") == visit.visit_id: return
	for story in state.familiar_plan.get("stories", []):
		if story is Dictionary:
			for key in ["first", "follow"]:
				if story.get(key, {}).get("visit_id", "") == visit.visit_id: return
	var tickets := eligible(state)
	if tickets.is_empty(): return
	var ticket: PawnTicket = VarietyService.pick(tickets, state.run_seed, visit.visit_id + "/swap-target")
	state.ghost_visits.append({"visit_id": visit.visit_id, "ticket_id": ticket.ticket_id, "original_customer_id": visit.customer_id, "night": state.current_night_index, "minute": state.game_minutes})
	var guest := state.ghost_catalog.get_definition("customers", SWAP) as CustomerDefinition
	visit.customer_id = SWAP
	visit.person = {"id": "person/" + visit.visit_id, "name": guest.terms.display_name, "portrait": guest.portrait_asset_id}
	visit.voice = guest.persona.duplicate(true)
	visit.scenario_id = ""
	visit.transaction_modes = ["exchange"]
	# Its small case resembles the pledged object, but has not been acquired yet.
	var original := InventoryManager.new().find(state, ticket.item_instance_id)
	visit.item.definition_id = original.definition_id
	visit.item.selected_variant_id = original.selected_variant_id
	visit.item.goods = original.goods.duplicate(true)
	visit.item.revealed_clue_ids.clear()
	visit.item.completed_action_ids.clear()
	visit.item.provenance.clear()
	visit.expires_at = mini(visit.expires_at, state.game_minutes + 90)

static func exchange(day: DayController, catalog: ContentCatalog, id: String, accept: bool) -> ActionResult:
	var state := day.state
	var visit := CustomerManager.new().active(state)
	if not LivingMirror.enabled(day.definition) or state.phase != &"open" or visit == null or visit.visit_id != id or visit.customer_id != SWAP: return ActionResult.new(false, "提匣的人已经不在柜前。")
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or MirrorEncounterService.new(catalog).pending(day) or not PawnReturnService.current(state).is_empty(): return ActionResult.new(false, "请先处理眼前的事情。")
	var ticket := target_ticket(state)
	if not state.exchange_history.is_empty() or ticket == null or ticket not in eligible(state): return ActionResult.new(false, "那件当物已经不能调换。")
	if not TimeController.new().can_spend(state, day.definition, 5): return ActionResult.new(false, "余下时辰不足以办妥。")
	var start := state.game_minutes
	day.spend_action(5)
	CustomerManager.new().update(state)
	if visit.status != "active" or state.phase != &"open": return ActionResult.new(false, "提匣的人收起匣子离开了，钱物未曾交接。")
	if not accept:
		CustomerManager.new().finish(state, visit, "swap_rejected")
		return ActionResult.new(true, "你把当票压回账下。那人收起匣子，八十银元也带走了。")
	var original := InventoryManager.new().find(state, ticket.item_instance_id)
	var replacement := ItemInstance.new()
	replacement.instance_id = "substitute/" + id
	replacement.definition_id = original.definition_id
	replacement.selected_variant_id = original.selected_variant_id
	replacement.goods = original.goods.duplicate(true)
	replacement.acquisition_price = ticket.principal
	replacement.acquired_night = state.current_night_index
	replacement.source_visit_id = id
	replacement.acquisition_type = "substitution"
	replacement.ownership_state = "pledged"
	var definition := catalog.get_definition("items", original.definition_id) as ItemDefinition
	if not definition.provenance.is_empty(): replacement.provenance = {"truth": "none", "status": "unchecked", "evidence": [], "investigated": false}
	original.ownership_state = "exchanged_out"
	ticket.replacement_instance_id = replacement.instance_id
	state.inventory_instances.append(replacement)
	state.exchange_history.append({"visit_id": id, "ticket_id": ticket.ticket_id, "original_id": original.instance_id, "replacement_id": replacement.instance_id, "person_id": ticket.person.get("id", "person/" + ticket.source_visit_id), "name": ticket.person.get("name", "当户"), "night": state.current_night_index, "start": start, "minute": state.game_minutes, "amount": 80})
	EconomyManager.new().commit(state, 80, replacement.instance_id, "exchange/" + id, "pawn_exchange", 80)
	CustomerManager.new().finish(state, visit, "swapped")
	CustomerManager.new().update(state)
	return ActionResult.new(true, "八十银元落在柜上。原物随匣子离开，你把替物放回那张当票下面。\n换物收款80银元；原票的本金、赎金与期限未变。")

static func dawn(state: RunState) -> void:
	if state.ghost_version != 1 or state.phase != &"pre_open": return
	for row in state.exchange_history:
		var ticket := PawnController.new().find(state, row.ticket_id)
		if ticket == null or ticket.status != "redeemed" or ticket.closed_night + 1 > state.current_night_index: continue
		if state.person_deaths.any(func(old: Dictionary) -> bool: return old.person_id == row.person_id): continue
		state.person_deaths.append({"person_id": row.person_id, "name": row.name, "ticket_id": ticket.ticket_id, "replacement_id": row.replacement_id, "redeemed_night": ticket.closed_night, "night": ticket.closed_night + 1, "delivered_night": state.current_night_index})

static func notice(state: RunState, catalog: ContentCatalog) -> String:
	var lines := ""
	for row in state.person_deaths:
		if row.get("source", "pawn_exchange") != "pawn_exchange": continue
		var replacement := InventoryManager.new().find(state, row.replacement_id)
		var item := catalog.get_definition("items", replacement.definition_id) as ItemDefinition
		lines += "\n\n第%d夜开铺前 · 街坊带来的消息\n%s昨夜赎回%s，今日便没了。家里人收拾遗物时，那件东西冰得握不住。\n你记得，那正是提匣人留下的替物。" % [row.delivered_night, row.name, item.display_name]
	return lines

static func decorate(model: Dictionary, day: DayController, catalog: ContentCatalog) -> void:
	if not LivingMirror.enabled(day.definition): return
	var visit := CustomerManager.new().active(day.state)
	if visit == null: return
	if visit.customer_id == CLOSED:
		model.appraisal.body = "来客不许验货。若仍动手，他便收货离去。\n\n" + model.appraisal.body
		model.appraisal.visual["guest_warning"] = "来客不许验货。若仍动手，他便收货离去。"
	if visit.customer_id != SWAP: return
	var ticket := target_ticket(day.state)
	var item := InventoryManager.new().find(day.state, ticket.item_instance_id)
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	var text := "那人指向柜里替%s保管的%s，打开随身的小匣。同样的形状，同样的旧色，边缘却冷冷地泛着青。\n\n“把你那件给我。这件留下，没人看得出来。另奉八十银元。”\n\n当票还没到该撕的时候，物件仍是人家的。" % [ticket.person.get("name", "原主"), definition.display_name]
	model.customer = "提匣的夜客\n" + text
	model.visual.intent = "换物付酬"
	model.visual.introduction = text
	for feature in ["dialogue", "trade", "appraisal"]:
		if model[feature].has("visual"): model[feature].visual.introduction = text
	model.dialogue.body = text
	model.trade.body = text
	model.trade.erase("visual")
	model.trade.can_offer = false
	model.trade.can_pawn = false
	model.trade["exchange"] = true
	model.trade.buttons = []
	var blocked := not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or MirrorEncounterService.new(catalog).pending(day) or not PawnReturnService.current(day.state).is_empty()
	for command in ["swap_accept", "swap_reject"]:
		model.trade.buttons.append({"command": command, "target_id": visit.visit_id, "detail": "", "label": ("交出原物，收下替物与80银元" if command == "swap_accept" else "合上匣子，请他带回去") + " · 5分钟", "enabled": not blocked and TimeController.new().can_spend(day.state, day.definition, 5), "reason": "请先处理眼前的事情。" if blocked else ""})
