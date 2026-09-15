class_name CounterSaveCodec
extends RefCounted

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	for key in ["inventory_instances", "ledger_entries", "visit_history"]:
		if not data.get(key) is Array: return "缺少M2库存/流水/来访历史。"
	if catalog == null and (not data.inventory_instances.is_empty() or not data.visit_history.is_empty() or not data.ledger_entries.is_empty()): return "恢复交易存档需要完整内容目录。"
	var completed_nights := state.current_night_index - (1 if state.phase == &"pre_open" else 0)
	var expected_visits: Dictionary = {}
	if catalog != null:
		for index in completed_nights:
			var fixture := RunState.create(run)
			fixture.current_night_index = index + 1
			fixture.run_seed = state.run_seed
			fixture.preparation_history = state.preparation_history.duplicate(true)
			FamiliarStories.attach_context(fixture, data)
			CustomerManager.new().prepare_night(fixture, run, catalog)
			var delay := PawnReturnService.delay_for(data, index + 1, catalog)
			for expected in fixture.visits:
				expected.arrival += delay
				expected.expires_at += delay
				expected_visits[expected.visit_id] = expected
		if data.visit_history.size() != expected_visits.size(): return "夜末来访历史不完整。"
	var bought: Dictionary = {}
	var history_ids: Array = []
	for entry in data.visit_history:
		if not entry is Dictionary or not _text_fields(entry, ["visit_id", "customer_id", "outcome"]) or not _integers(entry, ["night", "minute"]): return "来访历史结构无效。"
		if entry.night < 1 or entry.night > completed_nights or entry.minute < 0 or entry.minute > run.night_minutes or int(entry.minute) % run.time_step != 0: return "来访历史时刻无效。"
		if entry.outcome not in CounterReadModels.OUTCOMES or entry.visit_id in history_ids or not catalog.has_definition("customers", entry.customer_id): return "来访历史引用或结果无效。"
		var found_slot := false
		for slot in run.customer_slots:
			if entry.visit_id == "%s/%d/%s" % [run.id, int(entry.night), slot.id] and (slot.customer_id == entry.customer_id or not run.variety.is_empty()): found_slot = true
		if not expected_visits.has(entry.visit_id): return "来访不属于该夜编排。"
		if OpeningPreparation.enabled(run) and expected_visits.has(entry.visit_id) and entry.visit_id.ends_with("/prep_extra"): found_slot = true
		if not found_slot: return "来访ID不属于当前运行配置。"
		var planned: CustomerVisit = expected_visits[entry.visit_id]
		if entry.outcome in ["redeemed_early", "redemption_deferred"] and (not EarlyRedemption.enabled(run) or not EarlyRedemption.is_visit(planned)): return "提前取赎结果不属于这次来访。"
		if planned.customer_id != entry.customer_id: return "来访人物与抽选结果不符。"
		if entry.outcome in ["bought", "pawned"]:
			var customer := catalog.get_definition("customers", planned.customer_id) as CustomerDefinition
			var quote_start := int(entry.minute) - customer.terms.quote_minutes
			if entry.minute < planned.arrival or entry.minute >= run.night_minutes: return "成交不在来访窗口内。"
			if entry.minute >= planned.expires_at and (quote_start < planned.arrival or quote_start >= planned.expires_at): return "报价未在客人离场前开始。"
		history_ids.append(entry.visit_id)
		if entry.outcome in ["bought", "pawned"]: bought[entry.visit_id] = entry
		state.visit_history.append({"visit_id": String(entry.visit_id), "customer_id": String(entry.customer_id), "night": int(entry.night), "minute": int(entry.minute), "outcome": String(entry.outcome)})
	var inventory_ids: Dictionary = {}
	var acquired_visits: Array = []
	for entry in data.inventory_instances:
		if not entry is Dictionary or not _text_fields(entry, ["instance_id", "definition_id", "selected_variant_id", "judgement", "source_visit_id"]) or not _integers(entry, ["acquisition_price", "acquired_night"]): return "库存记录结构无效。"
		var item := catalog.get_definition("items", entry.definition_id) as ItemDefinition
		if item == null or item.find_variant(entry.selected_variant_id) == null: return "库存物品或变体ID失效。"
		if entry.instance_id in inventory_ids or entry.source_visit_id in acquired_visits or entry.acquisition_price <= 0 or entry.acquired_night < 1 or entry.acquired_night > completed_nights: return "库存重复或收购记录无效。"
		if entry.judgement not in CounterReadModels.JUDGEMENTS or not bought.has(entry.source_visit_id) or bought[entry.source_visit_id].night != entry.acquired_night or entry.instance_id != "item/" + entry.source_visit_id: return "库存与成交历史不一致。"
		var planned: CustomerVisit = expected_visits[entry.source_visit_id]
		if entry.definition_id != planned.item.definition_id or entry.selected_variant_id != planned.item.selected_variant_id: return "库存与固定seed预生成物品不一致。"
		var instance := ItemInstance.new()
		if not entry.get("provenance", {}) is Dictionary: return "来源字段结构无效。"
		if not entry.get("goods", {}) is Dictionary or not entry.get("expert_reviewed", false) is bool: return "商品复核字段无效。"
		var normalized_goods: Dictionary = entry.duplicate(true)
		if not VarietySaveCodec.normalize_goods(normalized_goods) or normalized_goods.get("goods", {}) != planned.item.goods: return "茶盏制式与来访不符。"
		instance.goods = planned.item.goods.duplicate(true)
		instance.expert_reviewed = entry.get("expert_reviewed", false)
		instance.provenance = entry.get("provenance", {}).duplicate(true)
		if run.variety.is_empty() and not instance.provenance.is_empty(): return "旧物不能混入新来源。"
		instance.instance_id = entry.instance_id
		instance.definition_id = entry.definition_id
		instance.selected_variant_id = entry.selected_variant_id
		instance.judgement = entry.judgement
		instance.acquisition_price = int(entry.acquisition_price)
		instance.acquired_night = int(entry.acquired_night)
		instance.source_visit_id = entry.source_visit_id
		if entry.get("acquisition_type") not in ["purchase", "pawn"] or entry.get("ownership_state") not in (["owned", "pledged", "sold", "redeemed", "transferred", "lost"] if state.night_market_enabled else ["owned", "pledged", "sold", "redeemed", "transferred"]): return "库存权属无效。"
		if (entry.acquisition_type == "pawn") != (bought[entry.source_visit_id].outcome == "pawned"): return "当票与交易模式不符。"
		instance.acquisition_type = entry.acquisition_type
		instance.ownership_state = entry.ownership_state
		if not _string_array(entry.get("revealed_clue_ids")) or not _string_array(entry.get("completed_action_ids")): return "库存证据字段无效。"
		var attainable: Variant = MirrorSaveCodec.evidence(data.get("mirror_history"), entry, item, run)
		if attainable == null or attainable != entry.revealed_clue_ids: return "库存证据与鉴定或窥镜来源不一致。"
		instance.revealed_clue_ids = entry.revealed_clue_ids.duplicate()
		instance.completed_action_ids = entry.completed_action_ids.duplicate()
		inventory_ids[instance.instance_id] = instance
		acquired_visits.append(instance.source_visit_id)
		state.inventory_instances.append(instance)
	if acquired_visits.size() != bought.size(): return "成交后缺少库存。"
	var source_error := VarietySaveCodec.restore_sources(data, state, run, catalog, expected_visits, bought)
	if not source_error.is_empty(): return source_error
	var goods_error := GoodsSaveCodec.restore(data, state, run, catalog, bought)
	if not goods_error.is_empty(): return goods_error
	return CommerceSaveCodec.restore(data, state, run, catalog, bought)

static func _integers(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not RunSchema.integer(data.get(key)) or abs(data[key]) > 2147483647: return false
	return true

static func _text_fields(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not data.get(key) is String or data[key].is_empty(): return false
	return true

static func _string_array(value: Variant) -> bool:
	if not value is Array: return false
	var seen: Array = []
	for entry in value:
		if not entry is String or entry.is_empty() or entry in seen: return false
		seen.append(entry)
	return true
