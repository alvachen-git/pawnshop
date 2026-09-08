class_name EventChoiceDefinition
extends RefCounted

var required_items: Array = []
var required_flags: Array = []
var excluded_flags: Array = []

func available(flags: Array, items: Array = []) -> bool:
	for id in required_items:
		if not items.any(func(item: ItemInstance) -> bool: return item.definition_id == id and item.ownership_state in ["owned", "pledged"]): return false
	if not CounterDomainValidator._contains_all(flags, required_flags): return false
	for flag in excluded_flags:
		if flag in flags: return false
	return true

var _id: String
var id: String:
	get: return _id
var _label: String
var label: String:
	get: return TranslationServer.translate(_label)
var _result: String
var result: String:
	get: return TranslationServer.translate(_result)
var _minutes: int
var minutes: int:
	get: return _minutes
var _grant_flags: Array
var grant_flags: Array:
	get: return _grant_flags.duplicate()

static func from_source(source: Dictionary) -> EventChoiceDefinition:
	var value := EventChoiceDefinition.new()
	value.required_items = source.get("required_items", []).duplicate()
	value.required_flags = source.get("required_flags", []).duplicate()
	value.excluded_flags = source.get("excluded_flags", []).duplicate()
	value._id = source.id
	value._label = source.label
	value._result = source.result
	value._minutes = int(source.minutes)
	value._grant_flags = source.grant_flags.duplicate()
	return value
