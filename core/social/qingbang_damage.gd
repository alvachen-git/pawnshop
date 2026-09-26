class_name QingbangDamage
extends RefCounted

static func ordinary(state: RunState, item: ItemInstance) -> bool:
	var definition := state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
	if definition == null or not definition.ghost_rule_id.is_empty() or not item.definition_id.begins_with("item_"): return false
	if definition.tags.any(func(tag: String) -> bool: return tag in ["story","quest","key_item"]): return false
	for ticket in state.pawn_tickets:
		if ticket.collateral_id() == item.instance_id and (ticket.terms_id == FamiliarStories.TERMS or not ticket.replacement_instance_id.is_empty()): return false
	for row in state.ordinary_selections:
		if row.visit_id == item.source_visit_id and (row.get("familiar_reserved",false) or row.get("early_redemption",false)): return false
	for visit in state.visits:
		if visit.item != null and visit.item.instance_id == item.instance_id and (not visit.night_policy.is_empty() or visit.purpose not in ["","qingbang_supply"]): return false
	var run := state.ghost_catalog.get_definition("runs",state.run_definition_id) as RunDefinition
	for event_id in run.event_ids:
		var event := state.ghost_catalog.get_definition("events",event_id) as EventDefinition
		if item.definition_id in event.required_items: return false
	return true

static func pick(state: RunState, event_id: String) -> Array:
	var pool: Array = state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.ownership_state in ["owned","pledged"] and ordinary(state,item))
	var result: Array = []
	var rng := VarietyService.rng(state.run_seed,event_id + "/items")
	for i in mini(int(QingbangRules.config().raid_items),pool.size()):
		var index := rng.randi_range(0,pool.size()-1)
		result.append(pool[index].instance_id)
		pool.remove_at(index)
	return result

static func apply(state: RunState, event: Dictionary) -> String:
	var q: Dictionary = state.social.qingbang
	if q.raids.any(func(r: Dictionary) -> bool: return r.id == event.id): return "这次损失已经记过。"
	var names: Array[String] = []
	var damaged: Array = []
	for id in event.items:
		var item := InventoryManager.new().find(state,id)
		if item == null or item.ownership_state not in ["owned","pledged"] or not ordinary(state,item): continue
		var previous := item.ownership_state
		item.goods["qingbang_loss"] = {"event":event.id,"night":state.current_night_index,"ownership":previous}
		item.ownership_state = "destroyed"
		damaged.append(id)
		var definition := state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
		names.append(definition.display_name + ("（在当）" if previous == "pledged" else ""))
		EconomyManager.new().commit(state,0,id,event.id + "/" + id,"inventory_loss")
	q.raids.append({"id":event.id,"night":state.current_night_index,"items":damaged})
	q.last_raid = state.current_night_index
	SocialRules.change(state,"reputation",int(QingbangRules.config().raid_reputation),event.id)
	return ("清点后，%s已彻底报废，不能再卖或交货。" % "、".join(names) if not names.is_empty() else "柜架被推倒，幸而没有可被砸坏的货物。") + "\n门口的人议论这铺子不安生，街坊对当铺的信任受了损。"

static func lost(state: RunState, ticket: PawnTicket) -> bool:
	if not QingbangRules.active(state) or ticket == null: return false
	var item := InventoryManager.new().find(state,ticket.collateral_id())
	return item != null and item.ownership_state == "destroyed" and item.goods.has("qingbang_loss")

static func close_ticket(state: RunState, ticket: PawnTicket) -> void:
	ticket.status = "destroyed"
	ticket.closed_night = state.current_night_index
	ticket.closed_minute = state.game_minutes

static func settle_return(day: DayController, ticket: PawnTicket, visit: Dictionary) -> ActionResult:
	var state := day.state
	var item := InventoryManager.new().find(state,ticket.collateral_id())
	var group: String = item.goods.qingbang_loss.event
	var who := String(ticket.person.get("id",ticket.customer_id))
	var key := group + "/" + who
	var q: Dictionary = state.social.qingbang
	if not q.complaints.any(func(row: Dictionary) -> bool: return row.id == key):
		var config := QingbangRules.config()
		var delta := -VarietyService.rng(state.run_seed,key + "/complaint").randi_range(int(config.complaint_min),int(config.complaint_max))
		q.complaints.append({"id":key,"night":state.current_night_index,"delta":delta})
		SocialRules.change(state,"reputation",delta,"damaged_pawn/" + key)
	# One meeting resolves all collateral belonging to the same person in this raid.
	for other in state.pawn_tickets:
		if other.status != "active" or not lost(state,other): continue
		var other_item := InventoryManager.new().find(state,other.collateral_id())
		if String(other.person.get("id",other.customer_id)) != who or other_item.goods.qingbang_loss.event != group: continue
		close_ticket(state,other)
		for back in state.pawn_returns:
			if back.ticket_id == other.ticket_id and back.status != "completed":
				back.status = "completed"
				back.start = visit.start
				back.minute = state.game_minutes
	var text := "你向当户说明原物被砸，本金息费一并免还，不另付赔款。当户收回当票，沉着脸出了门，转身向街坊诉说。铺子的口碑又受了影响。"
	QingbangRules.notice(state,text)
	return ActionResult.new(true,text)

static func decorate(model: Dictionary, day: DayController, ticket: PawnTicket, visit: Dictionary) -> void:
	if not lost(day.state,ticket): return
	var text := "当户拿着原票来办手续，柜上却只剩损毁记录。\n\n‘寄在这里的东西，你们总得给个交代。’\n\n原物已经报废。本金息费免还，不另付赔款；须向当户说明并核销当票。"
	model.item = ""
	model["itemless"] = true
	model.visual.item_asset = ""
	model.visual.item_name = ""
	model.visual.estimate = ""
	model.visual["item_status"] = "原物损毁 · 待核销当票"
	model.visual.clues = []
	model.visual.introduction = "当户攥着原票，等你交代原物的下落。"
	model.context_actions.item = []
	model.context_actions.customer = [{"id":"trade","label":"说明原物损毁","enabled":true}]
	for section in ["appraisal","dialogue","trade"]:
		model[section].body = text
	model.dialogue.visual = model.visual.duplicate(true)
	model.trade.buttons = [{"command":visit.command,"detail":"","label":"说明原物损毁，免本息核销","enabled":true,"reason":""}]
