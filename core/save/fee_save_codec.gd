class_name FeeSaveCodec
extends RefCounted

# Rebuild charges from validated external postings, not from saved fee claims.
static func prepare(data: Dictionary, state: RunState, run: RunDefinition, expected: Dictionary) -> String:
	if not data.get("fee_history") is Array or not data.get("fee_arrears") is Array: return "息费账页缺失。"
	var replay := RunState.create(run)
	for night in range(1, state.summaries.size() + 1):
		replay.current_night_index = night
		replay.game_minutes = run.night_minutes
		for posting in expected.values():
			if posting.night == night and posting.kind != "daily_fees": replay.cash += int(posting.amount)
		if replay.cash < 0: return "营业收支透支。"
		FeeService.settle(replay, run)
		if run.fee_policy.enabled:
			var posting: Dictionary = replay.ledger_entries.back().duplicate(true)
			posting.erase("balance")
			expected[posting.transaction_id] = posting
		if FeeService.overdue(replay) > 0 and night != state.summaries.size(): return "逾期欠款后不可继续经营。"
	var history: Variant = numeric_rows(data.fee_history, ["night", "interest", "overhead", "paid", "arrears", "overdue"])
	var arrears: Variant = numeric_rows(data.fee_arrears, ["origin_night", "due_night", "amount"])
	if history == null or arrears == null or replay.fee_history != history or replay.fee_arrears != arrears: return "息费、付款或欠款期限无法对账。"
	state.fee_history = replay.fee_history
	state.fee_arrears = replay.fee_arrears
	return ""

static func valid_archive(value: Variant) -> bool:
	if not value is Array: return false
	var tokens: Array = []
	for row in value:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["run_token", "run_id"]) or not CounterSaveCodec._integers(row, ["night", "cash", "principal", "arrears", "overdue", "inventory_cost", "pawn_principal"]): return false
		if row.run_token.length() != 32 or not row.run_token.is_valid_hex_number() or row.run_token in tokens or row.night < 1 or row.overdue <= 0 or row.arrears < row.overdue: return false
		for key in ["cash", "principal", "inventory_cost", "pawn_principal"]:
			if row[key] < 0: return false
		tokens.append(row.run_token)
	return true

static func finish(data: Dictionary, state: RunState, run: RunDefinition) -> String:
	if not valid_archive(data.get("bankruptcy_archive")): return "破铺录结构损坏。"
	for row in data.bankruptcy_archive:
		var copy: Dictionary = row.duplicate(true)
		for key in ["night", "cash", "principal", "arrears", "overdue", "inventory_cost", "pawn_principal"]: copy[key] = int(copy[key])
		state.bankruptcy_archive.append(copy)
	var failed := state.phase != &"pre_open" and FeeService.overdue(state) > 0 and state.risk_pending.is_empty() and state.phase != &"dead" and String(state.phase) not in RoomFlow.PHASES
	if failed != (state.phase == &"bankrupt"): return "经营终局与欠款期限不符。"
	var current: Dictionary = {}
	for row in state.bankruptcy_archive:
		if row.run_token == state.run_token: current = row
	if failed:
		if current != FeeService.record(state, run): return "经营终局缺少一致的破铺录。"
	elif not current.is_empty(): return "本轮已记入破铺录，不能恢复经营。"
	return ""

static func numeric_rows(value: Array, keys: Array) -> Variant:
	var result: Array[Dictionary] = []
	for row in value:
		if not row is Dictionary or row.size() != keys.size() or not CounterSaveCodec._integers(row, keys): return null
		var normalized := {}
		for key in keys: normalized[key] = int(row[key])
		result.append(normalized)
	return result
