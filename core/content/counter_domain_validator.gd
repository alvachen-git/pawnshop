class_name CounterDomainValidator
extends RefCounted

static func validate(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for item: ItemDefinition in catalog.get_all("items"):
		for records in [item.possible_variants, item.appraisal_actions, item.clues]:
			var ids: Array = []
			for record in records:
				if record.id.is_empty() or record.id in ids: _error(issues, item.id, "嵌套ID为空或重复。")
				ids.append(record.id)
		if not is_finite(item.base_value) or item.base_value <= 0 or item.base_value > 1000000: _error(issues, item.id, "基础价值无效。")
		if item.unknown_min < 0 or item.unknown_min > item.unknown_max:
			_error(issues, item.id, "估值区间无效。")
		for variant in item.possible_variants:
			if variant.true_value <= 0 or not is_finite(variant.weight) or variant.weight <= 0: _error(issues, item.id, "变体真实价值或权重无效。")
			if variant.true_value < item.unknown_min or variant.true_value > item.unknown_max: _error(issues, item.id, "初始估值区间不包含真实价值。")
			for clue_id in variant.clue_ids:
				var clue := item.find_clue(clue_id)
				if clue == null:
					_error(issues, item.id, "变体引用缺失线索：" + clue_id)
				elif clue.min_value > variant.true_value or clue.max_value < variant.true_value:
					_error(issues, item.id, "证据估值范围不包含变体真实价值。")
		for clue in item.clues:
			if clue.leverage < 0 or clue.min_value < 0 or clue.judgement not in ["unknown", "sound", "damaged", "fake"]: _error(issues, item.id, "线索取值无效。")
			if clue.min_value > clue.max_value:
				_error(issues, item.id, "证据估值区间无效。")
		for action in item.appraisal_actions:
			if action.minutes <= 0 or action.reveals.is_empty(): _error(issues, item.id, "鉴定动作没有正耗时或揭示目标。")
			for clue_id in action.requires_clues + action.reveals:
				if item.find_clue(clue_id) == null:
					_error(issues, item.id, "动作引用缺失线索：" + clue_id)
		# Fixed-point reachability detects evidence prerequisites that cannot be satisfied.
		for variant in item.possible_variants:
			var reachable: Array = []
			for iteration in item.appraisal_actions.size() + 1:
				for action in item.appraisal_actions:
					if _contains_all(reachable, action.requires_clues):
						for clue_id in action.reveals:
							if clue_id in variant.clue_ids and clue_id not in reachable: reachable.append(clue_id)
			for clue_id in variant.clue_ids:
				if clue_id not in reachable: _error(issues, item.id, "循环依赖或不可达线索：" + clue_id)
	for customer: CustomerDefinition in catalog.get_all("customers"):
		if customer.terms == null: continue
		var t := customer.terms
		if customer.patience < 1 or customer.max_quote_rounds < 1 or t.failed_quote_cost < 1 or t.false_pressure_cost < 1 or t.counter_step < 1 or not is_finite(t.ask_multiplier) or t.ask_multiplier <= 0 or not is_finite(t.reserve_ratio) or t.reserve_ratio <= 0 or t.reserve_ratio > 1:
			_error(issues, customer.id, "议价参数无效。")
		var question_ids: Array = []
		for question in customer.questions:
			if question.id.is_empty() or question.id in question_ids or question.minutes <= 0: _error(issues, customer.id, "询问ID/耗时无效。")
			question_ids.append(question.id)
	for run: RunDefinition in catalog.get_all("runs"):
		var slot_ids: Array = []
		for slot in run.customer_slots:
			if slot.id.is_empty() or slot.id in slot_ids: _error(issues, run.id, "来访槽ID重复或为空。")
			slot_ids.append(slot.id)
			if slot.night_min < 1 or slot.night_max < slot.night_min or slot.night_min > run.total_nights: _error(issues, run.id, "来访夜次区间无效。")
			if slot.arrival < 0 or slot.arrival >= run.night_minutes or slot.arrival % run.time_step != 0:
				_error(issues, run.id, "来访时刻无效。")
			var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
			if customer == null or customer.terms == null:
				_error(issues, run.id, "缺少可交易顾客：" + slot.customer_id)
				continue
			var terms := customer.terms
			for minutes in [terms.wait_minutes, terms.quote_minutes, terms.pressure_minutes, terms.reject_minutes]:
				if minutes <= 0 or minutes % run.time_step != 0: _error(issues, customer.id, "顾客耗时未匹配步长。")
			for question in customer.questions:
				if question.minutes % run.time_step != 0: _error(issues, customer.id, "询问耗时未匹配步长。")
			if customer.item_pool.is_empty() or (not slot.item_id.is_empty() and slot.item_id not in customer.item_pool):
				_error(issues, run.id, "携带物品不在顾客池中。")
			var item_ids: Array = customer.item_pool if slot.item_id.is_empty() else [slot.item_id]
			for item_id in item_ids:
				var item := catalog.get_definition("items", item_id) as ItemDefinition
				if item == null or item.possible_variants.is_empty() or item.appraisal_actions.is_empty():
					_error(issues, run.id, "来访物品无可玩鉴定定义。")
					continue
				if not slot.variant_id.is_empty() and item.find_variant(slot.variant_id) == null:
					_error(issues, run.id, "缺失指定变体。")
				for action in item.appraisal_actions:
					if action.minutes % run.time_step != 0: _error(issues, item.id, "鉴定耗时未匹配步长。")
					if not action.required_tool.is_empty() and action.required_tool not in run.tools: _error(issues, run.id, "缺少所需鉴定工具。")
	return issues

static func _contains_all(values: Array, required: Array) -> bool:
	for entry in required:
		if entry not in values: return false
	return true

static func _error(issues: Array, at: String, message: String) -> void:
	issues.append(ContentIssue.new("error", "invalid_counter_content", "ContentCatalog", at, message))
