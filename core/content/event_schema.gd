class_name EventSchema
extends RefCounted

static func validate(row: Variant, path: String, at: String) -> Array:
	var issues: Array = []
	CounterSchema._fields(row, {"id": "text", "title": "text", "speaker": "text", "body": "text", "kind": "text", "phase": "text", "night_min": "positive", "night_max": "positive", "window_start": "nonnegative", "window_end": "positive", "priority": "nonnegative", "weight": "positive", "max_count": "positive", "cooldown": "nonnegative", "required_flags": "strings", "excluded_flags": "strings", "required_items": "strings", "conflicts_with": "strings"}, path, at, issues)
	if not row is Dictionary: return issues
	CounterSchema._rows(row.get("choices"), {"id": "text", "label": "text", "result": "text", "minutes": "nonnegative", "grant_flags": "strings"}, path, at + ".choices", issues)
	return issues
