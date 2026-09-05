class_name RoomFlow
extends RefCounted

# Only lifecycle actions are persisted here. Physical cover/uncover actions remain
# in risk_history; this transcript links each irreversible response to its phase.
const PHASES := ["shop_resolution", "private_room", "sleep_resolution"]

static func can_execute(state: RunState, command: String) -> bool:
	if not state.room_enabled or not state.risk_pending.is_empty(): return false
	match command:
		"enter_room": return state.phase == &"shop_resolution"
		"sleep": return state.phase == &"private_room"
		"finish_sleep": return state.phase == &"sleep_resolution"
	return false

static func scope(state: RunState) -> String:
	return "personal" if state.phase == &"sleep_resolution" else "shop"

static func response(state: RunState, night: int, side: String) -> String:
	for row in state.risk_history:
		if row.night == night and row.get("scope", "") == side: return row.action
	return ""

static func storage_pending(state: RunState, manager: RiskManager) -> String:
	for item in manager.ghosts(state):
		if manager.held_at(state, item, state.current_night_index, state.game_minutes) and not manager.covered(state, item.instance_id): return item.instance_id
	return ""

static func outcome(state: RunState, manager: RiskManager, night: int) -> String:
	var shop := response(state, night, "shop")
	var personal := response(state, night, "personal")
	if "defy" in [shop, personal]: return "mirror_death"
	if manager.storage_outcome(state, night) == "mirror_pending" and shop.is_empty(): return "mirror_pending"
	if not MirrorEncounterService.pursuit(state, night).is_empty() and personal.is_empty(): return "mirror_pending"
	if not shop.is_empty() or not personal.is_empty(): return "mirror_survived"
	return manager.storage_outcome(state, night)

static func update_outcome(state: RunState, manager: RiskManager) -> void:
	state.summaries.back().outcome = outcome(state, manager, state.current_night_index)

static func seal(state: RunState, manager: RiskManager) -> void:
	state.phase = &"shop_resolution"
	state.risk_pending = storage_pending(state, manager)
	state.room_history.append({"night": state.current_night_index, "action": "seal"})
	update_outcome(state, manager)

static func execute(state: RunState, manager: RiskManager, command: String) -> ActionResult:
	if not can_execute(state, command): return ActionResult.new(false, "眼前的事情还没有处理完。")
	state.room_history.append({"night": state.current_night_index, "action": command})
	match command:
		"enter_room": state.phase = &"private_room"
		"sleep":
			state.phase = &"sleep_resolution"
			var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
			state.risk_pending = pursuit.mirror_id if not pursuit.is_empty() else ""
		"finish_sleep": state.phase = &"day_summary"
	update_outcome(state, manager)
	return ActionResult.new(true, "窗外的车铃声，隔着墙渐渐远了。")

static func respond(state: RunState, manager: RiskManager, id: String, command: String) -> ActionResult:
	if state.phase not in [&"shop_resolution", &"sleep_resolution"] or id.is_empty() or id != state.risk_pending or command not in ["retreat", "defy"]:
		return ActionResult.new(false, "这次应对已经结束。")
	var side := scope(state)
	state.risk_history.append({"night": state.current_night_index, "minute": state.game_minutes, "item_id": id, "action": command, "scope": side})
	state.room_history.append({"night": state.current_night_index, "action": side + "_" + command})
	state.risk_pending = ""
	if command == "defy":
		state.phase = &"dead"
		state.death_archive.append(manager.death_record(state, id))
	update_outcome(state, manager)
	return ActionResult.new(true, "灯芯烧尽了。" if command == "defy" else ("你护住灯盏，等那道影子慢慢退开。" if side == "personal" else "红布落下，镜前的脚步声停了。"))
