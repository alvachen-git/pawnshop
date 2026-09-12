class_name RunSnapshot
extends RefCounted

# Preserve aliasing between a live visitor and inventory, while isolating every
# mutable nested object (quotes, revealed clues, patience and trade state).
static func copy(source: RunState) -> RunState:
	return _clone(source, {}) as RunState

static func _clone(value: Variant, objects: Dictionary) -> Variant:
	if value is Array:
		var result: Array = value.duplicate()
		for index in result.size(): result[index] = _clone(value[index], objects)
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _clone(value[key], objects)
		return result
	if value is RefCounted and value.get_script() != null:
		var identity: int = value.get_instance_id()
		if objects.has(identity): return objects[identity]
		var result: Object = value.get_script().new()
		objects[identity] = result
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result.set(property.name, _clone(value.get(property.name), objects))
		return result
	return value
