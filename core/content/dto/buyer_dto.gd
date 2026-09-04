class_name BuyerDTO
extends RefCounted

var required_flags: Array = []
var id: String
var display_name: String
var channel: String
var categories: Array
var value_multiplier: float
var night_min: int
var night_max: int
var window_start: int
var window_end: int
var action_minutes: int
var capacity_per_night: int

static func from_source(source: Dictionary) -> BuyerDTO:
	var dto := BuyerDTO.new()
	dto.id = source.id
	dto.display_name = source.display_name
	dto.channel = source.channel
	dto.categories = source.categories.duplicate()
	dto.value_multiplier = float(source.value_multiplier)
	dto.night_min = int(source.night_min)
	dto.night_max = int(source.night_max)
	dto.window_start = int(source.window_start)
	dto.window_end = int(source.window_end)
	dto.action_minutes = int(source.action_minutes)
	dto.capacity_per_night = int(source.capacity_per_night)
	dto.required_flags = source.get("required_flags", []).duplicate()
	return dto

