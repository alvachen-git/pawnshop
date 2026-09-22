class_name MarketService
extends RefCounted

static func plan(run: RunDefinition, seed_value: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if run.market.is_empty(): return rows
	var config: Dictionary = run.market
	var previous := ""
	for index in range(0, run.total_nights + 1):
		var candidates: Array = config.demands.filter(func(d: Dictionary) -> bool: return d.id != previous)
		var demand: Dictionary = VarietyService.pick(candidates, seed_value, "market/demand/%d" % index)
		var minute := 0 if index == 0 else VarietyService.rng(seed_value, "market/time/%d" % index).randi_range(int(config.change_start) / run.time_step, int(config.change_end) / run.time_step) * run.time_step
		rows.append({"id": "market/%d" % index, "night": maxi(1, index), "minute": minute, "demand_id": demand.id})
		previous = demand.id
	return rows

static func current(run: RunDefinition, seed_value: int, night: int, minute: int) -> Dictionary:
	var found: Dictionary = {}
	for row in plan(run, seed_value):
		if row.night < night or (row.night == night and row.minute <= minute): found = row
	return found

static func demand(run: RunDefinition, row: Dictionary) -> Dictionary:
	if row.is_empty(): return {}
	for entry in run.market.demands:
		if entry.id == row.demand_id: return entry
	return {}

static func sync(state: RunState, run: RunDefinition) -> void:
	if run.market.is_empty(): return
	state.market_history.assign(plan(run, state.run_seed).filter(func(row: Dictionary) -> bool:
		return row.night < state.current_night_index or (row.night == state.current_night_index and row.minute <= state.game_minutes)))

static func category(day: DayController) -> String:
	return String(demand(day.definition, current(day.definition, day.state.run_seed, day.state.current_night_index, day.state.game_minutes)).get("category", ""))

static func is_special(run: RunDefinition, buyer: BuyerDefinition) -> bool:
	return not run.market.is_empty() and buyer != null and buyer.id == run.market.buyer_id

static func history_text(day: DayController) -> String:
	var lines: PackedStringArray = []
	for row in day.state.market_history:
		var entry := demand(day.definition, row)
		lines.append("第%d夜 %s · %s\n%s" % [row.night, TimeController.clock_text(day.definition.opening_minute, row.minute), entry.title, entry.body])
	return "\n\n".join(lines)
