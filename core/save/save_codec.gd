class_name SaveCodec
extends RefCounted

const VERSION := 3
const CHECKPOINTS := ["pre_open", "day_summary", "run_ended"]
var error_message := ""

func encode(state: RunState, content_version: int) -> Dictionary:
	var data := state.to_read_model()
	data.save_version = VERSION
	data.content_version = content_version
	return data

func decode(data: Variant, definition: RunDefinition, content_version: int, catalog: ContentCatalog = null) -> RunState:
	error_message = "存档结构损坏或状态不一致。"
	if not data is Dictionary:
		return null
	for key in ["save_version", "content_version", "current_night_index", "game_minutes", "cash", "run_seed", "closed_at", "night_opening_cash", "action_count"]:
		if not data.has(key) or not RunSchema.integer(data[key]) or abs(data[key]) > 2147483647:
			return null
	if int(data.save_version) != VERSION or int(data.content_version) != content_version:
		error_message = "存档/内容版本不兼容；旧文件已保留。"
		return null
	if data.get("run_definition_id") != definition.id:
		error_message = "存档运行配置不存在或不匹配。"
		return null
	if data.get("phase") not in CHECKPOINTS or not data.get("summaries") is Array:
		return null
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
		if entry.night != index + 1 or entry.opening_cash != previous_cash or entry.get("outcome") != "placeholder_peaceful":
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
	state.current_night_index = night
	state.phase = StringName(data.phase)
	state.game_minutes = elapsed
	state.cash = int(data.cash)
	state.run_seed = int(data.run_seed)
	state.closed_at = closed
	state.night_opening_cash = int(data.night_opening_cash)
	state.action_count = int(data.action_count)
	for entry in data.summaries:
		# JSON numbers arrive as floats. Normalize every runtime numeric field.
		state.summaries.append({"night": int(entry.night), "opening_cash": int(entry.opening_cash), "closing_cash": int(entry.closing_cash), "closed_at": int(entry.closed_at), "action_count": int(entry.action_count), "outcome": String(entry.outcome)})
		for key in FinancialSummary.build(RunState.new()):
			if not RunSchema.integer(entry.get(key)) or abs(entry[key]) > 2147483647: return null
			state.summaries.back()[key] = int(entry[key])
	error_message = CounterSaveCodec.restore(data, state, definition, catalog)
	if not error_message.is_empty(): return null
	return state
