class_name VarietySchema
extends RefCounted

static func validate(kind: String, row: Dictionary, path: String, at: String) -> Array:
	var issues: Array = []
	var field := "variety" if kind == "runs" else ("persona" if kind == "customers" else "provenance")
	if not row.has(field): return issues
	if not row[field] is Dictionary or row[field].is_empty():
		issues.append(ContentIssue.new("error", "invalid_record", path, at + "." + field, "新内容扩展需要非空对象。"))
		return issues
	var value: Dictionary = row[field]
	match kind:
		"runs":
			if value.has("profession_wait") and not value.profession_wait is bool: CounterDomainValidator._error(issues, at, "来客等待规则必须为布尔值。")
			CounterSchema._fields(value, {"customer_ids": "strings", "fixed_slots": "strings", "constrained_slots": "strings", "terms_ids": "strings", "surnames": "strings"}, path, at, issues)
			for key in ["customer_ids", "terms_ids", "surnames"]:
				if value.get(key) is Array and value[key].is_empty(): CounterDomainValidator._error(issues, at, "随机抽选池不能为空。")
		"customers":
			CounterSchema._fields(value, {"names": "strings", "origin": "text", "redeem": "text", "extend": "text"}, path, at, issues)
			if value.get("names") is Array and value.names.is_empty(): CounterDomainValidator._error(issues, at, "姓名池不能为空。")
		"items":
			CounterSchema._fields(value, {"document": "text", "matching": "text", "claim": "text", "verified": "text", "unconfirmed": "text", "mismatch": "text", "check_minutes": "positive", "inquiry_minutes": "positive", "inquiry_fee": "positive"}, path, at, issues)
			CounterSchema._fields(value.get("weights"), {"none": "nonnegative", "authentic": "nonnegative", "mismatch": "nonnegative"}, path, at + ".weights", issues)
			if issues.is_empty() and value.weights.none + value.weights.authentic + value.weights.mismatch <= 0: CounterDomainValidator._error(issues, at, "来源权重之和必须大于零。")
		"buyers":
			CounterSchema._fields(value, {"premium_bps": "nonnegative"}, path, at, issues)
			if issues.is_empty() and value.premium_bps > 10000: CounterDomainValidator._error(issues, at, "来源溢价不能超过原报价。")
	return issues

static func domain(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for run: RunDefinition in catalog.get_all("runs"):
		if run.variety.is_empty(): continue
		var ordinary: Array = []
		for id in run.variety.customer_ids:
			var customer := catalog.get_definition("customers", id) as CustomerDefinition
			if customer == null or customer.persona.is_empty():
				CounterDomainValidator._error(issues, run.id, "随机人物引用或姓名池缺失。")
				continue
			var compatible := false
			for item_id in customer.item_pool:
				var item := catalog.get_definition("items", item_id) as ItemDefinition
				if item != null and item.item_type == "normal":
					compatible = true
					if item_id not in ordinary: ordinary.append(item_id)
			if not compatible: CounterDomainValidator._error(issues, id, "人物没有适配的普通物品。")
		for id in run.variety.terms_ids:
			if not catalog.has_definition("pawn_terms", id): CounterDomainValidator._error(issues, run.id, "随机当约不存在。")
		var slot_ids := run.customer_slots.map(func(s: VisitSlotDefinition) -> String: return s.id)
		for id in run.variety.fixed_slots + run.variety.constrained_slots:
			if id not in slot_ids: CounterDomainValidator._error(issues, run.id, "固定来访引用不存在。")
		for id in ordinary:
			var item := catalog.get_definition("items", id) as ItemDefinition
			if item.provenance.is_empty() or TradeScenarioService.for_item(run, id) == null:
				CounterDomainValidator._error(issues, id, "普通物品缺少来源或专属交易情境。")
				continue
			for minutes in [item.provenance.check_minutes, item.provenance.inquiry_minutes]:
				if int(minutes) % run.time_step != 0 or minutes >= run.night_minutes: CounterDomainValidator._error(issues, id, "来源行动耗时不适配营业步长。")
	return issues
