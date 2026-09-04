class_name DayActionDefinition
extends RefCounted

var _id: String
var _label: String
var _minutes: int
var _phases: Array
var id: String:
	get: return _id
var label: String:
	get: return _label
var minutes: int:
	get: return _minutes
var phases: Array:
	get: return _phases.duplicate()

func _init(action_id: String, action_label: String, cost: int, allowed_phases: Array) -> void:
	_id = action_id
	_label = action_label
	_minutes = cost
	_phases = allowed_phases.duplicate()
