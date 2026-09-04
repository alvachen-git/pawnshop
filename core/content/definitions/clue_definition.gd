class_name ClueDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _text: String
var text: String:
	get: return _text
var _min_value: int
var min_value: int:
	get: return _min_value
var _max_value: int
var max_value: int:
	get: return _max_value
var _leverage: int
var leverage: int:
	get: return _leverage
var _judgement: String
var judgement: String:
	get: return _judgement

func _init(p_id: String, p_text: String, p_min_value: int, p_max_value: int, p_leverage: int, p_judgement: String) -> void:
	_id = p_id
	_text = p_text
	_min_value = p_min_value
	_max_value = p_max_value
	_leverage = p_leverage
	_judgement = p_judgement

