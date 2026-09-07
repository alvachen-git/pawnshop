class_name CommerceSaveCodec
extends RefCounted

# Reconstruct expected postings from transaction records, then reconcile every cent.
static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog, acquisitions: Dictionary) -> String:
	if not data.get("pawn_tickets") is Array or not data.get("sale_records") is Array: return "缺少M3当票/销售记录。"
	if catalog == null and (not data.pawn_tickets.is_empty() or not data.sale_records.is_empty()): return "恢复当票需要内容目录。"
	var completed := SaveTimeline.trading_nights(state)
	var settled := state.summaries.size()
	var expected: Dictionary = {}
	var tickets: Dictionary = {}
	var sales: Dictionary = {}
	var inventory := InventoryManager.new()
	for item in state.inventory_instances:
		var history: Dictionary = acquisitions[item.source_visit_id]
		var is_pawn := item.acquisition_type == "pawn"
		_post(expected, ("loan/" if is_pawn else "purchase/") + item.source_visit_id, item.instance_id, item.acquired_night, int(history.minute), -item.acquisition_price, "pawn_loan" if is_pawn else "acquisition", 0)
	for row in data.pawn_tickets:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["ticket_id", "terms_id", "customer_id", "item_instance_id", "source_visit_id", "status"]) or not CounterSaveCodec._integers(row, ["principal", "started_night", "due_night", "redemption_amount", "closed_night", "closed_minute"]) or not row.get("extensions") is Array: return "当票结构无效。"
		var item := inventory.find(state, row.item_instance_id)
		var terms := catalog.get_definition("pawn_terms", row.terms_id) as PawnTermsDefinition
		var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
		if item == null or terms == null or customer == null or item.instance_id in tickets: return "当票引用失效或重复。"
		if item.acquisition_type != "pawn" or row.source_visit_id != item.source_visit_id or row.ticket_id != "ticket/" + item.source_visit_id or row.principal != item.acquisition_price or row.started_night != item.acquired_night or (customer.pawn_terms_id != terms.id and run.variety.is_empty()) or acquisitions[item.source_visit_id].customer_id != customer.id: return "当票与放款交易不一致。"
		if row.redemption_amount != row.principal + ceili(row.principal * terms.redemption_fee_ratio): return "赎金与当约不一致。"
		if not row.get("person", {}) is Dictionary: return "当户身份结构无效。"
		if not run.variety.is_empty():
			var planned := VarietySaveCodec.selection(state, row.source_visit_id)
			if planned.is_empty() or planned.terms_id != row.terms_id or planned.person != row.get("person", {}): return "当户身份或当约与出票来访不符。"
		elif not row.get("person", {}).is_empty(): return "旧票混入新身份。"
		var due := int(row.started_night) + terms.term_nights
		if row.extensions.size() > 1 or (not row.extensions.is_empty() and terms.return_mode != "extend_once"): return "非法续当记录。"
		var ticket := PawnTicket.new()
		ticket.person = row.get("person", {}).duplicate(true)
		for key in ["ticket_id", "terms_id", "customer_id", "item_instance_id", "source_visit_id", "status"]: ticket.set(key, String(row[key]))
		for key in ["principal", "started_night", "due_night", "redemption_amount", "closed_night", "closed_minute"]: ticket.set(key, int(row[key]))
		for extension in row.extensions:
			if not extension is Dictionary or not CounterSaveCodec._integers(extension, ["night", "minute", "fee", "previous_due", "new_due"]): return "续当记录结构无效。"
			if extension.night != due or extension.night > completed or extension.previous_due != due or extension.new_due != due + terms.extension_nights or extension.fee != ceili(ticket.principal * terms.extension_fee_ratio) or not _return_time(extension.minute, int(extension.night), terms, terms.extend_minutes, run, state): return "续当与到访窗口或费用不符。"
			var normalized := {}
			for key in ["night", "minute", "fee", "previous_due", "new_due"]: normalized[key] = int(extension[key])
			ticket.extensions.append(normalized)
			_post(expected, "extend/" + ticket.ticket_id, item.instance_id, int(extension.night), int(extension.minute), int(extension.fee), "extension", int(extension.fee))
			due += terms.extension_nights
		if ticket.due_night != due: return "当票期限无法对账。"
		match ticket.status:
			"active":
				if due <= settled or ticket.closed_night != 0 or ticket.closed_minute != -1 or item.ownership_state != "pledged": return "在当状态与期限不符。"
			"defaulted":
				if due >= state.pawn_rules_start_night and terms.return_mode != "absent": return "已回访当户不能绝当。"
				if due > settled or ticket.closed_night != due or ticket.closed_minute != run.night_minutes or item.ownership_state not in ["owned", "sold"]: return "绝当状态或时刻不符。"
			"redeemed":
				if due > completed or ticket.closed_night != due or item.ownership_state != "redeemed" or terms.return_mode == "absent" or (terms.return_mode == "extend_once" and ticket.extensions.is_empty()) or not _return_time(ticket.closed_minute, ticket.closed_night, terms, terms.redeem_minutes, run, state): return "赎回没有有效当户请求。"
				_post(expected, "redeem/" + ticket.ticket_id, item.instance_id, due, ticket.closed_minute, ticket.redemption_amount, "redemption", ticket.redemption_amount - ticket.principal)
			"transferred":
				if due < state.pawn_rules_start_night or due > settled or ticket.closed_night != due or ticket.closed_minute != run.night_minutes or item.ownership_state != "transferred" or terms.return_mode != "absent": return "转当状态、期限或权属不符。"
				var price := PawnController.new().transfer_quote(ticket, terms)
				_post(expected, "transfer/" + ticket.ticket_id, item.instance_id, due, run.night_minutes, price, "pawn_transfer", price - ticket.principal)
			_: return "未知当票状态。"
		tickets[item.instance_id] = ticket
		state.pawn_tickets.append(ticket)
	var buyer_counts := {}
	for row in data.sale_records:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["item_instance_id", "buyer_id"]) or not CounterSaveCodec._integers(row, ["night", "minute", "price", "cost_basis", "realized_profit"]): return "销售记录结构无效。"
		var item := inventory.find(state, row.item_instance_id)
		var buyer := catalog.get_definition("buyers", row.buyer_id) as BuyerDefinition
		if item == null or buyer == null or buyer.id not in run.buyer_ids or item.instance_id in sales or item.ownership_state != "sold": return "销售记录引用或权属无效。"
		var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
		if row.night < item.acquired_night or row.night > completed or row.night < buyer.night_min or row.night > buyer.night_max or not _window(row.minute, buyer.window_start, buyer.window_end, buyer.action_minutes, run): return "销售不在有效买家窗口内。"
		if row.night == item.acquired_night and row.minute < acquisitions[item.source_visit_id].minute + buyer.action_minutes: return "先出售后收货。"
		if item.acquisition_type == "pawn" and (not tickets.has(item.instance_id) or tickets[item.instance_id].status != "defaulted" or row.night <= tickets[item.instance_id].closed_night): return "在当物品不可出售。"
		if not OrdinarySamplePlan.buyer_reason(state, buyer.id, definition.category, int(row.night), int(row.minute) - buyer.action_minutes).is_empty(): return "销售不符合本局收货约定。"
		if definition.category not in buyer.categories or buyer.channel not in definition.sell_channels or row.price != CommerceService.new(catalog).quote(item, buyer) or row.cost_basis != item.acquisition_price or row.realized_profit != row.price - row.cost_basis: return "销售报价、偏好或成本不符。"
		var quota := "%d/%s" % [int(row.night), buyer.id]
		buyer_counts[quota] = buyer_counts.get(quota, 0) + 1
		if buyer.capacity_per_night > 0 and buyer_counts[quota] > buyer.capacity_per_night: return "买家收货额度超限。"
		if buyer.id == PreparationService.BUYER:
			if not PreparationService.buyer_reason(state, buyer.id).is_empty() or not PreparationService.item_reason(item, buyer.id).is_empty(): return "预约销售缺少介绍或货物不符。"
		var market_error := MarketSaveCodec.sale_reason(row, state, run, buyer, definition)
		if not market_error.is_empty(): return market_error
		var normalized := {"item_instance_id": String(row.item_instance_id), "buyer_id": String(row.buyer_id)}
		if run.batch_selling: normalized.batch_id = row.batch_id
		for key in ["night", "minute", "price", "cost_basis", "realized_profit"]: normalized[key] = int(row[key])
		state.sale_records.append(normalized)
		sales[item.instance_id] = normalized
		_post(expected, "sale/" + item.instance_id, item.instance_id, int(row.night), int(row.minute), int(row.price), "sale", int(row.realized_profit))
	for item in state.inventory_instances:
		if (item.acquisition_type == "pawn") != tickets.has(item.instance_id) or (item.ownership_state == "sold") != sales.has(item.instance_id): return "缺少对应当票或销售。"
		if item.acquisition_type == "purchase" and item.ownership_state not in ["owned", "sold"]: return "收购物品权属不符。"
	for row in state.provenance_history:
		if row.action != "inquire": continue
		var item := inventory.find(state, row.item_instance_id)
		var def := catalog.get_definition("items", item.definition_id) as ItemDefinition
		_post(expected, "inquiry/" + item.instance_id, item.instance_id, row.night, row.minute, -int(def.provenance.inquiry_fee), "provenance_inquiry", 0)
	var fee_error := FeeSaveCodec.prepare(data, state, run, expected)
	if not fee_error.is_empty(): return fee_error
	var balance := run.initial_cash
	var last_time := -1
	for row in data.ledger_entries:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["transaction_id", "item_instance_id", "kind"]) or not CounterSaveCodec._integers(row, ["night", "minute", "amount", "balance", "realized_profit"]): return "流水结构无效。"
		if not expected.has(row.transaction_id): return "流水缺少对应交易或被重复提交。"
		var posting: Dictionary = expected[row.transaction_id]
		for key in posting:
			if row.get(key) != posting[key]: return "流水与交易记录不一致。"
		var stamp := int(row.night) * (run.night_minutes + 1) + int(row.minute)
		if row.kind not in ["daily_fees", "pawn_transfer"] and row.minute > SaveTimeline.closing(state, int(row.night)): return "关门后不能完成外部交易。"
		if stamp < last_time: return "流水时间倒序。"
		last_time = stamp
		balance += int(row.amount)
		if balance < 0 or balance != row.balance: return "流水现金无法对账。"
		posting.balance = balance
		state.ledger_entries.append(posting)
		expected.erase(row.transaction_id)
	if not expected.is_empty() or balance != state.cash: return "交易缺少流水或现金不符。"
	for summary in state.summaries:
		var snapshot := RunState.new()
		snapshot.current_night_index = summary.night
		snapshot.ledger_entries = state.ledger_entries
		snapshot.fee_history = state.fee_history
		snapshot.ordinary_selections = state.ordinary_selections
		var change := 0
		for entry in state.ledger_entries:
			if entry.night == summary.night: change += entry.amount
		for item in state.inventory_instances:
			if item.acquired_night > summary.night: continue
			var clone := ItemInstance.new()
			clone.acquisition_price = item.acquisition_price
			if tickets.has(item.instance_id):
				var ticket: PawnTicket = tickets[item.instance_id]
				if ticket.closed_night == 0 or ticket.closed_night > summary.night:
					clone.ownership_state = "pledged"
					var active := PawnTicket.new()
					active.principal = ticket.principal
					snapshot.pawn_tickets.append(active)
				elif ticket.status in ["redeemed", "transferred"]: clone.ownership_state = ticket.status
			if sales.has(item.instance_id) and sales[item.instance_id].night <= summary.night: clone.ownership_state = "sold"
			snapshot.inventory_instances.append(clone)
		var financial := FinancialSummary.build(snapshot)
		for key in financial:
			if summary[key] != financial[key]: return "日结财务指标无法对账：" + key
		if summary.closing_cash != summary.opening_cash + change: return "日结现金流不符。"
	return ""

static func _post(entries: Dictionary, id: String, item: String, night: int, minute: int, amount: int, kind: String, profit: int) -> void:
	entries[id] = {"transaction_id": id, "item_instance_id": item, "night": night, "minute": minute, "amount": amount, "kind": kind, "realized_profit": profit}

static func _window(minute: int, start: int, end: int, cost: int, run: RunDefinition) -> bool:
	return minute >= start + cost and minute < end and minute < run.night_minutes and minute % run.time_step == 0

static func _return_time(minute: int, night: int, terms: PawnTermsDefinition, cost: int, run: RunDefinition, state: RunState) -> bool:
	if night < state.pawn_rules_start_night: return _window(minute, terms.window_start, terms.window_end, cost, run)
	return minute >= cost and minute <= run.night_minutes and minute % run.time_step == 0
