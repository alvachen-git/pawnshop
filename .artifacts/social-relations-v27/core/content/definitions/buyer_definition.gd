class_name BuyerDefinition
extends RefCounted

var _provenance: Dictionary = {}
var provenance: Dictionary:
	get: return _provenance.duplicate(true)

var _required_flags: Array = []
var required_flags: Array:
	get: return _required_flags.duplicate()
var _id: String
var id: String:
	get: return _id
var _display_name: String
var display_name: String:
	get: return _display_name
var _channel: String
var channel: String:
	get: return _channel
var _categories: Array
var categories: Array:
	get: return _categories.duplicate()
var _value_multiplier: float
var value_multiplier: float:
	get: return _value_multiplier
var _night_min: int
var night_min: int:
	get: return _night_min
var _night_max: int
var night_max: int:
	get: return _night_max
var _window_start: int
var window_start: int:
	get: return _window_start
var _window_end: int
var window_end: int:
	get: return _window_end
var _action_minutes: int
var action_minutes: int:
	get: return _action_minutes
var _capacity_per_night: int
var capacity_per_night: int:
	get: return _capacity_per_night

static func from_dto(dto: BuyerDTO) -> BuyerDefinition:
	var result := BuyerDefinition.new()
	result._provenance = dto.provenance.duplicate(true)
	result._id = dto.id
	result._display_name = dto.display_name
	result._channel = dto.channel
	result._categories = dto.categories.duplicate()
	result._value_multiplier = dto.value_multiplier
	result._night_min = dto.night_min
	result._night_max = dto.night_max
	result._window_start = dto.window_start
	result._window_end = dto.window_end
	result._action_minutes = dto.action_minutes
	result._capacity_per_night = dto.capacity_per_night
	result._required_flags = dto.required_flags.duplicate()
	return result

