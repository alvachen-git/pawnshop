class_name RunDefinition
extends RefCounted

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
	# Copy scalar values; never retain a mutable DTO supplied by the adapter.
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
		result._customer_slots.append(VisitSlotDefinition.new(slot.id, int(slot.arrival), slot.customer_id, slot.item_id, slot.variant_id))
	for action in dto.actions:
		result._actions.append(DayActionDefinition.new(action.id, action.label, int(action.minutes), action.phases))
	return result

func find_action(action_id: String) -> DayActionDefinition:
	for action in _actions:
		if action.id == action_id:
			return action
	return null
