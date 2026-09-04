class_name EventChoiceDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _label: String
var label: String:
	get: return _label
var _result: String
var result: String:
	get: return _result
var _minutes: int
var minutes: int:
	get: return _minutes
var _grant_flags: Array
var grant_flags: Array:
	get: return _grant_flags.duplicate()

static func from_source(source: Dictionary) -> EventChoiceDefinition:
	var value := EventChoiceDefinition.new()
	value._id = source.id
	value._label = source.label
	value._result = source.result
	value._minutes = int(source.minutes)
	value._grant_flags = source.grant_flags.duplicate()
	return value
