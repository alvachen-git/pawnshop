class_name NightMarketRisk
extends RefCounted

const RULE_NOTE := "柜下旧规：夜里接来湿包，莫问来处。包布须在三更封铺前折好封存，需20分钟。货上若浮湿灰，先别转手；东西出手了，留下的包布也不能不管。"
const LAMPS := ["火稳，色暖。", "火苗泛着青色，影子朝柜下那块包布偏去。", "火苗比昨夜细了一圈，青色还没有退。", "灯芯只一根，墙上却映出两簇火。", "火贴着灯油，只剩一线。那块包布还在；再放一夜，恐怕熬不到天明。", "灯芯烧尽了，柜下传来湿布展开的声音。"]

static func selection(state: RunState, visit_id: String) -> Dictionary:
	return VarietySaveCodec.selection(state, visit_id)

static func after_command(state: RunState, visit: CustomerVisit, command: String, detail: String) -> String:
	if visit.night_policy != "wet_cloth": return ""
	var action := ""
	if command == "question" and detail == "origin": action = "taboo"
	elif command == "offer" and visit.status == "bought": action = "purchase"
	if action.is_empty(): return ""
	if state.night_market_history.any(func(r: Dictionary) -> bool: return r.action == action and r.visit_id == visit.visit_id): return ""
	state.night_market_history.append({"action": action, "night": state.current_night_index, "minute": state.game_minutes, "visit_id": visit.visit_id})
	if action == "taboo": return "\n他把一角湿布压在柜边。你挪了挪脚，影子却迟了一步。包布须照旧规封存。"
	match visit.night_aftermath:
		"item": return "\n货面浮出一层湿灰。先别转手，封铺前须把包布封好。"
		"haunt": return "\n身后响起一声滴水。你回头，脚边那道影子却迟了一步。"
	return "\n包布里轻轻叹了一声。再听，柜上已经没有声响。"

static func treated(state: RunState, id: String, night := 2147483647, minute := 540) -> bool:
	return state.night_market_history.any(func(r: Dictionary) -> bool: return r.visit_id == id and r.action == "seal_cloth" and (int(r.night) < night or (int(r.night) == night and int(r.minute) <= minute)))

static func item_pending(state: RunState, id: String, night := 2147483647, minute := 540) -> bool:
	if not state.night_market_enabled or treated(state, id, night, minute): return false
	return state.night_market_history.any(func(r: Dictionary) -> bool: return r.action == "purchase" and r.visit_id == id and selection(state, id).get("night_aftermath") == "item" and (int(r.night) < night or (int(r.night) == night and int(r.minute) <= minute)))

static func unresolved(state: RunState) -> Array[String]:
	var ids: Array[String] = []
	for row in state.night_market_history:
		if row.action not in ["purchase", "taboo"] or row.visit_id in ids or treated(state, row.visit_id): continue
		ids.append(row.visit_id)
	return ids

static func treatment_reason(day: DayController, id: String) -> String:
	if not day.state.night_market_enabled or id not in unresolved(day.state): return "这块包布已经处理过，或不在柜边。"
	if day.state.phase not in [&"open", &"closed_processing"]: return "须在三更封铺前处理包布。"
	if not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or not PawnReturnService.current(day.state).is_empty(): return "请先处理眼前的事情。"
	if day.state.visits.any(func(v: CustomerVisit) -> bool: return v.status in ["active", "waiting"]): return "客人还在柜前，先将眼前这笔生意了结。"
	var cost := int(day.definition.variety.night_market.treatment_minutes)
	if not TimeController.new().can_spend(day.state, day.definition, cost): return "封存需20分钟，离三更已来不及。"
	return ""

static func treat(day: DayController, id: String) -> ActionResult:
	var reason := treatment_reason(day, id)
	if not reason.is_empty(): return ActionResult.new(false, reason)
	var start := day.state.game_minutes
	day.spend_action(int(day.definition.variety.night_market.treatment_minutes))
	day.state.night_market_history.append({"action": "seal_cloth", "visit_id": id, "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes})
	CustomerManager.new().update(day.state)
	return ActionResult.new(true, "你照旧规折好湿布，封进匣里。柜上的灰迹渐渐干了，脚边的影子也归了位。")

static func loss_night(state: RunState, item: ItemInstance) -> int:
	for r in state.night_market_history:
		if r.action == "purchase" and r.visit_id == item.source_visit_id and selection(state, r.visit_id).get("night_aftermath") == "item" and not treated(state, r.visit_id, int(r.night)):
			return int(r.night)
	return 0

static func settle(state: RunState) -> void:
	if not state.night_market_enabled: return
	for item in state.inventory_instances:
		if item.ownership_state != "owned" or loss_night(state, item) != state.current_night_index: continue
		item.ownership_state = "lost"
		EconomyManager.new().commit(state, 0, item.instance_id, "night_loss/" + item.instance_id, "inventory_loss", 0)

# Derived from actual source actions and completed sleeps. Ambient audio never enters here.
static func lamp_level(state: RunState) -> int:
	if not state.night_market_enabled: return 0
	var active := {}
	var grade := 0
	var onset := 0
	for night in range(1, state.current_night_index + 1):
		for row in state.night_market_history:
			if int(row.night) != night: continue
			if row.action == "seal_cloth":
				active.erase(row.visit_id)
				if active.is_empty(): grade = 0; onset = 0
			elif row.action == "taboo" or (row.action == "purchase" and selection(state, row.visit_id).get("night_aftermath") == "haunt"):
				if active.is_empty(): grade = 1; onset = night
				active[row.visit_id] = true
		if not active.is_empty() and onset < night and state.room_history.any(func(r: Dictionary) -> bool: return int(r.night) == night and r.action == "finish_sleep"):
			grade = mini(5, grade + 1)
	return grade

static func finish_sleep(state: RunState) -> void:
	if lamp_level(state) < 5 or state.phase == &"dead": return
	state.phase = &"dead"
	if not state.death_archive.any(func(r: Dictionary) -> bool: return r.run_token == state.run_token): state.death_archive.append(death_record(state))

static func death_record(state: RunState) -> Dictionary:
	var assets := FinancialSummary.build(state)
	return {"run_token": state.run_token, "run_id": String(state.run_definition_id), "night": state.current_night_index, "cash": state.cash, "item_id": "wet_cloth", "rule_id": "night_guest_lamp", "cause": "湿布一直压在柜下。灯火一夜夜淡下去，终于没能等到天明。", "item_name": "柜下湿包布", "inventory_cost": assets.inventory_cost, "pawn_principal": assets.pawn_principal}

static func note(state: RunState) -> String:
	if not state.night_market_enabled: return ""
	var body := RULE_NOTE
	for id in unresolved(state):
		var planned := selection(state, id)
		body += "\n第%d夜留下的湿包布尚未封存。" % int(planned.get("night", 0))
	return body
