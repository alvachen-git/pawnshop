class_name MirrorEncounterDefinition
extends RefCounted

var _data: Dictionary
var once_per_night: bool:
	get: return _data.get("once_per_night", false)
var allow_pursuit: bool:
	get: return _data.get("allow_pursuit", true)
var required_flags: Array:
	get: return _data.get("required_flags", []).duplicate()
var id: String:
	get: return _data.id
var slot_id: String:
	get: return _data.slot_id
var mirror_item_id: String:
	get: return _data.mirror_item_id
var clue_id: String:
	get: return _data.get("clue_id", "")
var start_minute: int:
	get: return int(_data.start_minute)
var peek_minutes: int:
	get: return int(_data.peek_minutes)
var pursue_minutes: int:
	get: return int(_data.pursue_minutes)
func text(key: String) -> String:
	return _data.get(key, "")
func _init(source: Dictionary) -> void:
	_data = source.duplicate(true)
