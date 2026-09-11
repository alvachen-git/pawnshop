class_name CashFlowReadModel
extends RefCounted

# Presentation only: no money is reserved or written to the run/save.
static func enabled(run: RunDefinition) -> bool:
	return run.id in [&"complete_seven", &"pawn_chance_seven"] or NightMarketPlan.enabled(run)

static func build(state: RunState, run: RunDefinition) -> Dictionary:
	if not enabled(run): return {}
	var settled := state.fee_history.any(func(row: Dictionary) -> bool: return int(row.night) == state.current_night_index)
	var pending := 0 if settled or not run.fee_policy.enabled else run.fee_policy.interest + run.fee_policy.overhead
	var arrears := FeeService.outstanding(state)
	var assets := FinancialSummary.build(state)
	return {"cash": state.cash, "pending_fees": pending, "arrears": arrears,
		"reserve": pending + arrears, "balance": state.cash - pending - arrears,
		"inventory_cost": assets.inventory_cost, "pawn_principal": assets.pawn_principal,
		"settled": settled, "night": state.current_night_index,
		"pending_due_night": state.current_night_index + run.fee_policy.grace_nights,
		"arrears_rows": state.fee_arrears.duplicate(true)}

static func balance_text(balance: int, projected := false) -> String:
	var prefix := "成交后预计" if projected else ""
	return prefix + ("留足息费尚差%d银元" % -balance if balance < 0 else "留足息费后余量%d银元" % balance)

static func overview(flow: Dictionary) -> String:
	return "周转概况 / 银元\n现银 %d · 今夜待结息费 %d · 息费短款 %d\n%s\n自有现货占款 %d · 在当本金 %d\n仅扣除已知息费，未计后续收货等支出。" % [flow.cash, flow.pending_fees, flow.arrears, balance_text(flow.balance), flow.inventory_cost, flow.pawn_principal]

static func debt_detail(flow: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("今夜息费已结算，不再重复预留。" if flow.settled else "今夜待结息费%d银元；若有短款，宽限到第%d夜夜末。" % [flow.pending_fees, flow.pending_due_night])
	for row in flow.arrears_rows:
		var suffix := "（今夜到期）" if int(row.due_night) == flow.night else ("（已到期）" if int(row.due_night) < flow.night else "")
		lines.append("第%d夜短款%d银元 · 第%d夜夜末须补齐%s" % [row.origin_night, row.amount, row.due_night, suffix])
	lines.append("先补旧短款，再付当夜息费。留款只是查账试算，不会另扣银元。")
	return "\n".join(lines)

# The caller supplies the already visible quotes for exactly one buyer.
static func sale_preview(flow: Dictionary, buyer: Dictionary, selected: Array) -> Dictionary:
	var income := 0
	var cost := 0
	var seen: Array = []
	var error := ""
	for id in selected:
		if id in seen: error = "货单有重复货物，请重新选择。"; break
		seen.append(id)
		var found := false
		for row in buyer.get("stock", []):
			if row.id != id: continue
			found = true
			if not row.reason.is_empty(): error = row.reason; break
			income += int(row.price)
			cost += int(row.cost)
			break
		if not found: error = "货单包含无效货物，请重新选择。"
		if not error.is_empty(): break
	if not error.is_empty(): return {"valid": false, "reason": error}
	var reason: String = buyer.get("reason", "")
	if selected.is_empty(): reason = "请先选择货物。"
	return {"valid": true, "executable": reason.is_empty(), "reason": reason, "count": selected.size(),
		"income": income, "cost": cost, "profit": income - cost,
		"cash": flow.cash + income, "balance": flow.cash + income - flow.reserve}
