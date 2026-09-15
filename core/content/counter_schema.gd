class_name CounterSchema
extends RefCounted

# Fixed M2 record shapes, not an expression interpreter.
static func validate(kind: String, record: Dictionary, path: String, at: String) -> Array:
	var issues: Array = []
	if kind == "items":
		if record.has("expertise"):
			var expert: Variant = record.expertise
			_fields(expert, {"kind": "text", "fee": "positive", "minutes": "positive"}, path, at + ".expertise", issues)
			if expert is Dictionary:
				if expert.get("kind") not in ["fan", "cup"]: issues.append(ContentIssue.new("error", "invalid_field", path, at, "未知行家服务。"))
				elif expert.kind == "fan":
					_fields(expert, {"unreviewed_value": "positive"}, path, at, issues)
					_fields(expert.get("results"), {"sound": "text", "flawed": "text", "mended": "text"}, path, at, issues)
				if not RunSchema.integer(expert.get("minutes")) or int(expert.get("minutes", 0)) % 5 != 0: issues.append(ContentIssue.new("error", "invalid_field", path, at, "复核时长须为5分钟倍数。"))
		if record.has("display_name"):
			_fields(record, {"display_name": "text", "description": "text", "unknown_min": "nonnegative", "unknown_max": "positive"}, path, at, issues)
		_rows(record.get("possible_variants", []), {"id": "text", "weight": "ratio_positive", "true_value": "positive", "clue_ids": "strings"}, path, at + ".possible_variants", issues)
		_rows(record.get("clues", []), {"id": "text", "text": "text", "min_value": "nonnegative", "max_value": "positive", "leverage": "nonnegative", "judgement": "judgement"}, path, at + ".clues", issues)
		_rows(record.get("appraisal_actions", []), {"id": "text", "label": "text", "minutes": "positive", "required_tool": "string", "requires_clues": "strings", "reveals": "strings"}, path, at + ".appraisal_actions", issues)
	elif kind == "customers":
		if record.has("counter_terms"):
			_fields(record.counter_terms, {"display_name": "text", "introduction": "text", "wait_minutes": "positive", "quote_minutes": "positive", "pressure_minutes": "positive", "reject_minutes": "positive", "ask_multiplier": "ratio_positive", "reserve_ratio": "unit_positive", "counter_step": "positive", "failed_quote_cost": "positive", "false_pressure_cost": "positive"}, path, at + ".counter_terms", issues)
		_rows(record.get("questions", []), {"id": "text", "prompt": "text", "answer": "text", "minutes": "positive"}, path, at + ".questions", issues)
	elif kind == "runs":
		for key in ["event_ids", "flag_ids"]:
			_fields({key: record.get(key, [])}, {key: "strings"}, path, at, issues)
		if record.get("customer_slots", []) is Array:
			for slot in record.get("customer_slots", []):
				if slot is Dictionary:
					for key in ["night_min", "night_max"]:
						if slot.has(key): _fields(slot, {key: "positive"}, path, at, issues)
		_fields({"tools": record.get("tools", [])}, {"tools": "strings"}, path, at, issues)
		_rows(record.get("customer_slots", []), {"id": "text", "arrival": "nonnegative", "customer_id": "text", "item_id": "string", "variant_id": "string"}, path, at + ".customer_slots", issues)
		if record.get("customer_slots", []) is Array:
			for slot in record.get("customer_slots", []):
				if slot is Dictionary and slot.has("tutorial"):
					_fields(slot.tutorial, {"min_quote_rounds": "positive", "min_patience": "positive"}, path, at + ".tutorial", issues)
	if kind == "items" and record.get("clues") is Array:
		for clue in record.clues:
			if clue is Dictionary:
				for key in ["bargain_line", "bargain_response"]:
					if clue.has(key): _fields(clue, {key: "text"}, path, at + ".clues", issues)
	if kind == "customers" and record.has("belittle"):
		var policy: Variant = record.belittle
		_fields(policy, {"reaction": "text", "minutes": "positive", "ordinary_discount": "nonnegative", "urgent_discount": "nonnegative", "patience_cost": "nonnegative", "cue": "text", "response": "text"}, path, at + ".belittle", issues)
		if policy is Dictionary and policy.get("reaction") not in ["yielding", "firm", "proud"]:
			issues.append(ContentIssue.new("error", "invalid_field", path, at + ".belittle.reaction", "议价反应无效。"))
	return issues

static func _rows(rows: Variant, shape: Dictionary, path: String, at: String, issues: Array) -> void:
	if not rows is Array:
		issues.append(ContentIssue.new("error", "invalid_array", path, at, "需要数组。"))
		return
	var ids: Array = []
	for index in rows.size():
		var row: Variant = rows[index]
		_fields(row, shape, path, at + "[%d]" % index, issues)
		if row is Dictionary and row.get("id") is String:
			if row.id in ids:
				issues.append(ContentIssue.new("error", "duplicate_id", path, at, "嵌套ID重复：" + row.id))
			ids.append(row.id)

static func _fields(row: Variant, shape: Dictionary, path: String, at: String, issues: Array) -> void:
	if not row is Dictionary:
		issues.append(ContentIssue.new("error", "invalid_record", path, at, "需要对象。"))
		return
	for key in shape:
		if not row.has(key):
			issues.append(ContentIssue.new("error", "missing_field", path, at + "." + key, "缺少字段。"))
			continue
		var value: Variant = row[key]
		var valid := true
		match shape[key]:
			"text": valid = value is String and not value.is_empty()
			"string": valid = value is String
			"positive": valid = RunSchema.integer(value) and value > 0 and value <= 1000000
			"nonnegative": valid = RunSchema.integer(value) and value >= 0 and value <= 1000000
			"ratio_positive", "unit_positive":
				valid = typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value) and value > 0 and value <= (1 if shape[key] == "unit_positive" else 100)
			"judgement": valid = value in ["unknown", "sound", "damaged", "fake"]
			"strings":
				valid = value is Array
				if valid:
					var seen: Array = []
					for entry in value:
						if not entry is String or entry.is_empty() or entry in seen: valid = false
						seen.append(entry)
		if not valid:
			issues.append(ContentIssue.new("error", "invalid_field", path, at + "." + key, "类型、枚举或数值范围无效。"))
