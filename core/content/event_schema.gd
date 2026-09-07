class_name EventSchema
extends RefCounted

static func validate(row: Variant, path: String, at: String) -> Array:
	var issues: Array = []
	CounterSchema._fields(row, {"id": "text", "title": "text", "speaker": "text", "body": "text", "kind": "text", "phase": "text", "night_min": "positive", "night_max": "positive", "window_start": "nonnegative", "window_end": "positive", "priority": "nonnegative", "weight": "positive", "max_count": "positive", "cooldown": "nonnegative", "required_flags": "strings", "excluded_flags": "strings", "required_items": "strings", "conflicts_with": "strings"}, path, at, issues)
	if not row is Dictionary: return issues
	CounterSchema._rows(row.get("choices"), {"id": "text", "label": "text", "result": "text", "minutes": "nonnegative", "grant_flags": "strings"}, path, at + ".choices", issues)
	if row.has("presentation"):
		CounterSchema._fields(row.presentation, {"scene": "text"}, path, at + ".presentation", issues)
		if row.presentation is Dictionary:
			for key in ["hotspots", "checkpoint", "repeat_skip"]:
				if row.presentation.has(key) and not row.presentation[key] is bool: issues.append(ContentIssue.new("error", "invalid_field", path, at, key + "须为布尔值。"))
			if row.presentation.has("purchase_slot_id"): CounterSchema._fields(row.presentation, {"purchase_slot_id": "text"}, path, at, issues)
			if row.presentation.has("required_purchases"): CounterSchema._fields(row.presentation, {"required_purchases": "positive"}, path, at, issues)
	if row.get("choices") is Array:
		for choice in row.choices:
			if choice is Dictionary:
				for key in ["required_flags", "excluded_flags"]:
					if choice.has(key): CounterSchema._fields(choice, {key: "strings"}, path, at, issues)
	return issues
