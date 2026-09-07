class_name EventDefinition
extends RefCounted

var presentation: Dictionary = {}

var _id: String
var id: String:
	get: return _id
var _title: String
var title: String:
	get: return TranslationServer.translate(_title)
var _speaker: String
var speaker: String:
	get: return TranslationServer.translate(_speaker)
var _body: String
var body: String:
	get: return TranslationServer.translate(_body)
var _kind: String
var kind: String:
	get: return _kind
var _phase: String
var phase: String:
	get: return _phase
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
var _priority: int
var priority: int:
	get: return _priority
var _weight: int
var weight: int:
	get: return _weight
var _max_count: int
var max_count: int:
	get: return _max_count
var _cooldown: int
var cooldown: int:
	get: return _cooldown
var _required_flags: Array
var required_flags: Array:
	get: return _required_flags.duplicate()
var _excluded_flags: Array
var excluded_flags: Array:
	get: return _excluded_flags.duplicate()
var _required_items: Array
var required_items: Array:
	get: return _required_items.duplicate()
var _conflicts_with: Array
var conflicts_with: Array:
	get: return _conflicts_with.duplicate()
var _choices: Array[EventChoiceDefinition]
var choices: Array[EventChoiceDefinition]:
	get: return _choices.duplicate()

static func from_dto(dto: EventDTO) -> EventDefinition:
	var value := EventDefinition.new()
	value.presentation = dto.presentation.duplicate(true)
	value._id = dto.id
	value._title = dto.title
	value._speaker = dto.speaker
	value._body = dto.body
	value._kind = dto.kind
	value._phase = dto.phase
	value._night_min = dto.night_min
	value._night_max = dto.night_max
	value._window_start = dto.window_start
	value._window_end = dto.window_end
	value._priority = dto.priority
	value._weight = dto.weight
	value._max_count = dto.max_count
	value._cooldown = dto.cooldown
	value._required_flags = dto.required_flags.duplicate()
	value._excluded_flags = dto.excluded_flags.duplicate()
	value._required_items = dto.required_items.duplicate()
	value._conflicts_with = dto.conflicts_with.duplicate()
	value._choices = []
	for row in dto.choices: value._choices.append(EventChoiceDefinition.from_source(row))
	return value

func find_choice(choice_id: String) -> EventChoiceDefinition:
	for choice in _choices:
		if choice.id == choice_id: return choice
	return null
