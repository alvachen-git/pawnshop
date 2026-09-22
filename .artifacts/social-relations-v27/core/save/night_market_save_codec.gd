class_name NightMarketSaveCodec
extends RefCounted

static func prepare(data: Dictionary, state: RunState, run: RunDefinition) -> String:
	if not NightMarketPlan.enabled(run):
		return "旧局不能混入夜客记录。" if data.has("night_market_enabled") or data.has("night_market_history") else ""
	if data.get("night_market_enabled") != true or not data.get("night_market_history") is Array: return "缺少夜客处理记录。"
	var last := -1
	for raw in data.night_market_history:
		if not raw is Dictionary or not CounterSaveCodec._text_fields(raw, ["action", "visit_id"]) or not CounterSaveCodec._integers(raw, ["night", "minute"]): return "夜客处理记录损坏。"
		if raw.action not in ["purchase", "taboo", "seal_cloth"] or raw.size() != (5 if raw.action == "seal_cloth" else 4): return "未知夜客处理动作。"
		if raw.action == "seal_cloth" and not CounterSaveCodec._integers(raw, ["start"]): return "封存起始时刻无效。"
		var row: Dictionary = raw.duplicate(true)
		for key in ["night", "minute", "start"]:
			if row.has(key): row[key] = int(row[key])
		var stamp: int = row.night * 541 + row.minute
		if row.night < 1 or row.night > SaveTimeline.trading_nights(state) or row.minute < 0 or row.minute > 540 or row.minute % 5 != 0 or stamp < last: return "夜客处理时刻无效。"
		if row.night == state.current_night_index and row.minute > state.game_minutes: return "夜客处理晚于存档。"
		if VarietySaveCodec.selection(state, row.visit_id).get("night_policy") != "wet_cloth": return "包布不属于本局夜客。"
		last = stamp
		state.night_market_history.append(row)
	return ""

static func validate(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not state.night_market_enabled: return ""
	var expected: Array[Dictionary] = []
	for row in state.scenario_history + state.bargaining_history:
		if not row.ok or VarietySaveCodec.selection(state, row.visit_id).get("night_policy") != "wet_cloth": continue
		var action := ""
		if row.command == "question" and row.detail == "origin": action = "taboo"
		elif row.command == "offer" and state.visit_history.any(func(h: Dictionary) -> bool: return h.visit_id == row.visit_id and h.outcome == "bought" and h.minute == row.minute): action = "purchase"
		if not action.is_empty(): expected.append({"action": action, "night": int(row.night), "minute": int(row.minute), "visit_id": row.visit_id})
	var actual := state.night_market_history.filter(func(r: Dictionary) -> bool: return r.action != "seal_cloth")
	expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.night * 541 + a.minute < b.night * 541 + b.minute)
	if actual != expected: return "夜客后果与实际问话、成交不符。"
	var replay := RunState.create(run)
	replay.ordinary_selections = state.ordinary_selections
	for row in state.night_market_history:
		if row.action == "seal_cloth":
			if row.visit_id not in NightMarketRisk.unresolved(replay): return "包布重复处理或没有留下。"
			if row.start < 0 or row.start % 5 != 0 or row.minute != row.start + int(run.variety.night_market.treatment_minutes): return "封存耗时不符。"
			if not replay.night_market_history.any(func(h: Dictionary) -> bool: return h.visit_id == row.visit_id and (h.night < row.night or h.minute <= row.start)): return "包布还未留下就已封存。"
			for prior in replay.night_market_history:
				if prior.night == row.night and prior.minute > row.start: return "封存与夜客行动重叠。"
			for h in state.scenario_history + state.bargaining_history + state.provenance_history + state.sale_batches:
				if h.night == row.night and h.start < row.minute and h.minute > row.start: return "封存与交易行动重叠。"
			for h in data.event_history:
				if not h is Dictionary or not CounterSaveCodec._integers(h, ["night", "offered_minute", "minute"]): return "剧情时刻无效。"
				if h.night == row.night and h.offered_minute < row.minute and h.minute > row.start: return "剧情未决时不能封存。"
			if row.night == state.current_night_index and not state.pending_event_id.is_empty() and state.pending_event_minute <= row.start: return "剧情未决时不能封存。"
			for h in state.pawn_returns:
				if h.night == row.night and h.minute > row.start: return "原当户未办结时不能封存。"
			# Reconstruct whether any arrived customer was still being received/waiting.
			var delay := PawnReturnService.delay_for(data, int(row.night), catalog)
			for h in state.visit_history:
				var planned := VarietySaveCodec.selection(state, h.visit_id)
				if h.night == row.night and int(planned.arrival) + delay <= row.start and h.minute > row.start: return "柜前有客时不能封存。"
			for h in state.risk_history:
				if h.night == row.night and h.action in ["cover", "uncover"]:
					var item := InventoryManager.new().find(state, h.item_id)
					var rule := RiskManager.new(catalog).rule_for(item)
					if h.minute > row.start and h.minute - RiskManager.recorded_minutes(run, rule, h) < row.minute: return "封存与覆镜耗时重叠。"
			for h in data.mirror_history:
				if not h is Dictionary or not CounterSaveCodec._integers(h, ["night", "minute"]): return "窥镜时刻无效。"
				if h.night != row.night: continue
				var encounter := MirrorEncounterService.find_definition(run, h.get("encounter_id", ""))
				if encounter == null: return "窥镜引用无效。"
				var cost := encounter.peek_minutes if String(h.get("action", "")).begins_with("peek") else (encounter.pursue_minutes if String(h.get("action", "")).begins_with("pursue") else 0)
				if h.minute > row.start and h.minute - cost < row.minute: return "封存与窥镜耗时重叠。"
				if h.action == "peek" and encounter.allow_pursuit and h.minute <= row.start:
					var resolved: bool = data.mirror_history.any(func(next: Dictionary) -> bool: return next.encounter_id == h.encounter_id and next.night == h.night and next.action in ["stop", "pursue", "pursue_expired"] and next.minute <= row.start)
					if not resolved: return "窥镜选择未决时不能封存。"
		replay.night_market_history.append(row.duplicate(true))
	return ""
