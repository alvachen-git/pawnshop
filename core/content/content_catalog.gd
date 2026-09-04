class_name ContentCatalog
extends RefCounted

const SUPPORTED_KINDS := ["items", "customers", "runs", "buyers", "pawn_terms"]

var content_version: int = 0
var default_run_id: String = ""
var _collections: Dictionary = {
	"items": {},
	"customers": {},
	"runs": {},
	"buyers": {},
	"pawn_terms": {},
}


func add_definition(kind: String, definition: RefCounted) -> bool:
	if not _collections.has(kind):
		return false
	if definition == null or not "id" in definition:
		return false
	var definition_id: String = definition.id
	if definition_id.is_empty() or _collections[kind].has(definition_id):
		return false
	_collections[kind][definition_id] = definition
	return true


func has_definition(kind: String, definition_id: String) -> bool:
	return _collections.has(kind) and _collections[kind].has(definition_id)


func get_definition(kind: String, definition_id: String) -> RefCounted:
	if not has_definition(kind, definition_id):
		return null
	return _collections[kind][definition_id]


func get_count(kind: String) -> int:
	if not _collections.has(kind):
		return 0
	return _collections[kind].size()


func get_ids(kind: String) -> PackedStringArray:
	var result := PackedStringArray()
	if not _collections.has(kind):
		return result
	for definition_id in _collections[kind].keys():
		result.append(definition_id)
	result.sort()
	return result


func get_all(kind: String) -> Array:
	if not _collections.has(kind):
		return []
	return _collections[kind].values()
