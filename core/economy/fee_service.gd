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

static func nightly_fee_notice(state: RunState, run: RunDefinition) -> String:
	if not run.fee_policy.enabled: return ""
	var settled := state.fee_history.any(func(row: Dictionary) -> bool: return int(row.night) == state.current_night_index)
	var next_night := state.current_night_index + (1 if settled else 0)
	var amount := run.fee_policy.interest + run.fee_policy.overhead
	var notice := "下次结息费：第%d夜夜末（%s），应付%d银元。" % [next_night, "明夜" if settled else "今夜", amount]
	if not state.fee_arrears.is_empty():
		var earliest_due := int(state.fee_arrears[0].due_night)
		for row in state.fee_arrears: earliest_due = mini(earliest_due, int(row.due_night))
		var deadline := "今夜到期" if earliest_due <= state.current_night_index else "还剩%d夜" % (earliest_due - state.current_night_index)
		notice += "\n未付息费%d银元，最迟第%d夜夜末补齐（%s）。" % [outstanding(state), earliest_due, deadline]
	return notice

static func principal_schedule_notice(state: RunState, run: RunDefinition) -> String:
	if not FirstDebt.enabled(run) or not run.fee_policy.enabled: return ""
	var notice := "借据约定的还本日已过。"
	if state.current_night_index <= 21:
		notice = "下次约定还本：第21夜（%s）。" % _night_distance(state.current_night_index, 21)
	elif state.current_night_index <= 49:
		notice = "下次约定还本：第49夜（%s）。" % _night_distance(state.current_night_index, 49)
	return notice

static func _night_distance(current_night: int, target_night: int) -> String:
	if current_night < target_night: return "还剩%d夜" % (target_night - current_night)
	return "今夜"

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
	var body := "借据本金 %d 银元\n每日利息 %d · 铺面开支 %d · 合计 %d\n每夜夜末结账；息费未付清便记短款，须在次夜夜末补齐。\n" % [p.principal, p.interest, p.overhead, p.interest + p.overhead]
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
