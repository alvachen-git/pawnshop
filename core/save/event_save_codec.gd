class_name EventSaveCodec
extends RefCounted

# Rebuild flags from choices; do not trust a saved unlock list independently.
static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not CounterSaveCodec._string_array(data.get("narrative_flags")) or not data.get("event_history") is Array or not data.get("pending_event_id") is String or not RunSchema.integer(data.get("pending_event_minute")): return "缺少或损坏事件状态。"
	if catalog == null:
		return "" if data.event_history.is_empty() and data.narrative_flags.is_empty() and data.pending_event_id.is_empty() and data.pending_event_minute == -1 and run.event_ids.is_empty() else "恢复事件需要内容目录。"
	var director := EventDirector.new(catalog)
	var replay := RunState.create(run)
	replay.run_seed = state.run_seed
	var last_stamp := -1
	for row in data.event_history:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["event_id", "choice_id", "phase"]) or not CounterSaveCodec._integers(row, ["night", "offered_minute", "minute"]): return "事件历史结构无效。"
		if row.event_id not in run.event_ids: return "事件引用失效。"
		var event := catalog.get_definition("events", row.event_id) as EventDefinition
		var choice := event.find_choice(row.choice_id)
		if choice == null or row.phase != event.phase or row.night < 1 or row.night > state.current_night_index or row.offered_minute < 0 or int(row.offered_minute) % run.time_step != 0 or row.minute != row.offered_minute + choice.minutes or row.minute >= event.window_end: return "事件选择、夜次或耗时无效。"
		if row.night > state.summaries.size() and (row.phase != "pre_open" or row.minute != 0): return "未结算夜不应保存夜内事件。"
		if row.phase == "pre_open" and row.minute != 0: return "开铺前事件时刻无效。"
		if row.night <= state.summaries.size():
			var closed: int = state.summaries[int(row.night) - 1].closed_at
			if row.phase == "open" and row.minute > closed: return "营业事件发生在关门后。"
			if row.phase == "closed_processing" and row.offered_minute < closed: return "关门事件发生在营业时。"
		var rank: int = {"pre_open": 0, "open": 1, "closed_processing": 2}[row.phase]
		var offered_stamp := _stamp(int(row.night), int(row.offered_minute), rank, run)
		if offered_stamp < last_stamp: return "事件历史时间倒序。"
		last_stamp = _stamp(int(row.night), int(row.minute), rank, run)
		replay.current_night_index = int(row.night)
		replay.phase = StringName(row.phase)
		replay.game_minutes = int(row.offered_minute)
		replay.inventory_instances = _inventory_at(state, int(row.night), int(row.offered_minute))
		if director.select_next(replay, run) != event.id: return "事件调度与条件、优先级、权重或次数不一致。"
		for flag in choice.grant_flags:
			if flag not in replay.narrative_flags: replay.narrative_flags.append(flag)
		replay.event_history.append({"event_id": event.id, "choice_id": choice.id, "night": int(row.night), "phase": event.phase, "offered_minute": int(row.offered_minute), "minute": int(row.minute)})
	if replay.narrative_flags != data.narrative_flags: return "叙事标记与已选事件结果不一致。"
	state.narrative_flags = replay.narrative_flags.duplicate()
	state.event_history = replay.event_history.duplicate(true)
	# Before opening, all guaranteed anchors must have been handled.
	for night in state.summaries.size():
		var check := RunState.create(run)
		check.current_night_index = night + 1
		for row in state.event_history:
			if row.night <= night + 1: check.event_history.append(row)
		for id in run.event_ids:
			var event := catalog.get_definition("events", id) as EventDefinition
			if event.kind == "anchor" and director.eligible(check, event): return "已结算夜缺少必需锚点。"
	var pending := director.select_next(state, run)
	if data.pending_event_id != pending or int(data.pending_event_minute) != (state.game_minutes if not pending.is_empty() else -1): return "待处理事件与检查点不一致。"
	state.pending_event_id = pending
	state.pending_event_minute = int(data.pending_event_minute)
	# Buyers introduced by an event must be unlocked before the sale, not later.
	for sale in state.sale_records:
		var buyer := catalog.get_definition("buyers", sale.buyer_id) as BuyerDefinition
		for flag in buyer.required_flags:
			var unlocked := false
			for row in state.event_history:
				if row.night > sale.night or (row.night == sale.night and row.minute > sale.minute): continue
				var event := catalog.get_definition("events", row.event_id) as EventDefinition
				if flag in event.find_choice(row.choice_id).grant_flags: unlocked = true
			if not unlocked: return "销售发生在买家介绍之前。"
	return ""

static func _stamp(night: int, minute: int, phase: int, run: RunDefinition) -> int:
	return (night * (run.night_minutes + 1) + minute) * 3 + phase

static func _inventory_at(state: RunState, night: int, minute: int) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for item in state.inventory_instances:
		var acquired := false
		for visit in state.visit_history:
			if visit.visit_id == item.source_visit_id and (visit.night < night or (visit.night == night and visit.minute <= minute)): acquired = true
		if not acquired: continue
		var held := true
		for sale in state.sale_records:
			if sale.item_instance_id == item.instance_id and (sale.night < night or (sale.night == night and sale.minute <= minute)): held = false
		for ticket in state.pawn_tickets:
			if ticket.item_instance_id == item.instance_id and ticket.status == "redeemed" and (ticket.closed_night < night or (ticket.closed_night == night and ticket.closed_minute <= minute)): held = false
		if held:
			var copy := ItemInstance.new()
			copy.definition_id = item.definition_id
			items.append(copy)
	return items
