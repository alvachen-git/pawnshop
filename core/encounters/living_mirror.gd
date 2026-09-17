class_name LivingMirror
extends RefCounted

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("ghost_guests_version", 0) == 1

static func held(state: RunState) -> ItemInstance:
	for item in state.inventory_instances:
		if item.definition_id == "item_weeping_mirror" and item.ownership_state in ["owned", "pledged"]: return item
	return null

static func customer(day: DayController, catalog: ContentCatalog) -> Dictionary:
	var returning := PawnReturnService.current(day.state)
	if not returning.is_empty():
		return {"id": returning.id, "customer_id": returning.customer_id, "name": returning.get("person", {}).get("name", "持票的当户"), "life": "living"}
	var visit := CustomerManager.new().active(day.state)
	if visit == null: return {}
	var definition := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var life := definition.life_status
	if day.state.investigation_enabled and not visit.night_policy.is_empty(): life = "ghost" if visit.night_policy == "wet_cloth" else "living"
	return {"id": visit.visit_id, "customer_id": visit.customer_id, "name": VarietyService.name_for(visit.person, definition), "life": life}

static func reason(day: DayController, catalog: ContentCatalog, id: String) -> String:
	if not enabled(day.definition) or day.state.phase != &"open": return "开铺接客时才能借镜照人。"
	if not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or MirrorEncounterService.new(catalog).pending(day): return "请先处理眼前的事情。"
	var target := customer(day, catalog)
	if target.is_empty() or target.id != id: return "柜前已不是那位客人。"
	var mirror := held(day.state)
	if mirror == null: return "铜镜已不在铺中。"
	if MirrorEndingService.released(day.state, mirror.instance_id): return "女主人已离去，铜镜不能再辨人生死。"
	if MirrorEndingService.active(day.state): return "先谈完镜前旧事，或暂且收起。"
	if RiskManager.new(catalog).covered(day.state, mirror.instance_id): return "请先揭开红布。"
	if not TimeController.new().can_spend(day.state, day.definition, 5): return "余下时辰不够借镜。"
	return ""

static func describe(row: Dictionary) -> String:
	if row.result == "expired": return "你抬头时，柜前的人已经走了，未能辨清。"
	return ("%s还站在柜前，镜里却只有空柜。此客不是活人。" if row.result == "ghost" else "%s的身影清楚地留在镜中。此客是活人。") % row.name

static func inspect(day: DayController, catalog: ContentCatalog, id: String) -> ActionResult:
	var error := reason(day, catalog, id)
	if not error.is_empty(): return ActionResult.new(false, error)
	var target := customer(day, catalog)
	var mirror := held(day.state)
	var start := day.state.game_minutes
	day.spend_action(5)
	CustomerManager.new().update(day.state)
	var after := customer(day, catalog)
	var result: String = target.life if day.state.phase == &"open" and after.get("id", "") == id else "expired"
	var row := {"visit_id": id, "customer_id": target.customer_id, "name": target.name, "mirror_id": mirror.instance_id, "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes, "result": result}
	day.state.soul_history.append(row)
	return ActionResult.new(result != "expired", describe(row))

static func decorate(model: Dictionary, day: DayController, catalog: ContentCatalog) -> void:
	if not enabled(day.definition): return
	var target := customer(day, catalog)
	if held(day.state) != null and not MirrorEndingService.released(day.state, held(day.state).instance_id) and not target.is_empty():
		var error := reason(day, catalog, target.id)
		model.buttons.push_front({"command": "soul_inspect", "target_id": target.id, "detail": "", "label": "借铜镜照看来客 · 5分钟", "enabled": error.is_empty(), "reason": error})
	if not day.state.soul_history.is_empty():
		var latest: Dictionary = day.state.soul_history.back()
		if latest.night == day.state.current_night_index and latest.minute == day.state.game_minutes and day.state.phase == &"open" and not MirrorEncounterService.new(catalog).pending(day): model.body = describe(latest)
