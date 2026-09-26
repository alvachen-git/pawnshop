class_name FinancialSummary
extends RefCounted

static func build(state: RunState) -> Dictionary:
	var result := {"realized_profit": 0, "pawn_transfer_receipts": 0, "sales_revenue": 0, "purchase_spend": 0, "pawn_disbursed": 0, "redemption_receipts": 0, "inventory_count": 0, "inventory_cost": 0, "pawn_principal": 0}
	result.merge({"interest_expense": 0, "shop_expense": 0, "fees_paid": 0, "operating_profit": 0})
	if state.night_market_enabled: result.inventory_loss = 0
	if state.ghost_version == 1: result.exchange_receipts = 0
	if state.social_enabled: result.military_expense = 0
	if QingbangRules.active(state): result.qingbang_expense = 0; result.inventory_loss = 0
	if state.shop_growth_enabled: result.facility_investment = 0
	if state.investigation_enabled: result.investigation_expense = 0
	if state.run_definition_id in ["first_debt_open", "first_debt_reckoning", "first_debt_dragon_search", "first_debt_unified", "bangle_unified", "porcelain_unified", "gramophone_unified", "gramophone_release", "qingbang_release", "camera_unified", "porcelain_release", "first_debt_recovery", "first_debt_recovery_release"]: result.debt_compensation = 0
	if state.goods_version == 1: result.expertise_expense = 0
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
			"military_expense": result.military_expense -= entry.amount
			"qingbang_expense": result.qingbang_expense -= entry.amount
			"facility_investment": result.facility_investment -= entry.amount
			"inventory_loss":
				var item := InventoryManager.new().find(state, entry.item_instance_id)
				if item != null: result.inventory_loss += item.acquisition_price
			"pawn_exchange": result.exchange_receipts += entry.amount
			"investigation": result.investigation_expense -= entry.amount
			"debt_compensation": result.debt_compensation -= entry.amount
			"expertise": result.expertise_expense = int(result.get("expertise_expense", 0)) - int(entry.amount)
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
		if ticket.status == "active" and not QingbangDamage.lost(state,ticket): result.pawn_principal += ticket.principal
	result.operating_profit = result.realized_profit - int(result.get("qingbang_expense",0)) - int(result.get("debt_compensation", 0)) - int(result.get("military_expense", 0)) - int(result.get("investigation_expense", 0)) - int(result.get("expertise_expense", 0)) - result.interest_expense - result.shop_expense - int(result.get("provenance_expense", 0)) - int(result.get("preparation_expense", 0)) - int(result.get("inventory_loss", 0))
	if WealthyCustomers.active(state):
		result["reputation_trade_count"] = WealthyCustomers.data(state).transactions.size()
		result["reputation_growth"] = WealthyCustomers.data(state).milestones.filter(func(r: Dictionary) -> bool: return r.night == state.current_night_index).reduce(func(total: int, r: Dictionary) -> int: return total + int(r.delta), 0)
		result["advertising_delta"] = WealthyCustomers.data(state).advertisements.filter(func(r: Dictionary) -> bool: return r.night == state.current_night_index and r.settled).reduce(func(total: int, r: Dictionary) -> int: return total + int(r.delta), 0)
	return result
