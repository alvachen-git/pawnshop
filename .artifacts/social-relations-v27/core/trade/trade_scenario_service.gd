class_name TradeScenarioService
extends RefCounted

static func for_item(run: RunDefinition, item_id: String) -> TradeScenarioDefinition:
	for scenario in run.trade_scenarios:
		if scenario.item_id == item_id: return scenario
	return null

static func for_slot(run: RunDefinition, slot_id: String) -> TradeScenarioDefinition:
	for scenario in run.trade_scenarios:
		if scenario.slot_id == slot_id: return scenario
	return null

static func for_visit(run: RunDefinition, visit: CustomerVisit) -> TradeScenarioDefinition:
	for scenario in run.trade_scenarios:
		if scenario.id == visit.scenario_id: return scenario
	return null

static func prepare(visit: CustomerVisit, scenario: TradeScenarioDefinition, seed_value: int) -> void:
	# A separate per-slot stream keeps ordinary encounters and the mirror independent.
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value + int(scenario.id.hash())) & 0x7fffffff
	visit.scenario_id = scenario.id
	visit.item.selected_variant_id = scenario.variant_ids[rng.randi_range(0, scenario.variant_ids.size() - 1)]
	visit.situation_id = scenario.situations[rng.randi_range(0, scenario.situations.size() - 1)]
	visit.reaction_id = scenario.reactions[rng.randi_range(0, scenario.reactions.size() - 1)]
	if visit.situation_id == "urgent": visit.expires_at = visit.arrival + scenario.urgent_wait_minutes

static func prerequisites(visit: CustomerVisit, question: TradeQuestionDefinition) -> bool:
	return CounterDomainValidator._contains_all(visit.asked_question_ids, question.requires_questions) and CounterDomainValidator._contains_all(visit.item.revealed_clue_ids, question.requires_clues)

static func question_available(day: DayController, visit: CustomerVisit, question: TradeQuestionDefinition) -> bool:
	return prerequisites(visit, question) and (not question.requires_mirror or MirrorEncounterService.witnessed(day.state, visit.visit_id))

static func used(visit: CustomerVisit, scenario: TradeScenarioDefinition, clue_id: String) -> bool:
	for previous in visit.trade.used_clue_ids:
		if scenario.group(previous) == scenario.group(clue_id): return true
	return false

static func known_images(visit: CustomerVisit, scenario: TradeScenarioDefinition) -> Array:
	var result: Array = []
	for row in scenario.images:
		if CounterDomainValidator._contains_all(visit.item.revealed_clue_ids, row.requires_clues):
			result.append({"id": row.id, "label": row.label, "path": row.path})
	return result

static func concede(visit: CustomerVisit, scenario: TradeScenarioDefinition) -> String:
	visit.concession_used = true
	visit.trade.rounds_left -= 1
	if visit.situation_id == "urgent":
		visit.trade.reserve_price = maxi(1, visit.trade.reserve_price - scenario.concession_amount)
		visit.trade.asking_price = maxi(visit.trade.reserve_price, visit.trade.asking_price - scenario.concession_amount)
		return "他又瞧了一眼铺外：“再让%d银元。掌柜，您快定吧。”" % scenario.concession_amount if not visit.person.is_empty() else "他又瞧了一眼船票：“再让%d银元。掌柜，您快定吧。”" % scenario.concession_amount
	visit.trade.patience -= 1
	return "客人把东西往回拢了拢：“我并不急用，何必拿这话催我？”" if not visit.person.is_empty() else "他把表链收拢：“我又不赶路，何必拿这话催我？”"

static func record(day: DayController, visit: CustomerVisit, command: String, detail: String, amount: int, start: int, result: ActionResult) -> void:
	var history: Array = day.state.bargaining_history if visit.scenario_id.is_empty() else day.state.scenario_history
	var entry := {"scenario_id": visit.scenario_id, "visit_id": visit.visit_id, "variant_id": visit.item.selected_variant_id, "situation_id": visit.situation_id, "reaction_id": visit.reaction_id, "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes, "command": command, "detail": detail, "amount": amount, "ok": result.ok, "clues": visit.item.revealed_clue_ids.duplicate(), "questions": visit.asked_question_ids.duplicate(), "used_clues": visit.trade.used_clue_ids.duplicate(), "concession_used": visit.concession_used}
	if command == "belittle":
		entry.belittle_result = {"used": visit.trade.belittle_used, "asking": visit.trade.asking_price, "rounds": visit.trade.rounds_left, "patience": visit.trade.patience}
	history.append(entry)
