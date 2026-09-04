class_name SourceSchemaValidator
extends RefCounted

const ITEM_TYPES := ["normal", "black", "ghost", "pawn", "ward"]
const WEALTH_BANDS := ["poor", "modest", "comfortable", "wealthy"]
const TRANSACTION_MODES := ["sell", "pawn", "redeem", "buy", "exchange", "request"]

const ITEM_FIELDS := {
	"id": TYPE_STRING,
	"name_key": TYPE_STRING,
	"type": TYPE_STRING,
	"category": TYPE_STRING,
	"tags": TYPE_ARRAY,
	"base_value": TYPE_FLOAT,
	"value_variance": TYPE_FLOAT,
	"liquidity": TYPE_FLOAT,
	"possible_variants": TYPE_ARRAY,
	"appraisal_actions": TYPE_ARRAY,
	"clues": TYPE_ARRAY,
	"valuation_rules": TYPE_ARRAY,
	"sell_channels": TYPE_ARRAY,
	"buyer_tags": TYPE_ARRAY,
	"ghost_rule_id": TYPE_STRING,
	"visual_asset_id": TYPE_STRING,
}

const CUSTOMER_FIELDS := {
	"id": TYPE_STRING,
	"name_key": TYPE_STRING,
	"portrait_asset_id": TYPE_STRING,
	"identity_tags": TYPE_ARRAY,
	"wealth_band": TYPE_STRING,
	"urgency_range": TYPE_ARRAY,
	"honesty_profile": TYPE_STRING,
	"patience": TYPE_INT,
	"max_quote_rounds": TYPE_INT,
	"alertness": TYPE_FLOAT,
	"transaction_modes": TYPE_ARRAY,
	"item_pool": TYPE_ARRAY,
	"dialogue_profile_id": TYPE_STRING,
	"preferred_categories": TYPE_ARRAY,
	"schedule_tags": TYPE_ARRAY,
}


func validate_manifest(source: Variant, source_path: String) -> Array:
	var issues: Array = []
	if typeof(source) != TYPE_DICTIONARY:
		issues.append(_issue("invalid_root", source_path, "$", "Manifest根节点必须是对象。"))
		return issues
	if not source.has("content_version") or not _is_integer_value(source.content_version):
		issues.append(_issue("invalid_field", source_path, "content_version", "必须提供整数版本号。"))
	if not source.has("sources") or typeof(source.sources) != TYPE_ARRAY:
		issues.append(_issue("invalid_field", source_path, "sources", "必须提供内容源数组。"))
		return issues
	for index in source.sources.size():
		var entry: Variant = source.sources[index]
		var field_path := "sources[%d]" % index
		if typeof(entry) != TYPE_DICTIONARY:
			issues.append(_issue("invalid_source", source_path, field_path, "内容源必须是对象。"))
			continue
		if not entry.has("kind") or entry.kind not in ContentCatalog.SUPPORTED_KINDS:
			issues.append(_issue("unsupported_kind", source_path, field_path + ".kind", "未知内容类型。"))
		if not entry.has("path") or typeof(entry.path) != TYPE_STRING or not entry.path.begins_with("res://"):
			issues.append(_issue("invalid_path", source_path, field_path + ".path", "路径必须是res://字符串。"))
	if source.has("default_run_id") and (not source.default_run_id is String or source.default_run_id.is_empty()):
		issues.append(_issue("invalid_field", source_path, "default_run_id", "默认运行ID必须是非空字符串。"))
	return issues


func validate_collection(kind: String, source: Variant, source_path: String) -> Array:
	var issues: Array = []
	if typeof(source) != TYPE_DICTIONARY:
		issues.append(_issue("invalid_root", source_path, "$", "内容根节点必须是对象。"))
		return issues
	if not source.has("schema_version") or not _is_integer_value(source.schema_version):
		issues.append(_issue("invalid_field", source_path, "schema_version", "必须提供整数Schema版本。"))
	elif int(source.schema_version) != 1:
		issues.append(_issue("unsupported_version", source_path, "schema_version", "仅支持Schema v1。"))
	if not source.has("records") or typeof(source.records) != TYPE_ARRAY:
		issues.append(_issue("invalid_field", source_path, "records", "必须提供records数组。"))
		return issues
	if kind == "ghost_rules":
		for index in source.records.size():
			issues.append_array(GhostSchema.validate(source.records[index], source_path, "records[%d]" % index))
		return issues
	if kind == "events":
		for index in source.records.size():
			issues.append_array(EventSchema.validate(source.records[index], source_path, "records[%d]" % index))
		return issues
	if kind == "runs":
		for index in source.records.size():
			issues.append_array(RunSchema.validate(source.records[index], source_path, "records[%d]" % index))
			if source.records[index] is Dictionary:
				if source.records[index].has("ghost_rule_ids"):
					CounterSchema._fields(source.records[index], {"ghost_rule_ids": "strings"}, source_path, "records[%d]" % index, issues)
				issues.append_array(CounterSchema.validate(kind, source.records[index], source_path, "records[%d]" % index))
				issues.append_array(CommerceSchema.validate(kind, source.records[index], source_path, "records[%d]" % index))
		return issues
	if kind in ["buyers", "pawn_terms"]:
		for index in source.records.size():
			if not source.records[index] is Dictionary:
				issues.append(_issue("invalid_record", source_path, "records[%d]" % index, "需要对象。"))
			else:
				issues.append_array(CommerceSchema.validate(kind, source.records[index], source_path, "records[%d]" % index))
		return issues
	var schema: Dictionary
	match kind:
		"items":
			schema = ITEM_FIELDS
		"customers":
			schema = CUSTOMER_FIELDS
		_:
			issues.append(_issue("unsupported_kind", source_path, "$", "不支持的内容类型：%s" % kind))
			return issues
	for index in source.records.size():
		var record: Variant = source.records[index]
		var record_path := "records[%d]" % index
		if typeof(record) != TYPE_DICTIONARY:
			issues.append(_issue("invalid_record", source_path, record_path, "记录必须是对象。"))
			continue
		_validate_fields(record, schema, source_path, record_path, issues)
		issues.append_array(CounterSchema.validate(kind, record, source_path, record_path))
		issues.append_array(CommerceSchema.validate(kind, record, source_path, record_path))
		if kind == "items":
			_validate_item(record, source_path, record_path, issues)
		elif kind == "customers":
			_validate_customer(record, source_path, record_path, issues)
	return issues


func _validate_fields(record: Dictionary, schema: Dictionary, source_path: String, record_path: String, issues: Array) -> void:
	for field_name in schema:
		var field_path: String = record_path + "." + field_name
		if not record.has(field_name):
			issues.append(_issue("missing_field", source_path, field_path, "缺少必填字段。"))
			continue
		var expected_type: int = schema[field_name]
		var value: Variant = record[field_name]
		if expected_type == TYPE_INT and _is_integer_value(value):
			continue
		if expected_type == TYPE_FLOAT and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			continue
		if typeof(value) != expected_type:
			issues.append(_issue("invalid_type", source_path, field_path, "字段类型不符合Schema。"))


func _validate_item(record: Dictionary, source_path: String, record_path: String, issues: Array) -> void:
	if record.has("id") and typeof(record.id) == TYPE_STRING and record.id.is_empty():
		issues.append(_issue("empty_id", source_path, record_path + ".id", "ID不能为空。"))
	if record.has("type") and typeof(record.type) == TYPE_STRING and record.type not in ITEM_TYPES:
		issues.append(_issue("invalid_enum", source_path, record_path + ".type", "未知物品类型。"))
	_validate_unit_float(record, "value_variance", source_path, record_path, issues)
	_validate_unit_float(record, "liquidity", source_path, record_path, issues)


func _validate_customer(record: Dictionary, source_path: String, record_path: String, issues: Array) -> void:
	if record.has("wealth_band") and typeof(record.wealth_band) == TYPE_STRING and record.wealth_band not in WEALTH_BANDS:
		issues.append(_issue("invalid_enum", source_path, record_path + ".wealth_band", "未知财富档位。"))
	if record.has("transaction_modes") and typeof(record.transaction_modes) == TYPE_ARRAY:
		for mode in record.transaction_modes:
			if mode not in TRANSACTION_MODES:
				issues.append(_issue("invalid_enum", source_path, record_path + ".transaction_modes", "未知交易模式：%s" % mode))
	if record.has("patience") and _is_integer_value(record.patience) and record.patience < 1:
		issues.append(_issue("out_of_range", source_path, record_path + ".patience", "耐心必须至少为1。"))
	if record.has("max_quote_rounds") and _is_integer_value(record.max_quote_rounds) and record.max_quote_rounds < 1:
		issues.append(_issue("out_of_range", source_path, record_path + ".max_quote_rounds", "报价轮次必须至少为1。"))
	_validate_unit_float(record, "alertness", source_path, record_path, issues)
	if record.has("urgency_range") and typeof(record.urgency_range) == TYPE_ARRAY:
		if record.urgency_range.size() != 2:
			issues.append(_issue("invalid_range", source_path, record_path + ".urgency_range", "区间必须包含两个数值。"))
		elif not _is_number(record.urgency_range[0]) or not _is_number(record.urgency_range[1]):
			issues.append(_issue("invalid_range", source_path, record_path + ".urgency_range", "区间端点必须是数值。"))
		elif float(record.urgency_range[0]) > float(record.urgency_range[1]):
			issues.append(_issue("invalid_range", source_path, record_path + ".urgency_range", "区间下限不能大于上限。"))


func _validate_unit_float(record: Dictionary, field_name: String, source_path: String, record_path: String, issues: Array) -> void:
	if not record.has(field_name) or not _is_number(record[field_name]):
		return
	var value := float(record[field_name])
	if value < 0.0 or value > 1.0:
		issues.append(_issue("out_of_range", source_path, record_path + "." + field_name, "数值必须在0到1之间。"))


func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(value) and value == floor(value)


func _issue(code: String, source_path: String, field_path: String, message: String) -> ContentIssue:
	return ContentIssue.new(ContentIssue.ERROR, code, source_path, field_path, message)
