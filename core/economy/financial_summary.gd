class_name FinancialSummary
extends RefCounted

static func build(state: RunState) -> Dictionary:
	var result := {"realized_profit": 0, "pawn_transfer_receipts": 0, "sales_revenue": 0, "purchase_spend": 0, "pawn_disbursed": 0, "redemption_receipts": 0, "inventory_count": 0, "inventory_cost": 0, "pawn_principal": 0}
	result.merge({"interest_expense": 0, "shop_expense": 0, "fees_paid": 0, "operating_profit": 0})
	if state.night_market_enabled: result.inventory_loss = 0
	if state.preparation_version == 1: result.preparation_expense = 0
	if not state.ordinary_selections.is_empty(): result.provenance_expense = 0
	for row in state.fee_history:
		if row.night == state.current_night_index:
			result.interest_expense = row.interest
			result.shop_expense = row.overhead
			result.fees_paid = row.paid
	for entry in state.ledger_entries:
		if entry.night != state.current_night_index: continue
		result.realized_profit += entry.realized_profit
		match entry.kind:
			"inventory_loss":
				var item := InventoryManager.new().find(state, entry.item_instance_id)
				if item != null: result.inventory_loss += item.acquisition_price
			"preparation": result.preparation_expense = int(result.get("preparation_expense", 0)) - int(entry.amount)
			"provenance_inquiry": result.provenance_expense = int(result.get("provenance_expense", 0)) - int(entry.amount)
			"sale": result.sales_revenue += entry.amount
			"pawn_transfer": result.pawn_transfer_receipts += entry.amount
			"acquisition": result.purchase_spend -= entry.amount
			"pawn_loan": result.pawn_disbursed -= entry.amount
			"redemption", "extension": result.redemption_receipts += entry.amount
	for item in state.inventory_instances:
		if item.ownership_state == "owned":
			result.inventory_count += 1
			result.inventory_cost += item.acquisition_price
	for ticket in state.pawn_tickets:
		if ticket.status == "active": result.pawn_principal += ticket.principal
	result.operating_profit = result.realized_profit - result.interest_expense - result.shop_expense - int(result.get("provenance_expense", 0)) - int(result.get("preparation_expense", 0)) - int(result.get("inventory_loss", 0))
	return result
