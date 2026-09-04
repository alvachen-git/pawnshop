class_name TimeController
extends RefCounted

func can_spend(state: RunState, definition: RunDefinition, minutes: int) -> bool:
	return state.phase in [&"open", &"closed_processing"] and minutes > 0 and minutes % definition.time_step == 0 and state.game_minutes + minutes <= definition.night_minutes

func spend(state: RunState, definition: RunDefinition, minutes: int) -> ActionResult:
	if not can_spend(state, definition, minutes):
		return ActionResult.new(false, "当前阶段不能行动，或剩余时间不足。")
	state.game_minutes += minutes
	return ActionResult.new(true, "消耗 %d 分钟。" % minutes)

static func clock_text(opening_minute: int, elapsed: int) -> String:
	var absolute := (opening_minute + elapsed) % 1440
	return "%02d:%02d" % [absolute / 60, absolute % 60]
