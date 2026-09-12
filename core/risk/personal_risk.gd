class_name PersonalRisk
extends RefCounted

const RUN_ID := &"life_lamp_seven"
const DESCRIPTIONS := ["火稳，色暖。灯芯上没有杂音。", "火苗短了一截，朝你站的方向偏着。桌边的暖意淡了。", "火苗透出青色。你伸手靠近，指尖仍旧发凉。", "灯芯上只剩一线细火，桌上的光缩在灯座旁。你屏住气，它才勉强直起。", "灯盏冷透了，灯芯再没有亮起来。"]
const LIGHT := [1.0, 0.70, 0.40, 0.14, 0.0]

static func enabled(run: RunDefinition) -> bool:
	return run.id == RUN_ID

static func lamp_state(state: RunState) -> Dictionary:
	var damage := clampi(state.personal_damage, 0, 4)
	return {"damage": damage, "light": LIGHT[damage], "description": DESCRIPTIONS[damage], "extinguished": damage == 4, "double_flame": false}

# The target is total harm from this event instance, not additional harm.
# Healing never erases the event's high-water mark.
static func damage(state: RunState, event_instance: String, total := 1, cause := "有东西贴上了你的影子。", source := "story") -> int:
	if not state.personal_risk_enabled or state.phase in [&"dead", &"bankrupt"] or event_instance.is_empty() or total not in [1, 2]: return 0
	var previous := 0
	for row in state.personal_risk_history:
		if row.event_instance == event_instance and row.kind == "damage": previous = maxi(previous, int(row.event_total))
	if total <= previous: return 0
	var amount := mini(4 - state.personal_damage, total - previous)
	_record(state, event_instance, "damage", amount, total, source, cause)
	state.personal_damage += amount
	if state.personal_damage == 4:
		state.personal_death_phase = String(state.phase)
		var assets := FinancialSummary.build(state)
		state.death_archive.append({"run_token": state.run_token, "run_id": String(state.run_definition_id), "night": state.current_night_index, "minute": state.game_minutes, "source_phase": state.personal_death_phase, "event_instance": event_instance, "cash": state.cash, "item_id": event_instance, "rule_id": "personal_lamp", "cause": cause + "命灯最后一点火灭了。", "item_name": "命灯", "inventory_cost": assets.inventory_cost, "pawn_principal": assets.pawn_principal})
		state.phase = &"dead"
		state.risk_pending = ""
		state.pending_event_id = ""
		state.pending_event_minute = -1
	return amount

static func recover(state: RunState, event_instance: String, amount := 1, cause := "胸口那阵凉意退了一些。") -> int:
	if not state.personal_risk_enabled or state.phase in [&"dead", &"bankrupt"] or event_instance.is_empty() or amount < 1 or amount > 4: return 0
	if state.personal_risk_history.any(func(row: Dictionary) -> bool: return row.kind == "recovery" and row.event_instance == event_instance): return 0
	var restored := mini(amount, state.personal_damage)
	_record(state, event_instance, "recovery", -restored, amount, "story", cause)
	state.personal_damage -= restored
	return restored

static func _record(state: RunState, event_instance: String, kind: String, amount: int, total: int, source: String, cause: String) -> void:
	state.personal_risk_history.append({"event_instance": event_instance, "night": state.current_night_index, "minute": state.game_minutes, "phase": String(state.phase), "kind": kind, "amount": amount, "event_total": total, "source": source, "cause": cause})

static func apply_effect(state: RunState, effect: Dictionary, event_instance: String, cause: String) -> void:
	if effect.has("personal_damage"): damage(state, event_instance, int(effect.personal_damage), cause)
	if effect.has("personal_recovery"): recover(state, event_instance, int(effect.personal_recovery), cause)

static func warning(state: RunState, event_instance: String, total: int) -> String:
	var previous := 0
	for row in state.personal_risk_history:
		if row.event_instance == event_instance and row.kind == "damage": previous = maxi(previous, int(row.event_total))
	return "\n\n你胸口已经冷得发疼，自己的影子薄得几乎看不见。那东西又往前挪了一步。" if state.personal_damage + maxi(0, total - previous) >= 4 else ""
