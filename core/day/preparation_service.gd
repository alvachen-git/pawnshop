class_name PreparationService
extends RefCounted

const BUYER := "buyer_pen_appointment"
const DETAILS := "收货单：第六夜19:00–21:00收钢笔，件数不限。原尖完好或替换笔尖装配正常都收，破损、堵墨的不收。价钱验货后再议。"

static func used(state: RunState, action: String, night := 0) -> bool:
	return state.preparation_history.any(func(row: Dictionary) -> bool: return row.action == action and (night == 0 or row.night == night))

static func count(state: RunState) -> int:
	return state.preparation_history.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index and row.action != "finish").size()

static func reason(state: RunState, run: RunDefinition, action: String) -> String:
	if OpeningPreparation.enabled(run): return OpeningPreparation.reason(state, action)
	if not SevenNightPlan.enabled(run) or state.current_night_index < 4: return "第四夜起可在开铺前准备。"
	if state.phase != &"pre_open" or used(state, "finish", state.current_night_index): return "今夜准备已结束。"
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty(): return "请先处理眼前的事情。"
	if action == "finish": return ""
	if action not in ["investigate", "contact", "visitors"]: return "没有这项准备行动。"
	if used(state, action, state.current_night_index if action == "visitors" else 0): return "这件事已经问过，查看消息不消耗次数。"
	if action != "visitors" and state.current_night_index > 6: return "这桩收货约定已经结束。"
	if count(state) >= 2: return "今夜两次准备已经用完。"
	return ""

static func visitor(state: RunState) -> Dictionary:
	var candidates: Array = state.seven_plan.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index)
	return VarietyService.pick(candidates, state.run_seed, "seven/intel/%d" % state.current_night_index) if not candidates.is_empty() else {}

static func perform(state: RunState, run: RunDefinition, action: String) -> ActionResult:
	var error := reason(state, run, action)
	if not error.is_empty(): return ActionResult.new(false, error)
	var row := {"night": state.current_night_index, "minute": 0, "action": action, "visit_id": ""}
	if action == "visitors": row.visit_id = visitor(state).visit_id
	state.preparation_history.append(row)
	return ActionResult.new(true, {"investigate": DETAILS, "contact": "介绍信已备好，第六夜可持信去见收货人。收货细目还须另打听。", "visitors": "来客的口信记在铺中记事里了。", "finish": "准备妥当，可以开铺了。"}[action])

static func requirements_known(state: RunState) -> bool:
	return used(state, "investigate") or state.current_night_index > 6 or (state.current_night_index == 6 and state.game_minutes >= 60)

static func notice(state: RunState, catalog: ContentCatalog) -> String:
	if state.preparation_version == 1: return OpeningPreparation.notice(state, catalog)
	if state.current_night_index < 4: return ""
	var lines: PackedStringArray = ["茶馆捎来的口信：外埠有人托收旧文房用品，第六夜来收。细目还须打听。" if not requirements_known(state) else "外埠文房收货人第六夜来收货，收货单已问清。"]
	if requirements_known(state): lines.append(DETAILS)
	lines.append("介绍信已备好。" if used(state, "contact") else "尚未取得介绍。最晚第六夜开铺前可托人联系。")
	if state.current_night_index > 6: lines.append("第六夜的收货窗口已过，余货可另找买家，也可留在铺里。")
	for record in state.preparation_history:
		if record.action != "visitors": continue
		var found: Array = state.seven_plan.filter(func(row: Dictionary) -> bool: return row.visit_id == record.visit_id)
		if found.is_empty(): continue
		var row: Dictionary = found[0]
		var item := catalog.get_definition("items", row.item_id) as ItemDefinition
		var start := int(row.arrival) / 60 * 60
		var category: String = {"porcelain": "瓷器", "metal": "金属器", "jewelry": "首饰", "watches": "钟表", "stationery": "文房用具", "textile": "绣品"}.get(item.category, "旧物")
		var intent := "想办活当" if row.transaction_modes == ["pawn"] else ("只想出售" if row.transaction_modes == ["sell"] else "出售、活当都愿谈")
		lines.append("第%d夜来客口信：约%s–%s，有人带%s来，%s。原当户办理若占了时辰，来客也会稍晚。" % [row.night, TimeController.clock_text(1080, start), TimeController.clock_text(1080, start + 60), category, intent])
	return "\n\n".join(lines)

static func buyer_reason(state: RunState, buyer_id: String) -> String:
	if buyer_id != BUYER or state.preparation_version == 1: return ""
	return "尚未取得介绍，请在开铺前联系收货人。" if not used(state, "contact") else ""

static func item_reason(item: ItemInstance, buyer_id: String) -> String:
	if buyer_id != BUYER: return ""
	if item.definition_id != "item_fountain_pen": return "这回只收钢笔。"
	if item.selected_variant_id not in ["sound", "replacement_nib"]: return "笔尖破损或出墨不畅，不合这张收货单。"
	return ""

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if OpeningPreparation.enabled(run): return OpeningPreparation.restore(data, state, run, catalog)
	if not data.get("seven_plan", []) is Array or not data.get("preparation_history", []) is Array: return "七夜编排或准备记录结构无效。"
	if not SevenNightPlan.enabled(run):
		return "旧局混入七夜记录。" if not data.get("seven_plan", []).is_empty() or not data.get("preparation_history", []).is_empty() else ""
	var expected := SevenNightPlan.plan(run, catalog, state.run_seed)
	if VarietySaveCodec.normalize_plan(data.get("seven_plan")) != expected: return "七夜来访编排与种子不符。"
	state.seven_plan.assign(expected)
	var simulator := RunState.new()
	simulator.run_seed = state.run_seed
	simulator.seven_plan = state.seven_plan
	var last := 0
	for row in data.preparation_history:
		if not row is Dictionary or row.size() != 4 or not CounterSaveCodec._integers(row, ["night", "minute"]) or not CounterSaveCodec._text_fields(row, ["action"]) or not row.get("visit_id") is String: return "准备行动记录无效。"
		if row.night < last or row.night > state.current_night_index or row.minute != 0: return "准备行动时刻无效。"
		simulator.current_night_index = int(row.night)
		if not perform(simulator, run, row.action).ok or simulator.preparation_history.back().visit_id != row.visit_id: return "准备行动重复、超额或消息不符。"
		last = int(row.night)
	for night in range(4, state.current_night_index + (0 if state.phase == &"pre_open" else 1)):
		if not used(simulator, "finish", night): return "营业前缺少结束准备记录。"
	state.preparation_history.assign(simulator.preparation_history)
	return ""
