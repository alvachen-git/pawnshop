class_name CustomerTermsDefinition
extends RefCounted

var _display_name: String
var display_name: String:
	get: return _display_name
var _introduction: String
var introduction: String:
	get: return _introduction
var _wait_minutes: int
var wait_minutes: int:
	get: return _wait_minutes
var _quote_minutes: int
var quote_minutes: int:
	get: return _quote_minutes
var _pressure_minutes: int
var pressure_minutes: int:
	get: return _pressure_minutes
var _reject_minutes: int
var reject_minutes: int:
	get: return _reject_minutes
var _ask_multiplier: float
var ask_multiplier: float:
	get: return _ask_multiplier
var _reserve_ratio: float
var reserve_ratio: float:
	get: return _reserve_ratio
var _counter_step: int
var counter_step: int:
	get: return _counter_step
var _failed_quote_cost: int
var failed_quote_cost: int:
	get: return _failed_quote_cost
var _false_pressure_cost: int
var false_pressure_cost: int:
	get: return _false_pressure_cost

func _init(p_display_name: String, p_introduction: String, p_wait_minutes: int, p_quote_minutes: int, p_pressure_minutes: int, p_reject_minutes: int, p_ask_multiplier: float, p_reserve_ratio: float, p_counter_step: int, p_failed_quote_cost: int, p_false_pressure_cost: int) -> void:
	_display_name = p_display_name
	_introduction = p_introduction
	_wait_minutes = p_wait_minutes
	_quote_minutes = p_quote_minutes
	_pressure_minutes = p_pressure_minutes
	_reject_minutes = p_reject_minutes
	_ask_multiplier = p_ask_multiplier
	_reserve_ratio = p_reserve_ratio
	_counter_step = p_counter_step
	_failed_quote_cost = p_failed_quote_cost
	_false_pressure_cost = p_false_pressure_cost

