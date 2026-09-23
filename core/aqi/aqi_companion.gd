class_name AqiCompanion
extends RefCounted

static func enabled(run: RunDefinition) -> bool:
	return "aq_stay_8" in run.event_ids

# Presence is derived from authenticated event choices, phase and clock. No second state store.
static func model(day: DayController, events: EventDirector, counter: CounterService, mirror_busy: bool) -> Dictionary:
	if not enabled(day.definition): return {}
	var s := day.state
	var n := s.current_night_index
	var flags := s.narrative_flags
	var extended := FirstDebt.enabled(day.definition) and n >= 11
	var present := n >= 8 and (n <= 10 or extended) and s.phase == &"open" and s.game_minutes < 240 and "aq_seated" in flags and "aq_left_%d" % n not in flags and "aq_refused_%d" % n not in flags
	if extended and FirstDebt.left_today(s): present = false
	var busy := mirror_busy or not s.risk_pending.is_empty() or not s.pending_event_id.is_empty() or not PawnReturnService.current(s).is_empty() or counter.customers.active(s) != null
	if extended and (FirstDebt.chen_waiting(s) or DragonSearch.waiting(s)): busy = true
	var result := {"visible": present, "available": present and not busy, "token": s.run_token, "night": n, "minute": s.game_minutes, "topics": [], "busy_reason": "先招呼客人，等会儿再聊。"}
	if not present: return result
	for topic in ["chat", "paper", "leave"]:
		var id := "aq_%s_%d" % [topic, n]
		if extended: id = "fd_aqi_leave" if topic == "leave" else "fd_aqi_" + (["thread", "boat", "box"][(n - 11) % 3] if topic == "chat" else ["thread", "boat", "box"][(n - 10) % 3])
		var event := events.catalog.get_definition("events", id) as EventDefinition
		var chosen := ""
		for row in s.event_history:
			if row.event_id == id and (id != "fd_aqi_leave" or row.night == n): chosen = row.choice_id
		var entry := {"id": id, "topic": topic, "label": {"chat": "聊两句", "paper": "一起理理纸", "leave": "今天先回去吧"}[topic], "title": event.title, "text": event.body, "chosen": chosen, "buttons": []}
		if not chosen.is_empty():
			entry.text = event.find_choice(chosen).result
		elif (extended and FirstDebt.reason(day, counter, id, event.choices[0].id).is_empty()) or events.eligible(s, event):
			for option in event.choices:
				if option.available(flags, s.inventory_instances): entry.buttons.append({"target_id": id, "detail": option.id, "label": option.label, "enabled": not busy})
		result.topics.append(entry)
	return result

static func old_debt(day: DayController, events: EventDirector) -> Dictionary:
	if not enabled(day.definition): return {}
	var lines: Array[String] = []
	for id in ["aq_drawer", "aq_floorplan", "aq_old_ticket"]:
		for row in day.state.event_history:
			if row.event_id != id: continue
			var event := events.catalog.get_definition("events", id) as EventDefinition
			var text := event.find_choice(row.choice_id).result
			if id == "aq_drawer": text = "旧《阴账》上写着：尚欠七账。没有金额，也没有收讫印记。"
			lines.append(event.title + "\n\n" + text)
	return {"title": "旧事", "text": "\n\n——\n\n".join(lines) if not lines.is_empty() else "旧账还收在柜里，尚未翻查。"}
