class_name EventDirector
extends RefCounted

const RANK := {"anchor": 0, "conditional": 1, "random": 2}
var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func eligible(state: RunState, event: EventDefinition) -> bool:
	if String(state.phase) != event.phase or state.current_night_index < event.night_min or state.current_night_index > event.night_max or state.game_minutes < event.window_start or state.game_minutes >= event.window_end: return false
	if not CounterDomainValidator._contains_all(state.narrative_flags, event.required_flags): return false
	for flag in event.excluded_flags:
		if flag in state.narrative_flags: return false
	var purchases := 0
	for row in state.ledger_entries:
		var slot: String = event.presentation.get("purchase_slot_id", "")
		if not slot.is_empty() and not String(row.item_instance_id).ends_with("/" + slot): continue
		if row.kind == "acquisition" and (row.night < state.current_night_index or (row.night == state.current_night_index and row.minute <= state.game_minutes)): purchases += 1
	if purchases < int(event.presentation.get("required_purchases", 0)): return false
	for id in event.required_items:
		var found := false
		for item in state.inventory_instances:
			if item.definition_id == id and item.ownership_state in ["owned", "pledged"]: found = true
		if not found: return false
	var count := 0
	var optional_today := 0
	for row in state.event_history:
		var previous := catalog.get_definition("events", row.event_id) as EventDefinition
		if row.event_id == event.id:
			count += 1
			if state.current_night_index - int(row.night) <= event.cooldown and not event.presentation.get("hotspots", false): return false
		if row.night == state.current_night_index:
			if previous.kind != "anchor": optional_today += 1
			if row.event_id in event.conflicts_with or event.id in previous.conflicts_with: return false
	# One optional strong event per night; anchors have a separate guaranteed lane.
	if event.kind != "anchor" and optional_today >= 1: return false
	return count < event.max_count

func select_next(state: RunState, run: RunDefinition) -> String:
	var candidates: Array[EventDefinition] = []
	for id in run.event_ids:
		var event := catalog.get_definition("events", id) as EventDefinition
		if eligible(state, event) and _can_finish_any(state, event): candidates.append(event)
	if candidates.is_empty(): return ""
	candidates.sort_custom(func(a: EventDefinition, b: EventDefinition) -> bool:
		if RANK[a.kind] != RANK[b.kind]: return RANK[a.kind] < RANK[b.kind]
		if a.priority != b.priority: return a.priority > b.priority
		return a.id < b.id)
	if candidates[0].kind != "random": return candidates[0].id
	var top_priority := candidates[0].priority
	var total := 0
	for event in candidates:
		if event.priority == top_priority: total += event.weight
	var rng := RandomNumberGenerator.new()
	# Stable IDs/order and persisted history make selection independent of UI reads.
	rng.seed = state.run_seed + state.current_night_index * 104729 + state.event_history.size() * 7919
	var roll := rng.randi_range(1, total)
	for event in candidates:
		if event.priority != top_priority: continue
		roll -= event.weight
		if roll <= 0: return event.id
	return ""

func poll(state: RunState, run: RunDefinition) -> void:
	if not state.pending_event_id.is_empty(): return
	state.pending_event_id = select_next(state, run)
	state.pending_event_minute = state.game_minutes if not state.pending_event_id.is_empty() else -1

func _can_finish_any(state: RunState, event: EventDefinition) -> bool:
	for choice in event.choices:
		if choice.available(state.narrative_flags) and state.game_minutes + choice.minutes < event.window_end: return true
	return false

func choose(day: DayController, event_id: String, choice_id: String) -> ActionResult:
	if event_id.is_empty() or event_id != day.state.pending_event_id: return ActionResult.new(false, "这件事已经处理，或当前没有此事件。")
	var event := catalog.get_definition("events", event_id) as EventDefinition
	var choice := event.find_choice(choice_id)
	if choice == null or not eligible(day.state, event) or not choice.available(day.state.narrative_flags): return ActionResult.new(false, "事件或选择已不可用。")
	if day.state.game_minutes + choice.minutes >= event.window_end: return ActionResult.new(false, "剩余时间不足以完成此选择。")
	if choice.minutes > 0:
		var result := day.spend_action(choice.minutes)
		if not result.ok: return result
	for flag in choice.grant_flags:
		if flag not in day.state.narrative_flags: day.state.narrative_flags.append(flag)
	day.state.event_history.append({"event_id": event.id, "choice_id": choice.id, "night": day.state.current_night_index, "phase": event.phase, "offered_minute": day.state.pending_event_minute, "minute": day.state.game_minutes})
	day.state.pending_event_id = ""
	day.state.pending_event_minute = -1
	poll(day.state, day.definition)
	return ActionResult.new(true, choice.result)

func model(day: DayController, message: String) -> Dictionary:
	var body := "铺中记事\n当前没有待处理的消息，可以继续经营。\n\n" + message
	var buttons: Array = []
	if not day.state.pending_event_id.is_empty():
		var event := catalog.get_definition("events", day.state.pending_event_id) as EventDefinition
		body = "%s · %s\n\n%s\n\n" % [event.title, event.speaker, event.body]
		for choice in event.choices:
			if not choice.available(day.state.narrative_flags): continue
			var reason := "" if day.state.game_minutes + choice.minutes < event.window_end else "时间不足"
			buttons.append({"command": "choose", "target_id": event.id, "detail": choice.id, "label": choice.label + (" · %d分钟" % choice.minutes if choice.minutes > 0 else ""), "enabled": reason.is_empty(), "reason": reason})
	var history := "往事\n"
	for row in day.state.event_history:
		var event := catalog.get_definition("events", row.event_id) as EventDefinition
		history += "\n第%d夜 · %s\n%s\n" % [row.night, event.title, event.find_choice(row.choice_id).result]
	var model := {"body": body, "history": history if not day.state.event_history.is_empty() else "", "buttons": buttons, "pending_id": day.state.pending_event_id, "presentation": {}}
	if not day.state.pending_event_id.is_empty():
		var event := catalog.get_definition("events", day.state.pending_event_id) as EventDefinition
		model.presentation = event.presentation.duplicate(true)
		model.title = event.title
		model.speaker = event.speaker
		model.text = event.body
		model.feedback = ""
		if not day.state.event_history.is_empty() and day.state.event_history.back().event_id == event.id:
			model.feedback = event.find_choice(day.state.event_history.back().choice_id).result.replace("{accounts}", FeeService.describe(day.state, day.definition))
	return model
