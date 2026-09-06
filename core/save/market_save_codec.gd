class_name MarketSaveCodec
extends RefCounted

static func restore(data: Dictionary, state: RunState, run: RunDefinition) -> String:
	for key in ["market_history", "sale_batches"]:
		if not data.get(key, []) is Array: return "行情或出货批次结构无效。"
	if run.market.is_empty():
		return "旧局不能混入批量出货记录。" if not data.get("market_history", []).is_empty() or not data.get("sale_batches", []).is_empty() else ""
	if not data.has("market_history") or not data.has("sale_batches"): return "缺少行情或出货批次。"
	MarketService.sync(state, run)
	var history: Array = []
	for row in data.market_history:
		if not row is Dictionary or not CounterSaveCodec._integers(row, ["night", "minute"]): return "行情消息时刻无效。"
		var copy: Dictionary = row.duplicate(true)
		copy.night = int(copy.night)
		copy.minute = int(copy.minute)
		history.append(copy)
	if history != state.market_history: return "行情历史与本局消息不符。"
	var last_end := -1
	var sold: Array = []
	for row in data.sale_batches:
		if not row is Dictionary or row.size() != 7 or not CounterSaveCodec._text_fields(row, ["id", "buyer_id", "market_id"]) or not CounterSaveCodec._integers(row, ["night", "start", "minute"]) or not CounterSaveCodec._string_array(row.get("item_ids")): return "出货批次结构无效。"
		if row.id != "batch/%d" % (state.sale_batches.size() + 1) or row.item_ids.is_empty() or row.night < 1 or row.night > state.summaries.size() or row.start < 0 or int(row.start) % run.time_step != 0 or row.minute != row.start + int(run.market.trip_minutes) or row.minute >= run.night_minutes or row.minute > state.summaries[int(row.night) - 1].closed_at: return "出货批次时刻、货单或顺序无效。"
		var stamp := int(row.night) * (run.night_minutes + 1)
		if stamp + int(row.start) < last_end: return "多趟出货耗时重叠。"
		last_end = stamp + int(row.minute)
		if row.market_id != MarketService.current(run, state.run_seed, int(row.night), int(row.start)).id: return "出货没有使用出发时行情。"
		for id in row.item_ids:
			if id in sold: return "同一货物不能重复出货。"
			sold.append(id)
		var copy: Dictionary = row.duplicate(true)
		for key in ["night", "start", "minute"]: copy[key] = int(copy[key])
		state.sale_batches.append(copy)
	return ""

static func batch(state: RunState, id: String) -> Dictionary:
	for row in state.sale_batches:
		if row.id == id: return row
	return {}

static func sale_reason(row: Dictionary, state: RunState, run: RunDefinition, buyer: BuyerDefinition, item: ItemDefinition) -> String:
	if run.market.is_empty(): return ""
	if not row.get("batch_id") is String: return "销售缺少出货批次。"
	var trip := batch(state, row.batch_id)
	if trip.is_empty() or trip.buyer_id != buyer.id or trip.night != row.night or trip.minute != row.minute or row.item_instance_id not in trip.item_ids: return "销售与出货批次不符。"
	if MarketService.is_special(run, buyer):
		var demand := MarketService.demand(run, MarketService.current(run, state.run_seed, trip.night, trip.start))
		if item.category != demand.category: return "所售货物不合当时偏好。"
	return ""

static func validate_timing(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if run.market.is_empty(): return ""
	var data := state.to_read_model()
	for trip in state.sale_batches:
		var sales := state.sale_records.filter(func(row: Dictionary) -> bool: return row.get("batch_id", "") == trip.id)
		if sales.map(func(row: Dictionary) -> String: return row.item_instance_id) != trip.item_ids: return "批次货单与逐件销售不符。"
		var delay := PawnReturnService.delay_for(data, trip.night, catalog)
		for visit in VarietyService.plan(run, catalog, state.run_seed):
			if visit.night != trip.night: continue
			var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
			var arrival: int = int(visit.arrival) + delay
			if arrival > trip.start or arrival + customer.terms.wait_minutes <= trip.start: continue
			var ended := false
			for h in state.visit_history:
				if h.visit_id == visit.visit_id and h.minute <= trip.start: ended = true
			if not ended: return "客人仍在店里时不能交货。"
		for h in state.pawn_returns:
			if h.night == trip.night and (h.status != "completed" or h.minute > trip.start): return "原当户未办结前不能交货。"
		for history in [state.scenario_history, state.provenance_history]:
			for h in history:
				if h.night == trip.night and h.start < trip.minute and h.minute > trip.start: return "出货与店内行动耗时重叠。"
		for h in state.event_history:
			if h.night == trip.night and h.offered_minute < trip.minute and h.minute > trip.start: return "出货与剧情办理耗时重叠。"
		for h in state.risk_history:
			if h.night != trip.night or h.action not in ["cover", "uncover"]: continue
			var item := InventoryManager.new().find(state, h.item_id)
			var rule := RiskManager.new(catalog).rule_for(item)
			var cost := rule.cover_minutes if h.action == "cover" else rule.uncover_minutes
			if h.minute > trip.start and h.minute - cost < trip.minute: return "出货与存放处理耗时重叠。"
		for h in state.mirror_history:
			if h.night != trip.night: continue
			var encounter := MirrorEncounterService.find_definition(run, h.encounter_id)
			var cost := encounter.peek_minutes if h.action.begins_with("peek") else (encounter.pursue_minutes if h.action.begins_with("pursue") else 0)
			if h.minute > trip.start and h.minute - cost < trip.minute: return "出货与窥镜耗时重叠。"
	return ""
