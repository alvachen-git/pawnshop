class_name TradeReceiptModel
extends RefCounted

static func batch(day: DayController, catalog: ContentCatalog, first: int) -> Dictionary:
	if first < 0 or first >= day.state.ledger_entries.size(): return {}
	var first_entry: Dictionary = day.state.ledger_entries[first]
	if first_entry.get("kind", "") != "sale": return {}
	var first_sale := _sale_for_entry(day, first_entry)
	var batch_id := String(first_sale.get("batch_id", ""))
	if batch_id.is_empty(): return {}
	var trip: Dictionary = {}
	for candidate in day.state.sale_batches:
		if candidate.get("id", "") == batch_id:
			trip = candidate
			break
	if trip.is_empty(): return {}
	var entries: Array[Dictionary] = []
	for entry in day.state.ledger_entries:
		if entry.get("kind", "") != "sale" or entry.get("item_instance_id", "") not in trip.item_ids: continue
		var sale := _sale_for_entry(day, entry)
		if sale.get("batch_id", "") == batch_id: entries.append(entry)
	if entries.size() != trip.item_ids.size(): return {}
	var receipt := build(day, catalog, entries[0])
	if receipt.is_empty(): return {}
	var buyer := catalog.get_definition("buyers", trip.buyer_id) as BuyerDefinition
	if buyer == null: return {}
	var total := 0
	var cost := 0
	var lines: PackedStringArray = []
	for row in entries:
		var item := InventoryManager.new().find(day.state, row.item_instance_id)
		if item == null: return {}
		var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
		if definition == null: return {}
		var base := maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))
		total += row.amount
		cost += item.acquisition_price
		lines.append("%s · 收%d / 成本%d / 盈亏%+d\n基础报价%d · 来源溢价%d" % [definition.display_name, row.amount, item.acquisition_price, row.realized_profit, base, row.amount - base])
	receipt.item = "%s · 交货%d件" % [buyer.display_name, trip.item_ids.size()]
	receipt.item_asset = ""
	receipt.images = []
	receipt.amount = total
	receipt.before = entries[0].balance - entries[0].amount
	receipt.after = entries.back().balance
	receipt.note = "往返20分钟，货款已收妥。"
	receipt.detail = "总成本%d · 已实现盈亏%+d 银元\n未扣来源调查费与每日息费。\n\n%s" % [cost, total - cost, "\n\n".join(lines)]
	return receipt

# Only committed, player-visible facts. No hidden variant, true value or margin
# forecast is exposed by buying an item. This receipt is not a save checkpoint.
static func build(day: DayController, catalog: ContentCatalog, entry: Dictionary) -> Dictionary:
	var titles := {"acquisition": "收购成交", "pawn_loan": "活当办妥", "sale": "出售成交", "redemption": "赎当办妥", "extension": "续当办妥", "provenance_inquiry": "来源调查结清"}
	if catalog == null or not titles.has(entry.kind): return {}
	var item := InventoryManager.new().find(day.state, entry.item_instance_id)
	if item == null: return {}
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	var note: String = {"acquisition": "货已收进库存，收购款已付清。", "pawn_loan": "当票已开，在当物品留铺保管。", "sale": "货已交给买家，货款收妥。", "redemption": "赎金收妥，原物已交还当户。", "extension": "续当费收妥，原物继续留铺。", "provenance_inquiry": ProvenanceService.describe(item)}[entry.kind]
	var detail := "收购支出为进货成本，出售后再结盈亏。" if entry.kind == "acquisition" else ""
	if entry.kind == "sale": detail = "进货成本 %d 银元 · 本笔已实现盈亏 %+d 银元" % [item.acquisition_price, entry.realized_profit]
	if entry.kind == "provenance_inquiry": detail = ProvenanceService.result_text(item, definition) + "\n调查费记入经营费用，原始成本不变。"
	if entry.kind == "sale" and not item.provenance.is_empty():
		var sale := _sale_for_entry(day, entry)
		var buyer := catalog.get_definition("buyers", sale.get("buyer_id", "")) as BuyerDefinition
		if buyer != null:
			var base := maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))
			detail += "\n基础报价 %d · 来源溢价 %d 银元" % [base, ProvenanceService.premium(item, buyer, base)]
	var due_night := 0
	for ticket in day.state.pawn_tickets:
		if ticket.item_instance_id == item.instance_id and entry.kind in ["pawn_loan", "extension"]:
			# Reconstruct the date on THIS receipt, not the ticket's later renewal.
			due_night = ticket.due_night
			if not ticket.extensions.is_empty():
				due_night = ticket.extensions[0].previous_due
				if entry.kind == "extension":
					for renewal in ticket.extensions:
						if renewal.night == entry.night and renewal.minute == entry.minute: due_night = renewal.new_due
			detail = "第%d夜到期 · 约定赎金 %d 银元\n在当物品不可出售。" % [due_night, ticket.redemption_amount]
			if EarlyRedemption.enabled(day.definition) and ticket.terms_id == FamiliarStories.TERMS: detail += "\n" + EarlyRedemption.AGREEMENT
	if SevenNightPlan.enabled(day.definition) and entry.kind in ["acquisition", "pawn_loan"]:
		var row := VarietySaveCodec.selection(day.state, item.source_visit_id)
		if not row.is_empty() and not row.context_id.is_empty() and not row.has("night_policy"): note += "\n" + String(SevenNightPlan.context(day.definition, row.context_id).voice.completed)
	var late := VarietySaveCodec.selection(day.state, item.source_visit_id)
	if entry.kind == "acquisition" and late.get("night_policy") == "wet_cloth":
		note += "\n那块湿包布留在了柜边。"
		if late.night_aftermath == "item": detail += "\n货面浮起湿灰，暂不能交货。封铺前到营业页按旧规封存包布，需20分钟。"
		elif late.night_aftermath == "haunt": detail += "\n身后响起一声滴水，影子慢了半步。须在封铺前按旧规封存包布，需20分钟。"
		else: detail += "\n包布里轻轻叹了一声。再听，柜上已经没有声响。"
	var images: Array = []
	for scenario in day.definition.trade_scenarios:
		if item.source_visit_id.ends_with("/" + scenario.slot_id) or (not day.definition.variety.is_empty() and scenario.item_id == item.definition_id):
			for row in scenario.images:
				if row.id == "front" and row.requires_clues.is_empty(): images.append(row.duplicate(true))
	return {"id": entry.transaction_id, "title": titles[entry.kind], "kind": entry.kind,
		"item": definition.display_name, "item_asset": definition.visual_asset_id, "images": images,
		"amount": entry.amount, "before": entry.balance - entry.amount, "after": entry.balance,
		"clock": "第%d夜 · %s" % [entry.night, TimeController.clock_text(day.definition.opening_minute, entry.minute)],
		"note": note, "detail": detail, "due_night": due_night, "destination": "ledger" if entry.kind in ["pawn_loan", "redemption", "extension"] else "inventory",
		"followup": "risk" if not definition.ghost_rule_id.is_empty() and entry.kind in ["acquisition", "pawn_loan"] else "",
		"can_inspect": day.state.phase == &"open" and day.state.pending_event_id.is_empty() and day.state.risk_pending.is_empty()}


static func _sale_for_entry(day: DayController, entry: Dictionary) -> Dictionary:
	for sale in day.state.sale_records:
		if sale.get("item_instance_id", "") == entry.get("item_instance_id", ""):
			return sale
	return {}
