class_name RoomSaveCodec
extends RefCounted

# Replay the recorded lifecycle against already validated physical/financial
# history. Never infer that an absent sleep/response occurred successfully.
static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if catalog == null: return "房间内容缺失。"
	if state.phase == &"pre_open" and not state.risk_pending.is_empty(): return "开铺前不能带有未决夜间危机。"
	var manager := RiskManager.new(catalog)
	var rows: Array = data.room_history
	var cursor := 0
	var all_responses: Array = []
	for row in state.risk_history:
		if row.action in ["retreat", "defy"]: all_responses.append(row)
	var replayed_responses: Array = []
	for night in range(1, state.summaries.size() + 1):
		var sample := RunState.create(run)
		sample.current_night_index = night
		sample.game_minutes = run.night_minutes
		sample.inventory_instances = state.inventory_instances
		sample.ledger_entries = state.ledger_entries
		sample.mirror_history = state.mirror_history
		sample.summaries.append(state.summaries[night - 1].duplicate(true))
		for row in state.risk_history:
			if row.night <= night and (row.action not in ["retreat", "defy"] or row in replayed_responses): sample.risk_history.append(row.duplicate(true))
		if cursor >= rows.size() or not _row(rows[cursor], night, "seal"): return "缺少封铺结算记录。"
		RoomFlow.seal(sample, manager)
		cursor += 1
		while cursor < rows.size() and rows[cursor] is Dictionary and rows[cursor].get("night") == night:
			var row: Dictionary = rows[cursor]
			if row.size() != 2 or not RunSchema.integer(row.get("night")) or not row.get("action") is String: return "房间记录结构损坏。"
			var action: String = row.action
			var result: ActionResult
			if action in ["shop_retreat", "shop_defy", "personal_retreat", "personal_defy"]:
				if not action.begins_with(RoomFlow.scope(sample) + "_"): return "危机发生位置不符。"
				result = RoomFlow.respond(sample, manager, sample.risk_pending, action.get_slice("_", 1))
				if result.ok: replayed_responses.append(sample.risk_history.back())
			else: result = RoomFlow.execute(sample, manager, action)
			if not result.ok: return "房间阶段被跳过或重复提交。"
			cursor += 1
		if sample.summaries.back().outcome != state.summaries[night - 1].outcome: return "房间风险结果与历史不符。"
		if night < state.summaries.size() or state.phase == &"pre_open":
			if sample.phase != &"day_summary": return "未完成就寝不能进入下一夜。"
		else:
			var expected_phase := state.phase
			if state.phase in [&"run_ended", &"bankrupt"]: expected_phase = &"day_summary"
			if sample.phase != expected_phase or sample.risk_pending != state.risk_pending: return "房间恢复位置或未决危机不一致。"
	if cursor != rows.size() or replayed_responses != all_responses: return "房间记录或应对历史不一致。"
	for row in rows: state.room_history.append({"night": int(row.night), "action": row.action})
	return ""

static func _row(row: Variant, night: int, action: String) -> bool:
	return row is Dictionary and row.size() == 2 and RunSchema.integer(row.get("night")) and row.night == night and row.get("action") == action
