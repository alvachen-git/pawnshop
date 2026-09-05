class_name TradeScenarioSaveCodec
extends RefCounted

# Replay commands through the same counter rules; testimony cannot become physical evidence.
static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("scenario_history") is Array or not data.get("scenario_selections") is Array: return "缺少交易情境记录。"
	if run.trade_scenarios.is_empty():
		return "" if data.scenario_history.is_empty() and data.scenario_selections.is_empty() else "本运行没有交易情境。"
	if catalog == null: return "交易情境校验需要内容目录。"
	var selections: Array = []
	var replay_days: Dictionary = {}
	var all_visits: Dictionary = {}
	var endings: Dictionary = {}
	for row in state.visit_history: endings[row.visit_id] = row
	for night in range(1, state.current_night_index + 1):
		var sample := RunState.create(run)
		sample.current_night_index = night
		sample.run_seed = state.run_seed
		CustomerManager.new().prepare_night(sample, run, catalog)
		selections.append_array(sample.scenario_selections)
		var delay := PawnReturnService.delay_for(data, night, catalog)
		for visit in sample.visits:
			visit.arrival += delay
			visit.expires_at += delay
			all_visits[visit.visit_id] = visit
			if visit.scenario_id.is_empty() or night > state.summaries.size(): continue
			var replay := RunState.create(run)
			replay.run_seed = state.run_seed
			replay.current_night_index = night
			replay.phase = &"open"
			replay.cash = 1000000
			replay.visits.append(visit)
			replay_days[visit.visit_id] = DayController.new(run, replay)
	if selections != data.scenario_selections: return "交易情境与本局种子不一致。"
	state.scenario_selections.assign(selections)
	var service := CounterService.new(catalog)
	var last_end := -1
	for raw in data.scenario_history:
		if not raw is Dictionary or not CounterSaveCodec._text_fields(raw, ["scenario_id", "visit_id", "variant_id", "situation_id", "reaction_id", "command"]) or not CounterSaveCodec._integers(raw, ["night", "start", "minute", "amount"]): return "交易情境行动结构无效。"
		if not raw.get("detail") is String or not raw.get("ok") is bool or not raw.get("concession_used") is bool: return "交易情境结果结构无效。"
		for key in ["clues", "questions", "used_clues"]:
			if not CounterSaveCodec._string_array(raw.get(key)): return "交易情境证据或问答重复。"
		if not replay_days.has(raw.visit_id): return "交易情境行动不属于已结束的来访。"
		var day: DayController = replay_days[raw.visit_id]
		var visit: CustomerVisit = all_visits[raw.visit_id]
		if raw.night != day.state.current_night_index or raw.start < visit.arrival or int(raw.start) % run.time_step != 0 or raw.start >= mini(visit.expires_at, state.summaries[int(raw.night) - 1].closed_at): return "交易情境行动起始时刻无效。"
		var stamp := int(raw.night) * (run.night_minutes + 1) + int(raw.start)
		if stamp < last_end or raw.minute < raw.start or raw.minute > run.night_minutes: return "交易情境行动耗时重叠或无效。"
		last_end = int(raw.night) * (run.night_minutes + 1) + int(raw.minute)
		for other_id in endings:
			var other: CustomerVisit = all_visits[other_id]
			if other_id != visit.visit_id and endings[other_id].night == raw.night and other.arrival <= visit.arrival and endings[other_id].minute > raw.start: return "行动时这位客人尚未上柜。"
		day.state.game_minutes = int(raw.start)
		service.customers.update(day.state)
		var prior_count := day.state.scenario_history.size()
		service.execute(day, raw.command, raw.visit_id, raw.detail, int(raw.amount))
		if day.state.scenario_history.size() != prior_count + 1: return "交易情境行动不满足条件或重复使用优惠。"
		var normalized: Dictionary = raw.duplicate(true)
		for key in ["night", "start", "minute", "amount"]: normalized[key] = int(normalized[key])
		if normalized != day.state.scenario_history.back(): return "交易情境记录与真实行动、证据来源不符。"
		if endings[raw.visit_id].minute < raw.minute: return "交易情境行动晚于离店。"
		state.scenario_history.append(normalized)
	for id in replay_days:
		var day: DayController = replay_days[id]
		var visit: CustomerVisit = all_visits[id]
		var ending: Dictionary = endings[id]
		if visit.status not in ["scheduled", "active", "waiting"]:
			if visit.status != ending.outcome or day.state.visit_history.back().minute != ending.minute: return "议价结果与离店记录不一致。"
		elif ending.outcome not in ["timed_out", "shop_closed"]: return "缺少成交或送客的情境行动。"
		if ending.outcome in ["bought", "pawned"]:
			var owned := InventoryManager.new().find(state, visit.item.instance_id)
			if owned == null or owned.revealed_clue_ids != visit.item.revealed_clue_ids or owned.completed_action_ids != visit.item.completed_action_ids or owned.judgement != visit.item.judgement or owned.acquisition_price != visit.item.acquisition_price: return "库存与情境取证、报价历史不符。"
	return ""
