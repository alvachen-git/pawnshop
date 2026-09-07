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
			if value.has("story_slots"):
				if not value.story_slots is Array: CounterDomainValidator._error(issues, at, "剧情位置须为数组。")
				else:
					for anchor in value.story_slots: CounterSchema._fields(anchor, {"index": "nonnegative", "slot_id": "text"}, path, at, issues)
			if value.has("fixed_arrivals"):
				if not value.fixed_arrivals is Dictionary: CounterDomainValidator._error(issues, at, "固定时刻须按夜次配置。")
				else:
					for night in value.fixed_arrivals:
						var times: Variant = value.fixed_arrivals[night]
						if not night is String or not night.is_valid_int() or int(night) < 1 or int(night) > 7 or not times is Array or times.size() != 6:
							CounterDomainValidator._error(issues, at, "固定夜次须有六个时刻。")
							continue
						var previous := -15
						for minute in times:
							if not RunSchema.integer(minute) or minute < previous + 15 or minute > 450 or int(minute) % 5 != 0: CounterDomainValidator._error(issues, at, "固定来访时刻无效。")
							else: previous = int(minute)
			if value.has("preparation_version") and (value.preparation_version != 1 or value.get("seven_version") != 1):
				CounterDomainValidator._error(issues, at, "开铺准备需要七夜编排与有效规则版本。")
			if value.has("seven_version"):
				if value.seven_version != 1 or not value.get("contexts") is Array or value.contexts.size() != 16:
					CounterDomainValidator._error(issues, at, "七夜版需要16种明确来访处境。")
				else:
					var ids: Array = []
					for c in value.contexts:
						CounterSchema._fields(c, {"id": "text", "customer_id": "text", "wait_minutes": "positive", "situation": "text", "transaction_modes": "strings"}, path, at, issues)
						if not c is Dictionary: continue
						CounterSchema._fields(c.get("voice"), {"introduction": "text", "circumstance": "text", "completed": "text", "rejected": "text", "refused": "text", "bargain_context": "text", "timed_out": "text"}, path, at, issues)
						if not issues.is_empty(): continue
						if c.id in ids or c.customer_id not in value.customer_ids or c.situation not in ["ordinary", "urgent"] or c.transaction_modes.is_empty() or c.wait_minutes > 140 or int(c.wait_minutes) % 5 != 0: CounterDomainValidator._error(issues, at, "处境人物、期限或标识无效。")
						ids.append(c.id)
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
		if SevenNightPlan.enabled(run):
			issues.append_array(story_domain(run, catalog))
			if run.total_nights != 7 or run.customer_slots.size() != 42 or not run.batch_selling or not run.market.is_empty(): CounterDomainValidator._error(issues, run.id, "七夜运行配置不一致。")
			for id in run.variety.customer_ids:
				if run.variety.contexts.filter(func(c: Dictionary) -> bool: return c.customer_id == id).size() != 2: CounterDomainValidator._error(issues, run.id, "每类人物须有两种处境。")
			for c in run.variety.contexts:
				var person := catalog.get_definition("customers", c.customer_id) as CustomerDefinition
				if person == null: continue
				for mode in c.transaction_modes:
					if mode not in person.transaction_modes: CounterDomainValidator._error(issues, run.id, "处境不能扩展人物交易方式。")
			for id in run.buyer_ids:
				var buyer := catalog.get_definition("buyers", id) as BuyerDefinition
				if buyer != null and (buyer.action_minutes != 20 or buyer.capacity_per_night != 0): CounterDomainValidator._error(issues, run.id, "七夜出货须为20分钟且不限件数。")
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

static func story_domain(run: RunDefinition, catalog: ContentCatalog) -> Array:
	var issues: Array = []
	var occupied: Array = []
	var used_ids: Array = []
	for anchor in run.variety.get("story_slots", []):
		var index := int(anchor.index)
		var slot: VisitSlotDefinition
		for candidate in run.customer_slots:
			if candidate.id == anchor.slot_id: slot = candidate
		if index >= 42 or index in occupied or anchor.slot_id in used_ids or slot == null:
			CounterDomainValidator._error(issues, run.id, "剧情位置越界、重复或未定义。")
			continue
		occupied.append(index)
		used_ids.append(anchor.slot_id)
		var night := index / 6 + 1
		var item := catalog.get_definition("items", slot.item_id) as ItemDefinition
		var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
		if slot.night_min != night or slot.night_max != night or item == null or item.find_variant(slot.variant_id) == null or customer == null or slot.item_id not in customer.item_pool or "sell" not in customer.transaction_modes:
			CounterDomainValidator._error(issues, run.id, "剧情位置须绑定当夜可出售的实际人物与物品变体。")
		var times: Array = run.variety.get("fixed_arrivals", {}).get(str(night), [])
		if not times.is_empty() and slot.arrival != times[index % 6]: CounterDomainValidator._error(issues, run.id, "剧情来访与当夜固定时刻不一致。")
	return issues
