class_name FeeService
extends RefCounted

# One deterministic settlement per night. Charges accrue once; cash pays oldest first.
static func settle(state: RunState, run: RunDefinition) -> void:
	var policy := run.fee_policy
	if not policy.enabled: return
	for row in state.fee_history:
		if row.night == state.current_night_index: return
	var night := state.current_night_index
	state.fee_arrears.append({"origin_night": night, "due_night": night + policy.grace_nights, "amount": policy.interest + policy.overhead})
	var available := state.cash
	var paid := 0
	var remaining: Array[Dictionary] = []
	for debt in state.fee_arrears:
		var payment := mini(available, int(debt.amount))
		available -= payment
		paid += payment
		var rest := int(debt.amount) - payment
		if rest > 0: remaining.append({"origin_night": int(debt.origin_night), "due_night": int(debt.due_night), "amount": rest})
	state.fee_arrears = remaining
	EconomyManager.new().commit(state, -paid, "shop", "fees/%s/%d" % [run.id, night], "daily_fees")
	state.fee_history.append({"night": night, "interest": policy.interest, "overhead": policy.overhead, "paid": paid, "arrears": outstanding(state), "overdue": overdue(state)})

static func outstanding(state: RunState) -> int:
	var total := 0
	for row in state.fee_arrears: total += int(row.amount)
	return total

static func overdue(state: RunState) -> int:
	var total := 0
	for row in state.fee_arrears:
		if row.due_night <= state.current_night_index: total += int(row.amount)
	return total

static func finish(state: RunState, run: RunDefinition) -> void:
	if not run.fee_policy.enabled or overdue(state) == 0 or not state.risk_pending.is_empty() or state.phase == &"dead": return
	state.phase = &"bankrupt"
	for record in state.bankruptcy_archive:
		if record.run_token == state.run_token: return
	state.bankruptcy_archive.append(record(state, run))

static func record(state: RunState, run: RunDefinition) -> Dictionary:
	var assets := FinancialSummary.build(state)
	return {"run_token": state.run_token, "run_id": run.id, "night": state.current_night_index, "cash": state.cash, "principal": run.fee_policy.principal, "arrears": outstanding(state), "overdue": overdue(state), "inventory_cost": assets.inventory_cost, "pawn_principal": assets.pawn_principal}

static func describe(state: RunState, run: RunDefinition) -> String:
	if not run.fee_policy.enabled: return ""
	var p := run.fee_policy
	var body := "借据本金 %d 银元\n每日利息 %d · 铺面开支 %d · 合计 %d\n每夜夜末结账；短款只宽限到次夜夜末。\n" % [p.principal, p.interest, p.overhead, p.interest + p.overhead]
	if state.fee_arrears.is_empty(): body += "息费暂无欠款。\n"
	for debt in state.fee_arrears:
		body += "第%d夜短款 %d 银元 · 第%d夜夜末须补齐%s\n" % [debt.origin_night, debt.amount, debt.due_night, "（今夜到期）" if debt.due_night == state.current_night_index else ""]
	return body

static func archive_text(state: RunState) -> String:
	var text := "\n《破铺录》\n"
	if state.bankruptcy_archive.is_empty(): return text + "纸页尚空。\n"
	for row in state.bankruptcy_archive:
		text += "第%d夜 · 到期短款 %d 银元未齐\n本金 %d · 息费欠款 %d · 遗银 %d\n现货成本 %d · 在当本金 %d\n" % [row.night, row.overdue, row.principal, row.arrears, row.cash, row.inventory_cost, row.pawn_principal]
	return text
