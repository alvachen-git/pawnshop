class_name RecyclerPolicy
extends RefCounted

const BUYER := "buyer_recycler"

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("preopen_recycler_version", 0) == 1

static func rate(seed_value: int, night: int, definition_id: String) -> int:
	return VarietyService.rng(seed_value, "recycler/%d/%s" % [night, definition_id]).randi_range(70, 100)

static func amount(base: float, percent: int) -> int:
	return maxi(1, floori(base * percent / 100.0))

static func price(state: RunState, definition: ItemDefinition, night := 0) -> int:
	return amount(definition.base_value, rate(state.run_seed, state.current_night_index if night == 0 else night, definition.id))

static func spent(state: RunState) -> int:
	var total := 0
	for batch in state.sale_batches:
		if batch.night == state.current_night_index: total += int(batch.get("action_points", 0))
	return total

static func visible(day: DayController, buyer_id: String) -> bool:
	if not enabled(day.definition): return true
	match buyer_id:
		BUYER: return true
		"buyer_lu": return LuIntroduction.unlocked(day.state, day.definition)
		"buyer_pen_appointment": return PreparationService.used(day.state, "investigate") or day.state.current_night_index >= 6
		"buyer_mirror":
			for item in day.state.inventory_instances:
				if item.definition_id == "item_weeping_mirror" and item.ownership_state == "owned" and not MirrorEndingService.released(day.state, item.instance_id): return true
	return false

static func browse_reason(day: DayController) -> String:
	if MilitaryIntroduction.active(day.state) or LuIntroduction.active(day.state) or MirrorEndingService.active(day.state) or not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty(): return "请先处理眼前的事情。"
	return ""

static func trip_reason(day: DayController) -> String:
	if SocialRules.closed(day.state): return "今夜停业，暂不出门交货。"
	if day.state.current_night_index < 2: return "第二夜起可在开铺前交货。"
	if day.state.phase != &"pre_open" or PreparationService.used(day.state, "finish", day.state.current_night_index): return "杂货回收只在开铺前交货。"
	var pending := browse_reason(day)
	if not pending.is_empty(): return pending
	if PreparationService.action_points(day.state, day.definition) < 1: return "今夜行动点已用完。"
	return ""
