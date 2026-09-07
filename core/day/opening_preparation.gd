class_name OpeningPreparation
extends RefCounted

const CATEGORIES := {"porcelain": "瓷器", "metal": "金属器", "jewelry": "首饰", "watches": "钟表", "stationery": "文房", "textile": "绣品"}
const COSTS := {"attract": 3, "target": 0, "tea": 5, "visitors": 0, "investigate": 0, "finish": 0}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("preparation_version", 0) == 1

static func ordinary(row: Dictionary) -> bool:
	return not row.get("context_id", "").is_empty()

# Keep the seeded base intact. Every consumer sees the same replayable overlay.
static func plan(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> Array[Dictionary]:
	var rows := SevenNightPlan.plan(run, catalog, state.run_seed)
	if not enabled(run): return rows
	for record in state.preparation_history:
		if record.action == "attract": rows.append(record.change.duplicate(true))
		elif record.action == "target":
			for index in rows.size():
				if rows[index].visit_id == record.change.visit_id: rows[index] = record.change.duplicate(true); break
	for row in rows:
		if ordinary(row) and PreparationService.used(state, "tea", int(row.night)): row.wait_minutes = int(row.wait_minutes) + 20
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.night < b.night if a.night != b.night else a.arrival < b.arrival)
	return rows

static func known_ids(state: RunState, night: int) -> Array:
	var ids: Array = []
	for record in state.preparation_history:
		if record.night == night and record.action == "visitors": ids.append_array(record.visit_ids)
	return ids

static func reason(state: RunState, action: String, category := "") -> String:
	if state.current_night_index < 2: return "第二夜起可在开铺前准备。"
	if state.phase != &"pre_open" or PreparationService.used(state, "finish", state.current_night_index): return "今夜准备已结束。"
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty(): return "请先处理眼前的事情。"
	if not COSTS.has(action): return "没有这项准备行动。"
	if action == "finish": return ""
	if PreparationService.used(state, action, 0 if action == "investigate" else state.current_night_index): return "这项准备已经做过。已知消息可以免费复看。"
	if action == "investigate" and state.current_night_index not in [4, 5, 6]: return "眼下没有待调查的收货消息。"
	if PreparationService.count(state) >= 2: return "今夜两次准备已经用完。"
	if state.cash < int(COSTS[action]): return "现银不足，需要%d大洋。" % COSTS[action]
	if action == "target" and not category.is_empty() and not CATEGORIES.has(category): return "没有这类收货方向。"
	return ""

static func make_row(state: RunState, run: RunDefinition, catalog: ContentCatalog, id: String, arrival: int, category: String) -> Dictionary:
	var candidates: Array = []
	for context in run.variety.contexts:
		var modes: Array = context.transaction_modes.duplicate()
		if state.current_night_index < 3: modes.erase("pawn")
		if modes.is_empty(): continue
		var customer := catalog.get_definition("customers", context.customer_id) as CustomerDefinition
		for item_id in customer.item_pool:
			var item := catalog.get_definition("items", item_id) as ItemDefinition
			if item.item_type != "normal" or (not category.is_empty() and item.category != category): continue
			candidates.append({"context_id": context.id, "customer_id": customer.id, "item_id": item.id, "transaction_modes": modes, "wait_minutes": int(context.wait_minutes), "situation": context.situation})
	if candidates.is_empty(): return {}
	var key := id + "/preparation/" + category
	var row: Dictionary = VarietyService.pick(candidates, state.run_seed, key).duplicate(true)
	var item := catalog.get_definition("items", row.item_id) as ItemDefinition
	var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
	var sources: Array = []
	if not item.provenance.is_empty():
		for source in ["none", "authentic", "mismatch"]:
			for weight in int(item.provenance.weights[source]): sources.append(source)
	var existing_names: Array = plan(state, run, catalog).filter(func(r: Dictionary) -> bool: return r.visit_id != id).map(func(r: Dictionary) -> String: return r.person.name)
	var names: Array = customer.persona.names
	var surnames: Array = run.variety.surnames
	var first := VarietyService.rng(state.run_seed, key + "/name").randi_range(0, names.size() * surnames.size() - 1)
	var person_name := ""
	for offset in names.size() * surnames.size():
		var index := (first + offset) % (names.size() * surnames.size())
		person_name = surnames[index / names.size()] + names[index % names.size()]
		if person_name not in existing_names: break
	row.merge({"visit_id": id, "night": state.current_night_index, "arrival": arrival,
		"variant_id": VarietyService.pick(item.possible_variants, state.run_seed, key + "/variant").id,
		"source": "" if sources.is_empty() else VarietyService.pick(sources, state.run_seed, key + "/source"),
		"reaction": VarietyService.pick(["admit", "explain", "evade"], state.run_seed, key + "/reaction"),
		"terms_id": VarietyService.pick(run.variety.terms_ids, state.run_seed, key + "/terms"),
		"person": {"id": "person/" + id, "name": person_name, "portrait": customer.portrait_asset_id}})
	return row

static func perform(state: RunState, run: RunDefinition, catalog: ContentCatalog, action: String, category := "") -> ActionResult:
	var error := reason(state, action, category)
	if not error.is_empty(): return ActionResult.new(false, error)
	if action == "target" and category.is_empty(): return ActionResult.new(false, "请先选择收货类别。")
	if action != "target" and not category.is_empty(): return ActionResult.new(false, "这项准备不需要选择类别。")
	var night := state.current_night_index
	var rows: Array = plan(state, run, catalog).filter(func(row: Dictionary) -> bool: return row.night == night)
	var record := {"night": night, "minute": 0, "action": action, "category": category, "cost": int(COSTS[action]), "visit_ids": [], "change": {}}
	var key := "preparation/%d/%s" % [night, action]
	if action == "attract":
		var times: Array = []
		for minute in range(0, 451, 5):
			if rows.all(func(row: Dictionary) -> bool: return absi(int(row.arrival) - minute) >= 15): times.append(minute)
		if times.is_empty(): return ActionResult.new(false, "今夜来客的时辰已排满，无法再招揽。")
		record.change = make_row(state, run, catalog, "%s/%d/prep_extra" % [run.id, night], int(VarietyService.pick(times, state.run_seed, key)), "")
	elif action == "target":
		var known := known_ids(state, night)
		var candidates: Array = rows.filter(func(row: Dictionary) -> bool: return ordinary(row) and not row.has("seven_role") and not row.visit_id.ends_with("/prep_extra") and row.visit_id not in known)
		if candidates.is_empty(): return ActionResult.new(false, "今夜没有可另约收货的普通来客。")
		var selected: Dictionary = VarietyService.pick(candidates, state.run_seed, key)
		record.change = make_row(state, run, catalog, selected.visit_id, int(selected.arrival), category)
	elif action == "visitors":
		var candidates: Array = rows.filter(ordinary)
		for prior in state.preparation_history:
			if prior.night == night and prior.action == "target": record.visit_ids.append(prior.change.visit_id)
		if record.visit_ids.is_empty():
			# Intel must leave an undisclosed ordinary position for a later targeted request.
			var replaceable: Array = candidates.filter(func(row: Dictionary) -> bool: return not row.has("seven_role") and not row.visit_id.ends_with("/prep_extra"))
			if not replaceable.is_empty():
				var reserved: String = VarietyService.pick(replaceable, state.run_seed, key + "/reserve").visit_id
				candidates = candidates.filter(func(row: Dictionary) -> bool: return row.visit_id != reserved)
		while record.visit_ids.size() < 2:
			candidates = candidates.filter(func(row: Dictionary) -> bool: return row.visit_id not in record.visit_ids)
			if candidates.is_empty(): return ActionResult.new(false, "今夜没有足够的来客口信。")
			record.visit_ids.append(VarietyService.pick(candidates, state.run_seed, key + str(record.visit_ids.size())).visit_id)
	if action in ["target", "attract"]:
		if record.change.is_empty(): return ActionResult.new(false, "眼下没有合适的收货人选。")
		record.visit_ids.append(record.change.visit_id)
	state.preparation_history.append(record)
	if record.cost > 0:
		EconomyManager.new().commit(state, -record.cost, "preparation", posting_id(record), "preparation", 0)
	var messages := {"attract": "口信已经送出，今夜会多一位客人带货来。", "target": "已托人捎话，今夜有位客人带%s来。" % CATEGORIES.get(category, "旧物"), "tea": "茶水备好了，今夜普通来客会多等20分钟。", "visitors": "两位来客的口信已记在铺中记事里。", "investigate": PreparationService.DETAILS, "finish": "准备妥当，可以开铺了。"}
	return ActionResult.new(true, messages[action] + "\n现银%d大洋 · 今夜准备剩余%d次。" % [state.cash, 2 - PreparationService.count(state)])

static func posting_id(record: Dictionary) -> String:
	return "preparation/%d/%s" % [record.night, record.action]

static func notice(state: RunState, catalog: ContentCatalog) -> String:
	if state.current_night_index < 2: return ""
	var lines: PackedStringArray = []
	if state.current_night_index == 2:
		lines.append("开铺前可办两件事：招揽客人、托人捎话收货、备茶候客，或打听来客。花费写在各项旁；也可以直接开铺。")
	if state.current_night_index >= 4:
		lines.append(PreparationService.DETAILS if PreparationService.requirements_known(state) else "茶馆捎来的口信：外埠有人第六夜来收旧文房用品，细目还须打听。")
		if state.current_night_index > 6: lines.append("第六夜的收货窗口已过，余货可另找买家，也可留在铺里。")
	var run := catalog.get_definition("runs", state.run_definition_id) as RunDefinition
	var rows := plan(state, run, catalog)
	for record in state.preparation_history:
		if record.action != "visitors": continue
		for id in record.visit_ids:
			var found: Array = rows.filter(func(row: Dictionary) -> bool: return row.visit_id == id)
			if found.is_empty(): continue
			var row: Dictionary = found[0]
			var item := catalog.get_definition("items", row.item_id) as ItemDefinition
			var start := int(row.arrival) / 60 * 60
			var intent := "想办活当" if row.transaction_modes == ["pawn"] else ("只想出售" if row.transaction_modes == ["sell"] else "出售、活当都愿谈")
			lines.append("第%d夜来客口信：约%s–%s，有人带%s来，%s。原当户办理若占了时辰，来客也会稍晚。" % [row.night, TimeController.clock_text(1080, start), TimeController.clock_text(1080, start + 60), CATEGORIES.get(item.category, "旧物"), intent])
	return "\n\n".join(lines)

static func refresh_visits(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> void:
	state.ordinary_selections = state.ordinary_selections.filter(func(row: Dictionary) -> bool: return row.night != state.current_night_index)
	var prefix := "%s/%d/" % [run.id, state.current_night_index]
	state.scenario_selections = state.scenario_selections.filter(func(row: Dictionary) -> bool: return not row.visit_id.begins_with(prefix))
	CustomerManager.new().prepare_night(state, run, catalog)

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("preparation_history") is Array or not data.get("seven_plan") is Array: return "缺少开铺准备记录。"
	var base := SevenNightPlan.plan(run, catalog, state.run_seed)
	if VarietySaveCodec.normalize_plan(data.seven_plan) != base: return "本局基础来客编排不符。"
	var simulator := RunState.create(run)
	simulator.run_seed = state.run_seed
	var last := 0
	for row in data.preparation_history:
		if not row is Dictionary or row.size() != 7 or not CounterSaveCodec._integers(row, ["night", "minute", "cost"]) or not row.get("action") is String or not row.get("category") is String: return "准备行动记录无效。"
		if row.night < last or row.night > state.current_night_index or row.minute != 0: return "准备行动时刻无效。"
		if not row.get("change") is Dictionary or not CounterSaveCodec._string_array(row.get("visit_ids")): return "准备口信或来客记录无效。"
		var normalized: Dictionary = row.duplicate(true)
		for field in ["night", "minute", "cost"]: normalized[field] = int(normalized[field])
		if not row.change.is_empty():
			var changes: Variant = VarietySaveCodec.normalize_plan([row.change])
			if changes == null: return "准备来客记录无效。"
			normalized.change = changes[0]
		simulator.current_night_index = int(row.night)
		simulator.cash = 1000000 # Actual affordability is reconciled by the economic ledger.
		var result := perform(simulator, run, catalog, row.action, row.category)
		if not result.ok or simulator.preparation_history.back() != normalized: return "准备效果、费用或口信与实际行动不符。"
		last = int(row.night)
	for night in range(2, state.current_night_index + (0 if state.phase == &"pre_open" else 1)):
		if not PreparationService.used(simulator, "finish", night): return "缺少开铺前的准备结束记录。"
	state.seven_plan.assign(base)
	state.preparation_history.assign(simulator.preparation_history)
	return ""
