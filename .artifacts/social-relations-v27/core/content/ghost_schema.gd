class_name GhostSchema
extends RefCounted

static func validate(row: Variant, path: String, at: String) -> Array:
	var issues: Array = []
	CounterSchema._fields(row, {"id": "text", "mechanic": "text", "warning": "text", "crisis": "text", "death_cause": "text", "cover_minutes": "positive", "uncover_minutes": "positive"}, path, at, issues)
	return issues

static func domain(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for rule: GhostRuleDefinition in catalog.get_all("ghost_rules"):
		if rule.mechanic != "cover_before_close": CounterDomainValidator._error(issues, rule.id, "不支持的鬼货规则机制。")
	for item: ItemDefinition in catalog.get_all("items"):
		if (item.item_type == "ghost") != (not item.ghost_rule_id.is_empty()) or (not item.ghost_rule_id.is_empty() and not catalog.has_definition("ghost_rules", item.ghost_rule_id)):
			CounterDomainValidator._error(issues, item.id, "鬼货与规则引用不一致。")
	for run: RunDefinition in catalog.get_all("runs"):
		var ids: Array = []
		for id in run.ghost_rule_ids:
			var rule := catalog.get_definition("ghost_rules", id) as GhostRuleDefinition
			if rule == null or id in ids:
				CounterDomainValidator._error(issues, run.id, "鬼货规则缺失或重复。")
				continue
			ids.append(id)
			for cost in [rule.cover_minutes, rule.uncover_minutes]:
				if cost <= 0 or cost > run.night_minutes or cost % run.time_step != 0: CounterDomainValidator._error(issues, run.id, "鬼货处理耗时无效。")
		var ghost_slots := 0
		for slot in run.customer_slots:
			var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
			if customer == null: continue
			for item_id in (customer.item_pool if slot.item_id.is_empty() else [slot.item_id]):
				var item := catalog.get_definition("items", item_id) as ItemDefinition
				if item != null and not item.ghost_rule_id.is_empty():
					ghost_slots += 1
					if item.ghost_rule_id not in ids: CounterDomainValidator._error(issues, run.id, "来访鬼货规则未启用。")
					if slot.night_min != slot.night_max: CounterDomainValidator._error(issues, run.id, "M5鬼货只允许一次固定夜次来访。")
		if ghost_slots > 1: CounterDomainValidator._error(issues, run.id, "M5仅支持一件鬼货；多鬼货组合留待后续扩展。")
	return issues
