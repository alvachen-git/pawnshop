class_name TradeScenarioSchema
extends RefCounted

static func validate(row: Dictionary, path: String, at: String) -> Array:
	var issues: Array = []
	if not row.get("randomize_seed", false) is bool: CounterDomainValidator._error(issues, at, "随机种子开关须为布尔值。")
	var scenarios: Variant = row.get("trade_scenarios", [])
	if not scenarios is Array:
		CounterDomainValidator._error(issues, at, "交易情境须为数组。")
		return issues
	CounterSchema._rows(scenarios, {"id": "text", "slot_id": "text", "item_id": "text", "variant_ids": "strings", "situations": "strings", "reactions": "strings", "introduction": "text", "concession_question": "string", "concession_amount": "nonnegative", "concession_minutes": "positive", "urgent_wait_minutes": "positive"}, path, at, issues)
	for scenario in scenarios:
		if not scenario is Dictionary: continue
		CounterSchema._rows(scenario.get("questions"), {"id": "text", "prompt": "text", "minutes": "positive", "requires_questions": "strings", "requires_clues": "strings", "pressure_clue": "string", "patience_cost": "nonnegative"}, path, at + ".questions", issues)
		CounterSchema._rows(scenario.get("images"), {"id": "text", "label": "text", "path": "string", "requires_clues": "strings"}, path, at + ".images", issues)
		if scenario.get("questions") is Array:
			for q in scenario.questions:
				if not q is Dictionary: continue
				if not q.get("answers") is Dictionary or q.answers.is_empty(): CounterDomainValidator._error(issues, at, "问答缺少回答映射。")
				else:
					for key in q.answers:
						if not key is String or not q.answers[key] is String or q.answers[key].is_empty(): CounterDomainValidator._error(issues, at, "回答映射须为非空文本。")
		if not scenario.get("benefit_groups") is Dictionary: CounterDomainValidator._error(issues, at, "证据收益组须为映射。")
		else:
			for key in scenario.benefit_groups:
				if not key is String or not scenario.benefit_groups[key] is String or scenario.benefit_groups[key].is_empty(): CounterDomainValidator._error(issues, at, "证据收益组无效。")
	return issues

static func domain(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for run: RunDefinition in catalog.get_all("runs"):
		var slots: Array = []
		for scenario in run.trade_scenarios:
			if scenario.slot_id in slots: CounterDomainValidator._error(issues, scenario.id, "来访不能绑定多个交易情境。")
			slots.append(scenario.slot_id)
			var matched := not run.variety.is_empty()
			for slot in run.customer_slots:
				if slot.id == scenario.slot_id:
					matched = slot.item_id == scenario.item_id and slot.variant_id.is_empty() and slot.night_min == slot.night_max
			if not matched: CounterDomainValidator._error(issues, scenario.id, "情境须绑定单夜、同物品、无固定变体的来访。")
			var item := catalog.get_definition("items", scenario.item_id) as ItemDefinition
			if item == null:
				CounterDomainValidator._error(issues, scenario.id, "情境物品不存在。")
				continue
			if scenario.variant_ids.is_empty() or scenario.situations.is_empty() or scenario.reactions.is_empty(): CounterDomainValidator._error(issues, scenario.id, "情境抽选池不能为空。")
			for id in scenario.variant_ids:
				if item.find_variant(id) == null: CounterDomainValidator._error(issues, scenario.id, "情境变体不存在。")
			for id in scenario.situations:
				if id not in ["ordinary", "urgent"]: CounterDomainValidator._error(issues, scenario.id, "未知卖家处境。")
			for id in scenario.reactions:
				if id not in ["admit", "explain", "evade"]: CounterDomainValidator._error(issues, scenario.id, "未知反应。")
			for cost in [scenario.concession_minutes, scenario.urgent_wait_minutes]:
				if cost % run.time_step != 0 or cost > run.night_minutes: CounterDomainValidator._error(issues, scenario.id, "情境耗时不符。")
			if scenario.concession_amount > 0 and scenario.find_question(scenario.concession_question) == null: CounterDomainValidator._error(issues, scenario.id, "缺少核实处境的问题。")
			for clue in scenario.benefit_groups:
				if item.find_clue(clue) == null: CounterDomainValidator._error(issues, scenario.id, "收益组证据不存在。")
			var reachable: Array = []
			for pass_index in scenario.questions.size() + 1:
				for q in scenario.questions:
					if CounterDomainValidator._contains_all(reachable, q.requires_questions) and q.id not in reachable: reachable.append(q.id)
			for q in scenario.questions:
				if q.id not in reachable or q.minutes % run.time_step != 0 or q.minutes > run.night_minutes: CounterDomainValidator._error(issues, scenario.id, "追问循环依赖或耗时无效。")
				for clue in q.requires_clues:
					if item.find_clue(clue) == null: CounterDomainValidator._error(issues, scenario.id, "追问证据不存在。")
				if not q.pressure_clue.is_empty() and (q.pressure_clue not in q.requires_clues or item.find_clue(q.pressure_clue) == null): CounterDomainValidator._error(issues, scenario.id, "质疑口供必须引用已取得的物证。")
				for variant in scenario.variant_ids:
					for situation in scenario.situations:
						for reaction in scenario.reactions:
							var sample := CustomerVisit.new()
							sample.item = ItemInstance.new()
							sample.item.selected_variant_id = variant
							sample.situation_id = situation
							sample.reaction_id = reaction
							if q.answer(sample).is_empty(): CounterDomainValidator._error(issues, scenario.id, "某种情境没有可用回答。")
			var overviews: Array = []
			for pic in scenario.images:
				if not pic.path.is_empty() and (not pic.path.begins_with("res://assets/") or not FileAccess.file_exists(pic.path)): CounterDomainValidator._error(issues, scenario.id, "物品图路径不存在或不在资源目录。")
				if pic.requires_clues.is_empty(): overviews.append(pic.id)
				for clue in pic.requires_clues:
					if item.find_clue(clue) == null: CounterDomainValidator._error(issues, scenario.id, "细节图证据不存在。")
			if overviews != ["front", "back"]: CounterDomainValidator._error(issues, scenario.id, "仅正背面可在取证前展示。")
	return issues
