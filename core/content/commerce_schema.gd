class_name CommerceSchema
extends RefCounted

static func validate(kind: String, record: Dictionary, path: String, at: String) -> Array:
	var issues: Array = []
	match kind:
		"buyers":
			CounterSchema._fields(record, {"id": "text", "display_name": "text", "channel": "text", "categories": "strings", "value_multiplier": "ratio_positive", "night_min": "positive", "night_max": "positive", "window_start": "nonnegative", "window_end": "positive", "action_minutes": "positive", "capacity_per_night": "nonnegative"}, path, at, issues)
		"pawn_terms":
			CounterSchema._fields({"transfer_ratio": record.get("transfer_ratio", 0.8)}, {"transfer_ratio": "unit_positive"}, path, at, issues)
			CounterSchema._fields(record, {"id": "text", "display_name": "text", "loan_ratio": "unit_positive", "term_nights": "positive", "redemption_fee_ratio": "ratio_positive", "return_mode": "text", "window_start": "nonnegative", "window_end": "positive", "redeem_minutes": "positive", "extension_nights": "positive", "extension_fee_ratio": "ratio_positive", "extend_minutes": "positive"}, path, at, issues)
			if record.get("return_mode") not in ["redeem", "extend_once", "absent"]:
				issues.append(ContentIssue.new("error", "invalid_enum", path, at + ".return_mode", "未知返当行为。"))
		"runs": CounterSchema._fields({"buyer_ids": record.get("buyer_ids", [])}, {"buyer_ids": "strings"}, path, at, issues)
		"customers": CounterSchema._fields({"pawn_terms_id": record.get("pawn_terms_id", "")}, {"pawn_terms_id": "string"}, path, at, issues)
	if kind == "buyers": CounterSchema._fields({"required_flags": record.get("required_flags", [])}, {"required_flags": "strings"}, path, at, issues)
	return issues
