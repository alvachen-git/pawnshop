class_name RunDefinition
extends RefCounted

var _seven_plan_cache: Dictionary = {}
var _batch_selling := false
var batch_selling: bool:
	get: return _batch_selling or not _market.is_empty()

var _market: Dictionary = {}
var market: Dictionary:
	get: return _market.duplicate(true)

var _variety: Dictionary = {}
var variety: Dictionary:
	get: return _variety.duplicate(true)

var _ghost_rule_ids: Array = []
var ghost_rule_ids: Array:
	get: return _ghost_rule_ids.duplicate()
var _event_ids: Array = []
var event_ids: Array:
	get: return _event_ids.duplicate()
var _flag_ids: Array = []
var flag_ids: Array:
	get: return _flag_ids.duplicate()
var _fee_policy := FeePolicyDefinition.new()
var fee_policy: FeePolicyDefinition:
	get: return _fee_policy
var _mirror_encounters: Array[MirrorEncounterDefinition] = []
var mirror_encounters: Array[MirrorEncounterDefinition]:
	get: return _mirror_encounters.duplicate()
var _trade_scenarios: Array[TradeScenarioDefinition] = []
var trade_scenarios: Array[TradeScenarioDefinition]:
	get: return _trade_scenarios.duplicate()
var _randomize_seed := false
var _private_room := false
var private_room: bool:
	get: return _private_room
var randomize_seed: bool:
	get: return _randomize_seed
var _id: String
var _total_nights: int
var _opening_minute: int
var _night_minutes: int
var _time_step: int
var _initial_cash: int
var _seed: int
var _actions: Array[DayActionDefinition] = []
var _customer_slots: Array[VisitSlotDefinition] = []
var _tools: Array = []
var _buyer_ids: Array = []
var buyer_ids: Array:
	get: return _buyer_ids.duplicate()
var customer_slots: Array[VisitSlotDefinition]:
	get: return _customer_slots.duplicate()
var tools: Array:
	get: return _tools.duplicate()
var id: String:
	get: return _id
var total_nights: int:
	get: return _total_nights
var opening_minute: int:
	get: return _opening_minute
var night_minutes: int:
	get: return _night_minutes
var time_step: int:
	get: return _time_step
var initial_cash: int:
	get: return _initial_cash
var seed: int:
	get: return _seed
var actions: Array[DayActionDefinition]:
	get: return _actions.duplicate()

static func from_dto(dto: RunDTO) -> RunDefinition:
	var result := RunDefinition.new()
	result._batch_selling = dto.batch_selling
	result._market = dto.market.duplicate(true)
	result._variety = dto.variety.duplicate(true)
	# Copy scalar values; never retain a mutable DTO supplied by the adapter.
	result._ghost_rule_ids = dto.ghost_rule_ids.duplicate()
	result._event_ids = dto.event_ids.duplicate()
	result._flag_ids = dto.flag_ids.duplicate()
	result._fee_policy = FeePolicyDefinition.new(dto.fee_policy)
	for row in dto.mirror_encounters: result._mirror_encounters.append(MirrorEncounterDefinition.new(row))
	for row in dto.trade_scenarios: result._trade_scenarios.append(TradeScenarioDefinition.new(row))
	result._randomize_seed = dto.randomize_seed
	result._private_room = dto.private_room
	result._id = dto.id
	result._total_nights = dto.total_nights
	result._opening_minute = dto.opening_minute
	result._night_minutes = dto.night_minutes
	result._time_step = dto.time_step
	result._initial_cash = dto.initial_cash
	result._seed = dto.seed
	result._tools = dto.tools.duplicate()
	result._buyer_ids = dto.buyer_ids.duplicate()
	for slot in dto.customer_slots:
		result._customer_slots.append(VisitSlotDefinition.new(slot.id, int(slot.arrival), slot.customer_id, slot.item_id, slot.variant_id, int(slot.get("night_min", 1)), int(slot.get("night_max", 2147483647))))
		result._customer_slots.back().tutorial = slot.get("tutorial", {}).duplicate(true)
	for action in dto.actions:
		result._actions.append(DayActionDefinition.new(action.id, action.label, int(action.minutes), action.phases))
	return result

func find_action(action_id: String) -> DayActionDefinition:
	for action in _actions:
		if action.id == action_id:
			return action
	return null
