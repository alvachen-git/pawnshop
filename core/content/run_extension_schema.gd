class_name RunExtensionSchema
extends RefCounted

static func validate(row: Dictionary, path: String, at: String) -> Array:
	var issues: Array = TradeScenarioSchema.validate(row, path, at)
	if row.has("fee_policy"):
		var policy: Variant = row.fee_policy
		CounterSchema._fields(policy, {"principal": "positive", "interest_bps": "positive", "overhead": "positive", "grace_nights": "positive"}, path, at + ".fee_policy", issues)
		if policy is Dictionary and issues.is_empty():
			if policy.principal > 1000000 or policy.interest_bps > 10000 or policy.overhead > 1000000 or policy.grace_nights != 1:
				CounterDomainValidator._error(issues, at, "息费范围无效；宽限期须为一夜。")
	if not row.get("mirror_encounters", []) is Array:
		CounterDomainValidator._error(issues, at, "铜镜遭遇须为数组。")
		return issues
	for encounter in row.get("mirror_encounters", []):
		CounterSchema._fields(encounter, {"id": "text", "slot_id": "text", "mirror_item_id": "text", "clue_id": "text", "start_minute": "positive", "peek_minutes": "positive", "pursue_minutes": "positive", "invitation": "text", "peek_text": "text", "pursue_text": "text", "crisis": "text", "death_cause": "text"}, path, at + ".mirror_encounters", issues)
	return issues

static func domain(catalog: ContentCatalog) -> Array:
	var issues: Array = TradeScenarioSchema.domain(catalog)
	for run: RunDefinition in catalog.get_all("runs"):
		if run.private_room and run.ghost_rule_ids.is_empty() and not OrdinarySamplePlan.enabled(run): CounterDomainValidator._error(issues, run.id, "房间原型需要启用鬼货风险规则。")
		var p := run.fee_policy
		if p.enabled and (p.principal < 1 or p.principal > 1000000 or p.interest_bps < 1 or p.interest_bps > 10000 or p.overhead < 1 or p.overhead > 1000000 or p.grace_nights != 1): CounterDomainValidator._error(issues, run.id, "运行息费规则无效。")
		var ids: Array = []
		for encounter in run.mirror_encounters:
			if encounter.id in ids: CounterDomainValidator._error(issues, run.id, "铜镜遭遇ID重复。")
			ids.append(encounter.id)
			var mirror := catalog.get_definition("items", encounter.mirror_item_id) as ItemDefinition
			if mirror == null or mirror.ghost_rule_id not in run.ghost_rule_ids: CounterDomainValidator._error(issues, run.id, "遭遇铜镜未启用。")
			var slot_found := false
			for slot in run.customer_slots:
				if slot.id != encounter.slot_id: continue
				slot_found = true
				var item := catalog.get_definition("items", slot.item_id) as ItemDefinition
				if item == null or item.find_variant(slot.variant_id) == null or encounter.clue_id not in item.find_variant(slot.variant_id).clue_ids:
					CounterDomainValidator._error(issues, run.id, "遭遇须绑定固定物品变体及真实证据。")
			if not slot_found: CounterDomainValidator._error(issues, run.id, "遭遇来访槽不存在。")
			for cost in [encounter.peek_minutes, encounter.pursue_minutes, encounter.start_minute]:
				if cost <= 0 or cost >= run.night_minutes or cost % run.time_step != 0: CounterDomainValidator._error(issues, run.id, "遭遇时间不符合步长。")
	return issues
