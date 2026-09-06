class_name SaveCodec
extends RefCounted

const VERSION := 11
const ROOM_VERSION := 11
const CHECKPOINTS := ["pre_open", "day_summary", "run_ended", "dead", "bankrupt", "shop_resolution", "private_room", "sleep_resolution"]
var error_message := ""

func encode(state: RunState, content_version: int) -> Dictionary:
	var data := state.to_read_model()
	data.save_version = VERSION if content_version >= 11 else (10 if content_version == 10 else 9)
	data.content_version = content_version
	return data

func decode(data: Variant, definition: RunDefinition, content_version: int, catalog: ContentCatalog = null) -> RunState:
	error_message = "存档结构损坏或状态不一致。"
	if not data is Dictionary:
		return null
	for key in ["save_version", "content_version", "current_night_index", "game_minutes", "cash", "run_seed", "closed_at", "night_opening_cash", "action_count"]:
		if not data.has(key) or not RunSchema.integer(data[key]) or abs(data[key]) > 2147483647:
			return null
	var legacy := int(data.save_version) == (8 if definition.private_room else 7)
	if (int(data.save_version) not in [VERSION, 10, 9] and not legacy) or int(data.content_version) != content_version:
		error_message = "存档/内容版本不兼容；旧文件已保留。"
		return null
	if not definition.variety.is_empty() and int(data.save_version) != content_version: return null
	if legacy:
		data = data.duplicate(true)
		if not data.get("summaries") is Array or not data.get("pawn_tickets") is Array: return null
		data.pawn_rules_start_night = data.summaries.size() + 1
		data.pawn_returns = PawnReturnService.plan(data.pawn_tickets, int(data.current_night_index), catalog) if data.get("phase") == "pre_open" else []
		for summary in data.summaries:
			if not summary is Dictionary: return null
			summary.pawn_transfer_receipts = 0
	if not RunSchema.integer(data.get("pawn_rules_start_night")) or data.pawn_rules_start_night < 1 or data.pawn_rules_start_night > int(data.current_night_index) + 1: return null
	if data.get("run_definition_id") != definition.id:
		error_message = "存档运行配置不存在或不匹配。"
		return null
	if data.get("phase") not in CHECKPOINTS or not data.get("summaries") is Array:
		return null
	if data.pawn_rules_start_night > data.summaries.size() + 1: return null
	if not data.get("room_history", []) is Array: return null
	if not definition.private_room and (data.phase in RoomFlow.PHASES or data.get("room_enabled", false) != false or not data.get("room_history", []).is_empty()): return null
	if definition.private_room and (not data.get("room_enabled") is bool or data.room_enabled != true or not data.get("room_history") is Array): return null
	var night := int(data.current_night_index)
	var elapsed := int(data.game_minutes)
	var closed := int(data.closed_at)
	if night < 1 or night > definition.total_nights or data.cash < 0 or data.night_opening_cash < 0 or data.run_seed < 0:
		return null
	if data.action_count < 0 or data.action_count > definition.night_minutes / definition.time_step:
		return null
	var settled: bool = data.phase != "pre_open"
	if data.summaries.size() != (night if settled else night - 1):
		return null
	if settled:
		if elapsed != definition.night_minutes or closed < 0 or closed > elapsed or closed % definition.time_step != 0:
			return null
		if data.phase == "run_ended" and night != definition.total_nights:
			return null
	elif elapsed != 0 or closed != -1 or data.action_count != 0:
		return null
	var previous_cash := definition.initial_cash
	for index in data.summaries.size():
		var entry: Variant = data.summaries[index]
		if not entry is Dictionary:
			return null
		for key in ["night", "opening_cash", "closing_cash", "closed_at", "action_count"]:
			if not entry.has(key) or not RunSchema.integer(entry[key]) or entry[key] < 0 or entry[key] > 2147483647:
				return null
		if entry.night != index + 1 or entry.opening_cash != previous_cash or entry.get("outcome") not in ["placeholder_peaceful"] + RiskManager.OUTCOMES:
			return null
		if entry.closed_at > definition.night_minutes or int(entry.closed_at) % definition.time_step != 0 or entry.action_count < 1 or entry.action_count > definition.night_minutes / definition.time_step:
			return null
		previous_cash = int(entry.closing_cash)
	if data.cash != previous_cash:
		return null
	if settled:
		var last: Dictionary = data.summaries.back()
		if last.opening_cash != data.night_opening_cash or last.closed_at != closed or last.action_count != data.action_count:
			return null
	elif data.night_opening_cash != data.cash:
		return null
	var state := RunState.new()
	state.run_definition_id = definition.id
	state.pawn_rules_start_night = int(data.pawn_rules_start_night)
	state.room_enabled = definition.private_room
	state.current_night_index = night
	state.phase = StringName(data.phase)
	state.game_minutes = elapsed
	state.cash = int(data.cash)
	state.run_seed = int(data.run_seed)
	state.closed_at = closed
	state.night_opening_cash = int(data.night_opening_cash)
	state.action_count = int(data.action_count)
	error_message = VarietySaveCodec.selections(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	for entry in data.summaries:
		# JSON numbers arrive as floats. Normalize every runtime numeric field.
		state.summaries.append({"night": int(entry.night), "opening_cash": int(entry.opening_cash), "closing_cash": int(entry.closing_cash), "closed_at": int(entry.closed_at), "action_count": int(entry.action_count), "outcome": String(entry.outcome)})
		for key in FinancialSummary.build(state):
			if not RunSchema.integer(entry.get(key)) or abs(entry[key]) > 2147483647: return null
			state.summaries.back()[key] = int(entry[key])
	error_message = CounterSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = PawnReturnService.validate(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = TradeScenarioSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = TradeScenarioSaveCodec.restore(data, state, definition, catalog, true)
	if not error_message.is_empty(): return null
	error_message = EventSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = MirrorSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = RiskSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	error_message = VarietySaveCodec.validate_timing(state, definition, catalog)
	if not error_message.is_empty(): return null
	if definition.private_room:
		error_message = RoomSaveCodec.restore(data, state, definition, catalog)
		if not error_message.is_empty(): return null
	error_message = FeeSaveCodec.finish(data, state, definition)
	if not error_message.is_empty(): return null
	return state
