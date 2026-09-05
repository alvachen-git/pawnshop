class_name RiskManager
extends RefCounted

const OUTCOMES := ["peaceful", "mirror_safe", "mirror_scar", "mirror_pending", "mirror_survived", "mirror_death"]
const LABELS := {"peaceful": "一夜无事", "mirror_safe": "红布无声", "mirror_scar": "余祟未散", "mirror_pending": "镜中来客", "mirror_survived": "灯火未歇", "mirror_death": "命灯熄灭"}
var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func rule_for(item: ItemInstance) -> GhostRuleDefinition:
	var item_def := catalog.get_definition("items", item.definition_id) as ItemDefinition
	return catalog.get_definition("ghost_rules", item_def.ghost_rule_id) as GhostRuleDefinition

func ghosts(state: RunState) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in state.inventory_instances:
		if rule_for(item) != null: result.append(item)
	return result

func covered(state: RunState, id: String) -> bool:
	var result := false
	for row in state.risk_history:
		if row.item_id == id and row.action in ["cover", "uncover", "retreat"]: result = row.action != "uncover"
	return result

func held_at(state: RunState, item: ItemInstance, night: int, minute: int) -> bool:
	if item.acquired_night > night: return false
	for entry in state.ledger_entries:
		if entry.item_instance_id != item.instance_id: continue
		if entry.kind in ["acquisition", "pawn_loan"] and entry.night == night and entry.minute > minute: return false
		if entry.kind in ["sale", "redemption"] and (entry.night < night or (entry.night == night and entry.minute <= minute)): return false
	return true

# Called after every time-changing intent, including auto-seal and event choices.
func capture_close(state: RunState) -> void:
	if state.closed_at < 0: return
	for item in ghosts(state):
		if item.ownership_state not in ["owned", "pledged"]: continue
		var found := false
		for row in state.risk_history:
			if row.night == state.current_night_index and row.item_id == item.instance_id and row.action == "close": found = true
		if not found:
			var row := _row(state, item.instance_id, "close")
			row.minute = state.closed_at
			row.covered = covered(state, item.instance_id)
			state.risk_history.append(row)

func reason(day: DayController, id: String, command: String) -> String:
	if command not in ["cover", "uncover"]: return "未知处理方式。"
	if day.state.phase not in [&"open", &"closed_processing"]: return "只可在营业或关门处理时动手。"
	var item := InventoryManager.new().find(day.state, id)
	if item == null or rule_for(item) == null or item.ownership_state not in ["owned", "pledged"]: return "该鬼货不在铺中。"
	if covered(day.state, id) == (command == "cover"): return "物品已经处于该存放状态。"
	var rule := rule_for(item)
	var cost := rule.cover_minutes if command == "cover" else rule.uncover_minutes
	if day.state.game_minutes + cost > day.definition.night_minutes: return "剩余时间不足：需要%d分钟。" % cost
	return ""

func handle(day: DayController, id: String, command: String) -> ActionResult:
	var unavailable := reason(day, id, command)
	if not unavailable.is_empty(): return ActionResult.new(false, unavailable)
	var rule := rule_for(InventoryManager.new().find(day.state, id))
	var result := day.spend_action(rule.cover_minutes if command == "cover" else rule.uncover_minutes)
	if not result.ok: return result
	day.state.risk_history.append(_row(day.state, id, command))
	capture_close(day.state)
	return ActionResult.new(true, "红布已经盖好。" if command == "cover" else "红布已揭开，镜缘又出现血泪。封铺前务必重新遮盖。")

func night_outcome(state: RunState, night: int) -> String:
	if not MirrorEncounterService.pursuit(state, night).is_empty(): return "mirror_pending"
	return storage_outcome(state, night)

func storage_outcome(state: RunState, night: int) -> String:
	var result := "peaceful"
	for row in state.risk_history:
		if row.night != night or row.action != "close": continue
		# A later uncover also breaks storage, even if it was covered at closing.
		var safe: bool = row.covered
		var cloth: bool = row.covered
		for later in state.risk_history:
			if later.night == night and later.item_id == row.item_id and later.action in ["cover", "uncover"] and later.minute >= row.minute:
				cloth = later.action == "cover"
				if later.action == "uncover": safe = false
		if not cloth: return "mirror_pending"
		if not safe: result = "mirror_scar"
		elif result == "peaceful": result = "mirror_safe"
	return result

func settle(state: RunState) -> void:
	var outcome := night_outcome(state, state.current_night_index)
	state.summaries.back().outcome = outcome
	state.risk_pending = ""
	if outcome == "mirror_pending":
		var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
		if not pursuit.is_empty():
			state.risk_pending = pursuit.mirror_id
			return
		for item in ghosts(state):
			if item.ownership_state in ["owned", "pledged"] and not covered(state, item.instance_id):
				state.risk_pending = item.instance_id
				break

func respond(state: RunState, id: String, command: String) -> ActionResult:
	if state.phase != &"day_summary" or id.is_empty() or id != state.risk_pending or command not in ["retreat", "defy"]: return ActionResult.new(false, "这次夜间应对已结束或选择无效。")
	state.risk_history.append(_row(state, id, command))
	state.risk_pending = ""
	if command == "defy":
		state.phase = &"dead"
		state.summaries.back().outcome = "mirror_death"
		state.death_archive.append(death_record(state, id))
		return ActionResult.new(true, "灯芯烧尽了。柜上的账册无风翻开，停在一张空白页上。")
	state.summaries.back().outcome = "mirror_survived"
	if not MirrorEncounterService.pursuit(state, state.current_night_index).is_empty(): return ActionResult.new(true, "你垂下眼，将命灯护在怀里。脚边那道影子终于停住，却比你迟了一步。")
	return ActionResult.new(true, "你垂下眼，把红布慢慢覆上。耳边的声音停了。再看命灯，灯芯仍朝着你的影子歪斜。")

func death_record(state: RunState, id: String) -> Dictionary:
	var item := InventoryManager.new().find(state, id)
	var rule := rule_for(item)
	var item_def := catalog.get_definition("items", item.definition_id) as ItemDefinition
	var financial := FinancialSummary.build(state)
	var record := {"run_token": state.run_token, "run_id": String(state.run_definition_id), "night": state.current_night_index, "cash": state.cash, "item_id": id, "rule_id": rule.id, "cause": rule.death_cause, "item_name": item_def.display_name, "inventory_cost": financial.inventory_cost, "pawn_principal": financial.pawn_principal}
	var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
	if not pursuit.is_empty() and (not state.room_enabled or state.risk_history.back().get("scope", "") == "personal"):
		var run := catalog.get_definition("runs", String(state.run_definition_id)) as RunDefinition
		var encounter := MirrorEncounterService.find_definition(run, pursuit.encounter_id) if run != null else null
		if encounter != null:
			record.encounter_id = encounter.id
			record.cause = encounter.text("death_cause")
	return record

static func _row(state: RunState, id: String, action: String) -> Dictionary:
	return {"night": state.current_night_index, "minute": state.game_minutes, "item_id": id, "action": action}
