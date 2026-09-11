class_name GoodsSaveCodec
extends RefCounted

static func owned_at(data: Dictionary, item: ItemInstance, bought: Dictionary, night: int, minute: int) -> bool:
	if night < bought.night or (night == bought.night and minute < bought.minute): return false
	if item.acquisition_type == "pawn":
		var found := false
		for ticket in data.get("pawn_tickets", []):
			if not ticket is Dictionary: return false
			if ticket.get("item_instance_id") != item.instance_id: continue
			if ticket.get("status") != "defaulted" or not RunSchema.integer(ticket.get("closed_night")) or night <= ticket.closed_night: return false
			found = true
		if not found: return false
	for batch in data.get("sale_batches", []):
		if not batch is Dictionary or not batch.get("item_ids") is Array: return false
		if item.instance_id in batch.item_ids and (batch.night < night or (batch.night == night and batch.start <= minute)): return false
	return true

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog, bought: Dictionary) -> String:
	if not data.get("expertise_history", []) is Array: return "行家复核历史无效。"
	if not GoodsExpertise.enabled(run):
		return "旧局混入复核历史。" if not data.get("expertise_history", []).is_empty() or state.inventory_instances.any(func(i: ItemInstance) -> bool: return i.expert_reviewed or not i.goods.is_empty()) else ""
	if not data.has("expertise_history"): return "缺少行家历史。"
	var seen := []; var reviewed := []; var last := -1
	for raw in data.expertise_history:
		if not raw is Dictionary or raw.size() != 8 or not CounterSaveCodec._integers(raw, ["night", "start", "minute", "fee"]) or not CounterSaveCodec._text_fields(raw, ["id", "action", "result"]) or not CounterSaveCodec._string_array(raw.get("item_ids")): return "复核记录结构无效。"
		if raw.action not in ["fan", "pair"] or raw.item_ids.size() != (1 if raw.action == "fan" else 2): return "复核对象数不符。"
		var ids: Array = raw.item_ids.duplicate(); ids.sort()
		if ids != raw.item_ids or ids in seen or raw.id != "expertise/%d" % (state.expertise_history.size() + 1): return "复核重复或顺序无效。"
		var fee := 6 if raw.action == "fan" else 4; var minutes := 20 if raw.action == "fan" else 10
		if raw.fee != fee or raw.night < 1 or raw.night > SaveTimeline.trading_nights(state) or raw.start < 0 or int(raw.start) % run.time_step != 0 or raw.minute != raw.start + minutes or raw.minute >= run.night_minutes or raw.minute > SaveTimeline.closing(state, int(raw.night)): return "复核费用或时刻不符。"
		var stamp := int(raw.night) * (run.night_minutes + 1)
		if stamp + raw.start < last: return "复核耗时重叠。"
		last = stamp + int(raw.minute)
		for id in ids:
			var item := InventoryManager.new().find(state, id)
			if item == null or item.definition_id != (GoodsExpertise.FAN if raw.action == "fan" else GoodsExpertise.CUP) or not owned_at(data, item, bought[item.source_visit_id], int(raw.night), int(raw.start)): return "复核时并未持有对应现货。"
		var first := InventoryManager.new().find(state, ids[0])
		var result := first.selected_variant_id if raw.action == "fan" else ("matched" if GoodsExpertise.paired(first, InventoryManager.new().find(state, ids[1])) else "different")
		if raw.result != result: return "复核结论与原物不符。"
		if raw.action == "fan": reviewed.append(ids[0])
		for key in ["scenario_history", "provenance_history", "sale_batches", "pawn_returns", "event_history"]:
			if not data.get(key, []) is Array: return "复核所需历史无效。"
			for h in data.get(key, []):
				if not h is Dictionary or not CounterSaveCodec._integers(h, ["night", "minute"]): return "复核关联时刻无效。"
				if h.night != raw.night: continue
				if key == "pawn_returns":
					if raw.start < h.minute: return "返当未办结前不能复核。"
					continue
				var start: Variant = h.get("start", h.get("offered_minute", h.minute))
				if not RunSchema.integer(start): return "关联起始时刻无效。"
				if start < raw.minute and h.minute > raw.start: return "复核与其他行动耗时重叠。"
		var row: Dictionary = raw.duplicate(true)
		for k in ["night", "start", "minute", "fee"]: row[k] = int(row[k])
		state.expertise_history.append(row); seen.append(ids)
	for item in state.inventory_instances:
		if item.expert_reviewed != (item.instance_id in reviewed): return "库存认证缺少复核记录。"
	for record in state.preparation_history:
		if record.action != "seek": continue
		var item := InventoryManager.new().find(state, record.category)
		if item == null or item.acquired_night >= record.night or not owned_at(data, item, bought[item.source_visit_id], int(record.night), -1): return "寻货时没有对应自有茶盏。"
		if not data.scenario_history.any(func(h: Dictionary) -> bool: return h.visit_id == item.source_visit_id and h.command == "appraise" and h.detail == "observe" and h.ok and h.night < record.night): return "尚未辨纹样就寻配。"
	return ""

static func sale_bonus(row: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> int:
	var batch := MarketSaveCodec.batch(state, row.get("batch_id", ""))
	if batch.is_empty() or not GoodsExpertise.enabled(run): return 0
	var pairs: Array = batch.get("pairs", [])
	var buyer := catalog.get_definition("buyers", row.buyer_id) as BuyerDefinition
	for ids in pairs:
		if not ids is Array: return -1
		var certificate := GoodsExpertise.certificate(state, ids)
		if certificate.is_empty() or certificate.night > batch.night or (certificate.night == batch.night and certificate.minute > batch.start): return -1
	var checked := GoodsExpertise.pair_bonus(state, catalog, buyer, batch.item_ids, pairs, false)
	return -1 if not checked.error.is_empty() else int(checked.bonuses.get(row.item_instance_id, 0))

static func validate_timing(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	# Reuse the established event/mirror/risk interval checks without persisting
	# a second source-history representation of expert work.
	var original := state.provenance_history
	var combined: Array[Dictionary] = original.duplicate(true)
	for row in state.expertise_history: combined.append(row)
	state.provenance_history = combined
	var error := VarietySaveCodec.validate_timing(state, run, catalog)
	state.provenance_history = original
	return error
