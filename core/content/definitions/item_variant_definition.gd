class_name ItemVariantDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _true_value: int
var true_value: int:
	get: return _true_value
var _weight: float
var weight: float:
	get: return _weight
var _clue_ids: Array
var clue_ids: Array:
	get: return _clue_ids.duplicate()

func _init(p_id: String, p_true_value: int, p_weight: float, p_clue_ids: Array) -> void:
	_id = p_id
	_true_value = p_true_value
	_weight = p_weight
	_clue_ids = p_clue_ids.duplicate()

