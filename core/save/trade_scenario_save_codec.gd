class_name TradeScenarioSaveCodec
extends RefCounted

# Replay commands through the same counter rules; testimony cannot become physical evidence.
static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog, ordinary := false) -> String:
	if not data.get("scenario_history") is Array or not data.get("scenario_selections") is Array: return "缺少交易情境记录。"
	var history_key := "bargaining_history" if ordinary else "scenario_history"
	var history: Variant = data.get(history_key, [])
	if not history is Array: return "议价行动记录无效。"
	if ordinary and history.is_empty(): return ""
	var recorded_visits: Array = []
	if ordinary:
		for row in history:
			if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["visit_id"]): return "议价来访记录无效。"
			if row.visit_id not in recorded_visits: recorded_visits.append(row.visit_id)
	if not ordinary and run.trade_scenarios.is_empty():
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
			if night > state.summaries.size(): continue
			if ordinary:
				if not visit.scenario_id.is_empty() or visit.visit_id not in recorded_visits: continue
			elif visit.scenario_id.is_empty(): continue
			var replay := RunState.create(run)
			replay.run_seed = state.run_seed
			replay.current_night_index = night
			replay.phase = &"open"
			replay.cash = 1000000
			replay.visits.append(visit)
			replay_days[visit.visit_id] = DayController.new(run, replay)
	if selections != data.scenario_selections: return "交易情境与本局种子不一致。"
	if not ordinary: state.scenario_selections.assign(selections)
	var service := CounterService.new(catalog)
	var last_end := -1
	for raw in history:
		if not raw is Dictionary or not CounterSaveCodec._text_fields(raw, (["visit_id", "variant_id", "command"] if ordinary else ["scenario_id", "visit_id", "variant_id", "situation_id", "reaction_id", "command"])) or not CounterSaveCodec._integers(raw, ["night", "start", "minute", "amount"]): return "交易情境行动结构无效。"
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
		# Mirror evidence has a separate validated history, outside counter commands.
		for source in data.get("mirror_history", []):
			if not source is Dictionary: return "铜镜证据记录无效。"
			if source.get("visit_id") != raw.visit_id or source.get("action") != "peek": continue
			if not CounterSaveCodec._integers(source, ["minute"]): return "铜镜证据时刻无效。"
			if source.minute > raw.start: continue
			var encounter := MirrorEncounterService.find_definition(run, source.get("encounter_id", ""))
			if encounter == null: return "铜镜证据来源无效。"
			if encounter.clue_id not in visit.item.revealed_clue_ids: visit.item.revealed_clue_ids.append(encounter.clue_id)
		day.state.game_minutes = int(raw.start)
		# The fixed mirror encounter may supply evidence between counter commands.
		for source in data.get("mirror_history", []):
			if not source is Dictionary: return "铜镜证据结构无效。"
			if source.get("visit_id") == raw.visit_id and source.get("action") == "peek" and RunSchema.integer(source.get("minute")) and source.minute <= raw.start:
				var encounter := MirrorEncounterService.find_definition(run, source.get("encounter_id", ""))
				if encounter == null: return "铜镜证据引用无效。"
				if encounter.clue_id not in visit.item.revealed_clue_ids: visit.item.revealed_clue_ids.append(encounter.clue_id)
		service.customers.update(day.state)
		var replay_history: Array = day.state.get(history_key)
		var prior_count := replay_history.size()
		service.execute(day, raw.command, raw.visit_id, raw.detail, int(raw.amount))
		if replay_history.size() != prior_count + 1: return "交易情境行动不满足条件或重复使用优惠。"
		var normalized: Dictionary = raw.duplicate(true)
		for key in ["night", "start", "minute", "amount"]: normalized[key] = int(normalized[key])
		if raw.command == "belittle":
			if not raw.get("belittle_result") is Dictionary or not raw.belittle_result.get("used") is bool or not CounterSaveCodec._integers(raw.belittle_result, ["asking", "rounds", "patience"]): return "试探结果结构无效。"
			for key in ["asking", "rounds", "patience"]: normalized.belittle_result[key] = int(normalized.belittle_result[key])
		if normalized != replay_history.back(): return "交易情境记录与真实行动、证据来源不符。"
		if endings[raw.visit_id].minute < raw.minute: return "交易情境行动晚于离店。"
		if raw.command == "verify_source" and raw.ok:
			if not state.provenance_history.any(func(h: Dictionary) -> bool: return h.item_instance_id == visit.item.instance_id and h.action == "counter" and h.start == raw.start and h.minute == raw.minute and h.result == visit.item.provenance.status): return "来源核验缺少对应物证记录。"
		var restored_history: Array = state.get(history_key)
		restored_history.append(normalized)
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
