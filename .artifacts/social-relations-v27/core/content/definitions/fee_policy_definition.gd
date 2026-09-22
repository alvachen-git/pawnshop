class_name FeePolicyDefinition
extends RefCounted

var _data: Dictionary
var principal: int:
	get: return int(_data.get("principal", 0))
var interest_bps: int:
	get: return int(_data.get("interest_bps", 0))
var overhead: int:
	get: return int(_data.get("overhead", 0))
var grace_nights: int:
	get: return int(_data.get("grace_nights", 1))
var enabled: bool:
	get: return not _data.is_empty()
var interest: int:
	get: return ceili(principal * interest_bps / 10000.0)

func _init(source: Dictionary = {}) -> void:
	_data = source.duplicate(true)
