class_name VisitSlotDefinition
extends RefCounted

var _night_min := 1
var night_min: int:
	get: return _night_min
var _night_max := 2147483647
var night_max: int:
	get: return _night_max

var _id: String
var id: String:
	get: return _id
var _arrival: int
var arrival: int:
	get: return _arrival
var _customer_id: String
var customer_id: String:
	get: return _customer_id
var _item_id: String
var item_id: String:
	get: return _item_id
var _variant_id: String
var variant_id: String:
	get: return _variant_id

func _init(p_id: String, p_arrival: int, p_customer_id: String, p_item_id: String, p_variant_id: String, p_night_min := 1, p_night_max := 2147483647) -> void:
	_night_min = p_night_min
	_night_max = p_night_max
	_id = p_id
	_arrival = p_arrival
	_customer_id = p_customer_id
	_item_id = p_item_id
	_variant_id = p_variant_id

