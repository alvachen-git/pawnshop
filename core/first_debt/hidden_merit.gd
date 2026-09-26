class_name HiddenMerit
extends RefCounted

const RUN := "first_debt_merit"
const BALANCED_RUN := "first_debt_merit_balance"
const RELEASE_RUN := "first_debt_merit_release"
const ECHO := "merit_incense"

static func enabled(state: RunState) -> bool:
	return state.run_definition_id in [RUN, BALANCED_RUN, RELEASE_RUN]

static func change(state: RunState, amount: int) -> void:
	if enabled(state): state.hidden_merit = clampi(state.hidden_merit + amount, -100, 100)

static func reward_first_debt(state: RunState, choice: String) -> void:
	# Called before the settlement flags are granted, inside the same transaction.
	if enabled(state) and not FirstDebt.settled(state): change(state, 5 if state.run_definition_id in [BALANCED_RUN, RELEASE_RUN] and choice == "pay" else 10)

static func feedback(state: RunState, mirror_pending := false) -> Dictionary:
	var pending := enabled(state) and FirstDebt.settled(state) and FirstDebt.last(state, ECHO).is_empty()
	var safe := state.phase == &"open" and state.risk_pending.is_empty() and state.pending_event_id.is_empty() and not mirror_pending and not SocialRules.blocked(state) and not MirrorEndingService.active(state)
	# The existing smoke warning is driven by intrusion, even before a crisis.
	var danger := RiskReadModels.smoke_intrusion(state)
	return {"pending": pending, "safe": safe and not danger}

static func acknowledge(state: RunState, choice: String, mirror_pending := false) -> ActionResult:
	var model := feedback(state, mirror_pending)
	if choice != "seen" or not model.pending or not model.safe:
		return ActionResult.new(false, "眼下不能处理这段回应。")
	state.event_history.append({"event_id": ECHO, "choice_id": "seen", "night": state.current_night_index, "phase": String(state.phase), "offered_minute": state.game_minutes, "minute": state.game_minutes})
	return ActionResult.new(true, "")


static func gameplay_event_count(state: RunState) -> int:
	var count := 0
	for row in state.event_history:
		if row.event_id != ECHO: count += 1
	return count
