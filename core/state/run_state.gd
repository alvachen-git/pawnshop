class_name RunState
extends RefCounted

const PHASE_PRE_OPEN := &"pre_open"

var run_definition_id: StringName
var current_night_index: int = 1
var phase: StringName = PHASE_PRE_OPEN
var game_minutes: int = 0
var cash: int = 0
var run_seed: int = 0
var closed_at: int = -1
var night_opening_cash: int = 0
var action_count: int = 0
var run_token := ""
var risk_history: Array[Dictionary] = []
var risk_pending := ""
var death_archive: Array[Dictionary] = []
var narrative_flags: Array = []
var event_history: Array[Dictionary] = []
var pending_event_id := ""
var pending_event_minute := -1
var summaries: Array[Dictionary] = []
var inventory_instances: Array[ItemInstance] = []
var pawn_tickets: Array[PawnTicket] = []
var sale_records: Array[Dictionary] = []
var ledger_entries: Array[Dictionary] = []
var visit_history: Array[Dictionary] = []
# Transient visits exist only inside a night. Checkpoints have no live customers.
var visits: Array[CustomerVisit] = []


static func create(definition: RunDefinition) -> RunState:
	var state := RunState.new()
	state.run_definition_id = definition.id
	if not definition.ghost_rule_ids.is_empty(): state.run_token = Crypto.new().generate_random_bytes(16).hex_encode()
	state.run_seed = definition.seed
	state.cash = definition.initial_cash
	state.night_opening_cash = state.cash
	return state


func to_read_model() -> Dictionary:
	return {
		"run_definition_id": String(run_definition_id),
		"run_token": run_token,
		"risk_history": risk_history.duplicate(true),
		"risk_pending": risk_pending,
		"death_archive": death_archive.duplicate(true),
		"current_night_index": current_night_index,
		"phase": String(phase),
		"game_minutes": game_minutes,
		"cash": cash,
		"run_seed": run_seed,
		"closed_at": closed_at,
		"night_opening_cash": night_opening_cash,
		"action_count": action_count,
		"narrative_flags": narrative_flags.duplicate(),
		"event_history": event_history.duplicate(true),
		"pending_event_id": pending_event_id,
		"pending_event_minute": pending_event_minute,
		"summaries": summaries.duplicate(true),
		"inventory_instances": inventory_instances.map(func(item: ItemInstance) -> Dictionary: return item.to_data()),
		"ledger_entries": ledger_entries.duplicate(true),
		"pawn_tickets": pawn_tickets.map(func(ticket: PawnTicket) -> Dictionary: return ticket.to_data()),
		"sale_records": sale_records.duplicate(true),
		"visit_history": visit_history.duplicate(true),
	}
