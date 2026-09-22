class_name AppraisalActionDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _label: String
var label: String:
	get: return _label
var _minutes: int
var minutes: int:
	get: return _minutes
var _required_tool: String
var required_tool: String:
	get: return _required_tool
var _requires_clues: Array
var requires_clues: Array:
	get: return _requires_clues.duplicate()
var _reveals: Array
var reveals: Array:
	get: return _reveals.duplicate()

func _init(p_id: String, p_label: String, p_minutes: int, p_required_tool: String, p_requires_clues: Array, p_reveals: Array) -> void:
	_id = p_id
	_label = p_label
	_minutes = p_minutes
	_required_tool = p_required_tool
	_requires_clues = p_requires_clues.duplicate()
	_reveals = p_reveals.duplicate()

