class_name MirrorEncounterService
extends RefCounted

var catalog: ContentCatalog
var customers := CustomerManager.new()
var risk: RiskManager
func _init(content: ContentCatalog) -> void:
	catalog = content
	risk = RiskManager.new(content)

static func find_definition(run: RunDefinition, id: String) -> MirrorEncounterDefinition:
	for definition in run.mirror_encounters:
		if definition.id == id: return definition
	return null

static func stage(state: RunState, visit_id: String) -> String:
	var result := ""
	for row in state.mirror_history:
		if row.visit_id == visit_id: result = row.action
	return result

func current(day: DayController) -> MirrorEncounterDefinition:
	if day.state.phase != &"open": return null
	var visit := customers.active(day.state)
	if visit == null: return null
	for definition in day.definition.mirror_encounters:
		if visit.visit_id != "%s/%d/%s" % [day.definition.id, day.state.current_night_index, definition.slot_id]: continue
		if day.state.game_minutes >= definition.start_minute and held_mirror(day.state, definition) != null and stage(day.state, visit.visit_id) in ["", "peek"]: return definition
	return null

func held_mirror(state: RunState, definition: MirrorEncounterDefinition) -> ItemInstance:
	for item in state.inventory_instances:
		if item.definition_id == definition.mirror_item_id and item.ownership_state in ["owned", "pledged"]: return item
	return null

func pending(day: DayController) -> bool:
	var visit := customers.active(day.state)
	return current(day) != null and visit != null and stage(day.state, visit.visit_id) == "peek"

func choose(day: DayController, id: String, command: String) -> ActionResult:
	var definition := current(day)
	if definition == null or definition.id != id or not day.state.pending_event_id.is_empty(): return ActionResult.new(false, "柜前的人已离去，镜里也没了那道影子。")
	var visit := customers.active(day.state)
	var previous := stage(day.state, visit.visit_id)
	if command not in (["peek", "decline"] if previous.is_empty() else ["pursue", "stop"]): return ActionResult.new(false, "你已经收回了视线。")
	var mirror := held_mirror(day.state, definition)
	var cost := definition.peek_minutes if command == "peek" else (definition.pursue_minutes if command == "pursue" else 0)
	if cost > 0 and risk.covered(day.state, mirror.instance_id): return ActionResult.new(false, "镜面还覆着红布。")
	if cost > 0 and not TimeController.new().can_spend(day.state, day.definition, cost): return ActionResult.new(false, "余下的时辰不够了。")
	var prior := visit.item.completed_action_ids.duplicate()
	if cost > 0:
		day.spend_action(cost)
		customers.update(day.state)
	var action := command if visit.status == "active" else command + "_expired"
	var row := {"encounter_id": id, "visit_id": visit.visit_id, "mirror_id": mirror.instance_id, "night": day.state.current_night_index, "minute": day.state.game_minutes, "action": action, "prior_actions": prior}
	day.state.mirror_history.append(row)
	risk.capture_close(day.state)
	if visit.status != "active": return ActionResult.new(false, "你抬头时，柜前的人已经走了。镜里只剩下一片昏黄。")
	if command == "peek":
		if definition.clue_id not in visit.item.revealed_clue_ids: visit.item.revealed_clue_ids.append(definition.clue_id)
		return ActionResult.new(true, definition.text("peek_text"))
	if command == "pursue": return ActionResult.new(true, definition.text("pursue_text"))
	return ActionResult.new(true, "你收回视线，柜前的人把怀表往前推了推。镜面还露在外头。" if command == "stop" else "你没有去碰那面镜子，继续招呼柜前的客人。")

func model(day: DayController) -> Dictionary:
	var definition := current(day)
	var result := {"body": "", "buttons": [], "attention_id": ""}
	if definition == null or not day.state.pending_event_id.is_empty(): return result
	var visit := customers.active(day.state)
	var peeked := stage(day.state, visit.visit_id) == "peek"
	result.attention_id = visit.visit_id + ("/peek" if peeked else "/offer")
	result.body = definition.text("peek_text" if peeked else "invitation")
	for command in (["stop", "pursue"] if peeked else ["peek", "decline"]):
		var label: String = {"peek": "借镜照一照来客", "decline": "继续招呼柜前的客人", "stop": "收回视线", "pursue": "看清那张旧当票"}[command]
		var cost := definition.peek_minutes if command == "peek" else (definition.pursue_minutes if command == "pursue" else 0)
		var reason := ""
		if cost > 0:
			label += " · %d分钟" % cost
			if risk.covered(day.state, held_mirror(day.state, definition).instance_id): reason = "请先揭开红布。"
			elif not TimeController.new().can_spend(day.state, day.definition, cost): reason = "剩余时间不足。"
		result.buttons.append({"command": "mirror_" + command, "target_id": definition.id, "detail": "", "label": label, "enabled": reason.is_empty(), "reason": reason})
	return result

static func pursuit(state: RunState, night: int) -> Dictionary:
	for row in state.mirror_history:
		if row.night == night and row.action == "pursue": return row
	return {}
