class_name MirrorSaveCodec
extends RefCounted

# Reconstruct ordinary appraisal plus externally sourced evidence in acquisition order.
static func evidence(history: Variant, entry: Dictionary, item: ItemDefinition, run: RunDefinition) -> Variant:
	if not history is Array: return null
	var external: Array = []
	for row in history:
		if not row is Dictionary: return null
		if row.get("visit_id") == entry.source_visit_id and row.get("action") == "peek":
			var definition := MirrorEncounterService.find_definition(run, row.get("encounter_id", ""))
			if definition == null or not CounterSaveCodec._string_array(row.get("prior_actions")): return null
			if row.prior_actions != entry.completed_action_ids.slice(0, row.prior_actions.size()): return null
			if not definition.clue_id.is_empty(): external.append({"at": row.prior_actions.size(), "clue": definition.clue_id})
	if external.size() > 1: return null
	var attainable: Array = []
	for index in entry.completed_action_ids.size() + 1:
		for source in external:
			if source.at == index and source.clue not in attainable: attainable.append(source.clue)
		if index == entry.completed_action_ids.size(): break
		var action := item.find_action(entry.completed_action_ids[index])
		if action == null or not CounterDomainValidator._contains_all(attainable, action.requires_clues): return null
		for clue_id in action.reveals:
			if clue_id in item.find_variant(entry.selected_variant_id).clue_ids and clue_id not in attainable: attainable.append(clue_id)
	return attainable

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("mirror_history") is Array: return "铜镜遭遇记录缺失。"
	if data.mirror_history.is_empty(): return ""
	if catalog == null or run.mirror_encounters.is_empty(): return "本运行没有铜镜遭遇。"
	var visits: Dictionary = {}
	var endings: Dictionary = {}
	for ending in state.visit_history: endings[ending.visit_id] = ending
	for night in range(1, SaveTimeline.trading_nights(state) + 1):
		var sample := RunState.create(run)
		sample.current_night_index = night
		sample.run_seed = state.run_seed
		sample.preparation_history = state.preparation_history.duplicate(true)
		CustomerManager.new().prepare_night(sample, run, catalog)
		for visit in sample.visits: visits[visit.visit_id] = visit
	var manager := RiskManager.new(catalog)
	var last_end := -1
	for row in data.mirror_history:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["encounter_id", "visit_id", "mirror_id", "action"]) or not CounterSaveCodec._integers(row, ["night", "minute"]) or not CounterSaveCodec._string_array(row.get("prior_actions")): return "铜镜遭遇记录结构无效。"
		var definition := MirrorEncounterService.find_definition(run, row.encounter_id)
		var night := int(row.night)
		var minute := int(row.minute)
		if definition == null or night < 1 or night > SaveTimeline.trading_nights(state) or minute % run.time_step != 0 or not visits.has(row.visit_id): return "铜镜遭遇引用或时间无效。"
		if row.visit_id != "%s/%d/%s" % [run.id, night, definition.slot_id]: return "铜镜遭遇来客不符。"
		var visit: CustomerVisit = visits[row.visit_id]
		var previous := MirrorEncounterService.stage(state, row.visit_id)
		if row.action not in (["peek", "peek_expired", "decline"] if previous.is_empty() else (["pursue", "pursue_expired", "stop"] if previous == "peek" else [])): return "铜镜遭遇选择重复或顺序无效。"
		var cost := definition.peek_minutes if row.action.begins_with("peek") else (definition.pursue_minutes if row.action.begins_with("pursue") else 0)
		var start := minute - cost
		var stamp := night * (run.night_minutes + 1) + start
		var closing: int = SaveTimeline.closing(state, night)
		if stamp < last_end or start < maxi(definition.start_minute, visit.arrival) or start >= mini(visit.expires_at, closing) or minute > run.night_minutes: return "铜镜遭遇不在有效营业窗口。"
		last_end = stamp + cost
		var ending: Dictionary = endings[row.visit_id]
		var expired: bool = minute >= mini(visit.expires_at, run.night_minutes)
		if row.action.ends_with("_expired") != expired or ending.minute < minute: return "铜镜遭遇发生于离店之后。"
		for other_id in visits:
			var other: CustomerVisit = visits[other_id]
			if other_id != row.visit_id and other_id.begins_with("%s/%d/" % [run.id, night]) and other.arrival <= visit.arrival and endings[other_id].minute > start: return "铜镜遭遇来客尚未上柜。"
		var mirror := InventoryManager.new().find(state, row.mirror_id)
		if mirror == null or mirror.definition_id != definition.mirror_item_id or not manager.held_at(state, mirror, night, start) or not manager.held_at(state, mirror, night, minute): return "窥镜时未持有对应铜镜。"
		var cloth := false
		for treatment in data.get("risk_history", []):
			if not treatment is Dictionary or not CounterSaveCodec._integers(treatment, ["night", "minute"]): return "铜镜存放记录无效。"
			if treatment.get("item_id") != row.mirror_id: continue
			if treatment.get("action") in ["cover", "uncover", "retreat"] and (treatment.night < night or (treatment.night == night and treatment.minute <= start)): cloth = treatment.action != "uncover"
			if cost > 0 and treatment.night == night and treatment.get("action") in ["cover", "uncover"]:
				var rule := manager.rule_for(mirror)
				var treatment_cost := rule.cover_minutes if treatment.action == "cover" else rule.uncover_minutes
				if treatment.minute > start and treatment.minute - treatment_cost < minute: return "窥镜与覆镜耗时重叠。"
		if cost > 0 and cloth: return "红布未揭，无法窥镜。"
		var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
		for action in row.prior_actions:
			if item.find_action(action) == null: return "窥镜前鉴定记录无效。"
		var copy: Dictionary = row.duplicate(true)
		copy.night = night
		copy.minute = minute
		state.mirror_history.append(copy)
	return ""
