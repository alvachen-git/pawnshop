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
var seven_plan: Array[Dictionary] = []
var familiar_plan: Dictionary = {}
var familiar_progress: Dictionary = {}
# Read-only raw history context used during ordered validation; never serialized.
var familiar_context: Dictionary = {}
var preparation_history: Array[Dictionary] = []
var preparation_version := 0
var sample_plan: Array[Dictionary] = []
var buyer_appointment: Dictionary = {}
var ordinary_selections: Array[Dictionary] = []
var provenance_history: Array[Dictionary] = []
var night_market_enabled := false
var night_market_history: Array[Dictionary] = []
var risk_history: Array[Dictionary] = []
var risk_pending := ""
var room_enabled := false
var room_history: Array[Dictionary] = []
var fee_history: Array[Dictionary] = []
var fee_arrears: Array[Dictionary] = []
var bankruptcy_archive: Array[Dictionary] = []
var scenario_selections: Array[Dictionary] = []
var scenario_history: Array[Dictionary] = []
var bargaining_history: Array[Dictionary] = []
var mirror_history: Array[Dictionary] = []
var death_archive: Array[Dictionary] = []
var narrative_flags: Array = []
var event_history: Array[Dictionary] = []
var pending_event_id := ""
var pending_event_minute := -1
var summaries: Array[Dictionary] = []
var inventory_instances: Array[ItemInstance] = []
var pawn_rules_start_night := 1
var pawn_returns: Array[Dictionary] = []
var pawn_tickets: Array[PawnTicket] = []
var market_history: Array[Dictionary] = []
var sale_batches: Array[Dictionary] = []
var sale_records: Array[Dictionary] = []
var ledger_entries: Array[Dictionary] = []
var visit_history: Array[Dictionary] = []
# Transient visits exist only inside a night. Checkpoints have no live customers.
var visits: Array[CustomerVisit] = []


static func create(definition: RunDefinition) -> RunState:
	var state := RunState.new()
	state.run_definition_id = definition.id
	state.night_market_enabled = NightMarketPlan.enabled(definition)
	state.preparation_version = int(definition.variety.get("preparation_version", 0))
	state.room_enabled = definition.private_room
	if not definition.ghost_rule_ids.is_empty() or definition.fee_policy.enabled: state.run_token = Crypto.new().generate_random_bytes(16).hex_encode()
	state.run_seed = (int(Crypto.new().generate_random_bytes(4).hex_encode().hex_to_int()) & 0x7fffffff) if definition.randomize_seed else definition.seed
	state.cash = definition.initial_cash
	state.night_opening_cash = state.cash
	return state


func to_read_model() -> Dictionary:
	var data := {
		"run_definition_id": String(run_definition_id),
		"run_token": run_token,
		"ordinary_selections": ordinary_selections.duplicate(true),
		"sample_plan": sample_plan.duplicate(true),
		"seven_plan": seven_plan.duplicate(true),
		"preparation_history": preparation_history.duplicate(true),
		"buyer_appointment": buyer_appointment.duplicate(true),
		"provenance_history": provenance_history.duplicate(true),
		"risk_history": risk_history.duplicate(true),
		"risk_pending": risk_pending,
		"room_enabled": room_enabled,
		"room_history": room_history.duplicate(true),
		"fee_history": fee_history.duplicate(true),
		"fee_arrears": fee_arrears.duplicate(true),
		"bankruptcy_archive": bankruptcy_archive.duplicate(true),
		"mirror_history": mirror_history.duplicate(true),
		"scenario_history": scenario_history.duplicate(true),
		"bargaining_history": bargaining_history.duplicate(true),
		"scenario_selections": scenario_selections.duplicate(true),
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
		"pawn_rules_start_night": pawn_rules_start_night,
		"pawn_returns": pawn_returns.duplicate(true),
		"pawn_tickets": pawn_tickets.map(func(ticket: PawnTicket) -> Dictionary: return ticket.to_data()),
		"sale_records": sale_records.duplicate(true),
		"market_history": market_history.duplicate(true),
		"sale_batches": sale_batches.duplicate(true),
		"visit_history": visit_history.duplicate(true),
	}

	if night_market_enabled:
		data["night_market_history"] = night_market_history.duplicate(true)
		data["night_market_enabled"] = true
	if not familiar_plan.is_empty():
		data["familiar_plan"] = familiar_plan.duplicate(true)
		familiar_progress = FamiliarStories.progress(data)
		data["familiar_progress"] = familiar_progress.duplicate(true)
	return data
