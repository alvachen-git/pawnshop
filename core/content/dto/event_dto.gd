class_name EventDTO
extends RefCounted

var id: String
var title: String
var speaker: String
var body: String
var kind: String
var phase: String
var night_min: int
var night_max: int
var window_start: int
var window_end: int
var priority: int
var weight: int
var max_count: int
var cooldown: int
var required_flags: Array
var excluded_flags: Array
var required_items: Array
var conflicts_with: Array
var choices: Array

static func from_source(source: Dictionary) -> EventDTO:
	var dto := EventDTO.new()
	dto.id = source.id
	dto.title = source.title
	dto.speaker = source.speaker
	dto.body = source.body
	dto.kind = source.kind
	dto.phase = source.phase
	dto.night_min = int(source.night_min)
	dto.night_max = int(source.night_max)
	dto.window_start = int(source.window_start)
	dto.window_end = int(source.window_end)
	dto.priority = int(source.priority)
	dto.weight = int(source.weight)
	dto.max_count = int(source.max_count)
	dto.cooldown = int(source.cooldown)
	dto.required_flags = source.required_flags.duplicate(true)
	dto.excluded_flags = source.excluded_flags.duplicate(true)
	dto.required_items = source.required_items.duplicate(true)
	dto.conflicts_with = source.conflicts_with.duplicate(true)
	dto.choices = source.choices.duplicate(true)
	return dto
