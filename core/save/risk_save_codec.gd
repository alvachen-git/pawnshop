class_name RiskSaveCodec
extends RefCounted

static func valid_archive(value: Variant) -> bool:
	if not value is Array: return false
	var tokens: Array = []
	for row in value:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["run_token", "run_id", "item_id", "rule_id", "cause", "item_name"]) or not CounterSaveCodec._integers(row, ["night", "cash", "inventory_cost", "pawn_principal"]): return false
		if row.has("encounter_id") and not CounterSaveCodec._text_fields(row, ["encounter_id"]): return false
		if row.rule_id == "personal_lamp":
			if not CounterSaveCodec._text_fields(row, ["source_phase", "event_instance"]) or not CounterSaveCodec._integers(row, ["minute"]): return false
			if row.minute < 0 or row.minute > 540 or row.source_phase not in ["pre_open", "open", "closed_processing", "night_resolution", "shop_resolution", "private_room", "sleep_resolution", "day_summary"]: return false
		if row.run_token.length() != 32 or not row.run_token.is_valid_hex_number() or row.run_token in tokens or row.night < 1 or row.cash < 0 or row.inventory_cost < 0 or row.pawn_principal < 0: return false
		for field in ["night", "cash", "inventory_cost", "pawn_principal"]:
			if row[field] > 2147483647: return false
		tokens.append(row.run_token)
	return true

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("run_token") is String or not data.get("risk_pending") is String or not data.get("risk_history") is Array or not valid_archive(data.get("death_archive")): return "鬼货状态或绝当录结构损坏。"
	state.run_token = data.run_token
	for record in data.death_archive:
		var copy: Dictionary = record.duplicate(true)
		copy.night = int(copy.night)
		copy.cash = int(copy.cash)
		copy.inventory_cost = int(copy.inventory_cost)
		copy.pawn_principal = int(copy.pawn_principal)
		state.death_archive.append(copy)
	if run.ghost_rule_ids.is_empty():
		if (not run.fee_policy.enabled and not state.run_token.is_empty()) or (run.fee_policy.enabled and (state.run_token.length() != 32 or not state.run_token.is_valid_hex_number())) or not data.risk_pending.is_empty() or not data.risk_history.is_empty() or state.phase == &"dead": return "本运行未启用鬼货。"
		for summary in state.summaries:
			if summary.outcome != ("peaceful" if run.private_room else "placeholder_peaceful"): return "旧运行日结结果无效。"
		return ""
	if catalog == null or state.run_token.length() != 32 or not state.run_token.is_valid_hex_number(): return "鬼货运行标识无效。"
	var manager := RiskManager.new(catalog)
	var last_stamp := -1
	var closes := {}
	var responses := {}
	for row in data.risk_history:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["item_id", "action"]) or not CounterSaveCodec._integers(row, ["night", "minute"]): return "鬼货处理历史损坏。"
		var night := int(row.night)
		var minute := int(row.minute)
		var stamp := night * (run.night_minutes + 1) + minute
		if night == state.current_night_index and minute > state.game_minutes: return "鬼货处理晚于保存时刻。"
		if SaveTimeline.unsettled(state) and night == state.current_night_index and row.action in ["retreat", "defy"]: return "未结算时不能已有夜间应对。"
		if night < 1 or night > SaveTimeline.trading_nights(state) or minute < 0 or minute > run.night_minutes or minute % run.time_step != 0 or stamp < last_stamp: return "鬼货处理时刻无效。"
		last_stamp = stamp
		var item := InventoryManager.new().find(state, row.item_id)
		var pursuit := MirrorEncounterService.pursuit(state, night)
		var personal: bool = not pursuit.is_empty() and pursuit.mirror_id == row.item_id
		if item == null or manager.rule_for(item) == null or (not manager.held_at(state, item, night, minute) and not (personal and row.action in ["retreat", "defy"])): return "鬼货处理没有对应持有物。"
		var key := "%d/%s" % [night, row.item_id]
		var cloth := manager.covered(state, row.item_id)
		var closing: int = SaveTimeline.closing(state, night)
		match row.action:
			"close":
				if closes.has(key) or minute != closing or not row.get("covered") is bool or row.covered != cloth: return "关门鬼货快照不一致。"
				closes[key] = true
			"cover", "uncover":
				var rule := manager.rule_for(item)
				var cost := RiskManager.recorded_minutes(run, rule, row)
				if cost < 0: return "红布动作的即时记录无效。"
				if cloth == (row.action == "cover") or minute < cost or (minute > closing and not closes.has(key)): return "鬼货处理顺序无效。"
				if not manager.held_at(state, item, night, minute - cost): return "鬼货处理早于入库。"
				for previous in state.risk_history:
					if previous.night == night and previous.action in ["cover", "uncover"] and previous.minute > minute - cost: return "鬼货处理耗时重叠。"
			"retreat", "defy":
				if run.private_room:
					if row.get("scope", "") not in ["shop", "personal"] or minute != run.night_minutes: return "房间应对位置无效。"
				else:
					if responses.has(night) or minute != run.night_minutes or (not personal and (not closes.has(key) or cloth)) or manager.night_outcome(state, night) != "mirror_pending": return "夜间应对无前置警告。"
					responses[night] = row.action
			_:
				return "未知鬼货处理动作。"
		var copy: Dictionary = row.duplicate(true)
		copy.night = night
		copy.minute = minute
		state.risk_history.append(copy)
	for night in range(1, SaveTimeline.trading_nights(state) + 1):
		for item in manager.ghosts(state):
			if manager.held_at(state, item, night, SaveTimeline.closing(state, night)) and not closes.has("%d/%s" % [night, item.instance_id]): return "缺少关门鬼货检查。"
		if night > state.summaries.size(): continue
		if run.private_room: continue # RoomSaveCodec replays both risk stages and their outcomes.
		var outcome := manager.night_outcome(state, night)
		if responses.has(night): outcome = "mirror_death" if responses[night] == "defy" else "mirror_survived"
		if state.summaries[night - 1].outcome != outcome: return "鬼货结果与处理历史不符。"
		if outcome in ["mirror_death", "mirror_pending"] and (night != state.current_night_index or state.phase != (&"dead" if outcome == "mirror_death" else &"day_summary")): return "未解决的鬼货结果不能推进。"
	if SaveTimeline.unsettled(state) and not data.risk_pending.is_empty(): return "尚未结算不能带有夜间危机。"
	var expected := ""
	if run.private_room: expected = data.risk_pending
	elif not state.summaries.is_empty() and state.summaries.back().outcome == "mirror_pending":
		var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
		if not pursuit.is_empty(): expected = pursuit.mirror_id
		for item in manager.ghosts(state):
			if not expected.is_empty(): break
			if manager.held_at(state, item, state.current_night_index, state.game_minutes) and not manager.covered(state, item.instance_id):
				expected = item.instance_id
				break
	if data.risk_pending != expected: return "待处理鬼货与日结不一致。"
	state.risk_pending = expected
	var death: Dictionary = {}
	for record in state.death_archive:
		if record.run_token == state.run_token: death = record
	if state.phase == &"dead" and state.night_market_enabled and data.room_history.any(func(r: Variant) -> bool: return r is Dictionary and r.get("night") == state.current_night_index and r.get("action") == "finish_sleep"):
		var expected_late := NightMarketRisk.death_record(state)
		for key in expected_late:
			if key not in ["cause", "item_name"] and death.get(key) != expected_late[key]: return "命灯记录与夜客遗留资产不符。"
	elif state.phase == &"dead":
		if state.risk_history.is_empty() or state.risk_history.back().action != "defy": return "死亡状态缺少一致的绝当录。"
		var expected_death := manager.death_record(state, state.risk_history.back().item_id)
		# Editorial snapshots may differ after a copy revision; identity and assets must still agree.
		for key in expected_death:
			if key not in ["cause", "item_name"] and death.get(key) != expected_death[key]: return "死亡状态缺少一致的绝当录。"
	elif not death.is_empty(): return "本轮已记入绝当录，不能恢复为存活状态。"
	return ""
