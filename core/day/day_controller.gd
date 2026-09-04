class_name DayController
extends RefCounted

var definition: RunDefinition
var state: RunState
var _time := TimeController.new()

func _init(run_definition: RunDefinition, run_state: RunState) -> void:
	definition = run_definition
	state = run_state

func can_execute(command: String) -> bool:
	match command:
		"open_shop": return state.phase == &"pre_open"
		"close_shop": return state.phase == &"open"
		"wait_until_seal": return state.phase in [&"open", &"closed_processing"]
		"resolve_night": return state.phase == &"night_resolution"
		"continue_run": return state.phase == &"day_summary"
	var action := definition.find_action(command)
	return action != null and String(state.phase) in action.phases and _time.can_spend(state, definition, action.minutes)

func execute(command: String) -> ActionResult:
	if not can_execute(command):
		return ActionResult.new(false, "操作不可用：阶段不符或剩余时间不足。")
	match command:
		"open_shop":
			state.phase = &"open"
		"close_shop":
			state.closed_at = state.game_minutes
			state.phase = &"closed_processing"
		"resolve_night":
			state.summaries.append({"night": state.current_night_index, "opening_cash": state.night_opening_cash, "closing_cash": state.cash, "closed_at": state.closed_at, "action_count": state.action_count, "outcome": "placeholder_peaceful"})
			state.summaries.back().merge(FinancialSummary.build(state))
			state.phase = &"day_summary"
		"continue_run":
			if state.current_night_index == definition.total_nights:
				state.phase = &"run_ended"
			else:
				state.current_night_index += 1
				state.phase = &"pre_open"
				state.game_minutes = 0
				state.closed_at = -1
				state.action_count = 0
				state.night_opening_cash = state.cash
		_:
			var minutes := definition.night_minutes - state.game_minutes if command == "wait_until_seal" else definition.find_action(command).minutes
			return spend_action(minutes)
	return ActionResult.new(true, "操作完成。")

func spend_action(minutes: int) -> ActionResult:
	var result := _time.spend(state, definition, minutes)
	if not result.ok: return result
	state.action_count += 1
	if state.game_minutes == definition.night_minutes:
		if state.closed_at < 0: state.closed_at = state.game_minutes
		state.phase = &"night_resolution"
	return result
