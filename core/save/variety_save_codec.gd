class_name VarietySaveCodec
extends RefCounted

static func selections(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("sample_plan", []) is Array or not data.get("buyer_appointment", {}) is Dictionary: return "本局编排结构无效。"
	if OrdinarySamplePlan.enabled(run):
		var full_plan := VarietyService.plan(run, catalog, state.run_seed)
		var appointment := OrdinarySamplePlan.appointment(full_plan, catalog, state.run_seed)
		if normalize_plan(data.get("sample_plan")) != full_plan or normalize_appointment(data.get("buyer_appointment")) != appointment: return "本局来访编排或收货约定与种子不符。"
		state.sample_plan.assign(full_plan)
		state.buyer_appointment = appointment
	elif not data.get("sample_plan", []).is_empty() or not data.get("buyer_appointment", {}).is_empty(): return "旧局不能混入四夜编排。"
	for key in ["ordinary_selections", "provenance_history"]:
		if not data.get(key, []) is Array: return "随机来客或来源记录结构无效。"
	if run.variety.is_empty():
		return "旧局不能混入新来客记录。" if not data.get("ordinary_selections", []).is_empty() or not data.get("provenance_history", []).is_empty() else ""
	if not data.get("ordinary_selections") is Array or not data.get("provenance_history") is Array: return "缺少随机来客或来源记录。"
	var expected := VarietyService.plan(run, catalog, state.run_seed).filter(func(row: Dictionary) -> bool: return row.night <= state.current_night_index)
	var normalized: Array = []
	for row in data.ordinary_selections:
		if not row is Dictionary or not CounterSaveCodec._integers(row, ["night", "arrival"]): return "随机来客结构无效。"
		var copy: Dictionary = row.duplicate(true)
		copy.night = int(copy.night)
		copy.arrival = int(copy.arrival)
		if copy.has("wait_minutes"):
			if not RunSchema.integer(copy.wait_minutes): return "来客等待期限无效。"
			copy.wait_minutes = int(copy.wait_minutes)
		normalized.append(copy)
	if normalized != expected: return "来客身份、物品或来源与本局编排不符。"
	state.ordinary_selections.assign(expected)
	return ""

static func selection(state: RunState, visit_id: String) -> Dictionary:
	for row in state.ordinary_selections:
		if row.visit_id == visit_id: return row
	return {}

static func restore_sources(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog, visits: Dictionary, acquisitions: Dictionary) -> String:
	if run.variety.is_empty(): return ""
	# Other codecs reconcile these histories later; check shapes before reading them.
	for key in ["scenario_history", "pawn_tickets", "sale_records", "pawn_returns"]:
		if not data.get(key) is Array: return "来源核验所需的交易历史缺失。"
		for row in data[key]:
			if not row is Dictionary: return "交易历史结构无效。"
			match key:
				"scenario_history":
					if not CounterSaveCodec._text_fields(row, ["visit_id", "command"]) or not CounterSaveCodec._integers(row, ["night", "start", "minute"]) or not row.get("ok") is bool or not row.get("detail") is String: return "柜台历史结构无效。"
				"pawn_tickets":
					if not CounterSaveCodec._text_fields(row, ["item_instance_id", "status"]) or not CounterSaveCodec._integers(row, ["closed_night"]): return "当票历史结构无效。"
				"sale_records":
					if not CounterSaveCodec._text_fields(row, ["item_instance_id", "buyer_id"]) or not CounterSaveCodec._integers(row, ["night", "minute"]) or not catalog.has_definition("buyers", row.buyer_id): return "销售历史结构无效。"
				"pawn_returns":
					if not CounterSaveCodec._integers(row, ["night", "minute"]): return "回访历史结构无效。"
	var simulated: Dictionary = {}
	for id in visits: simulated[id] = visits[id].item
	var last_stamp := -1
	for row in data.provenance_history:
		if not row is Dictionary or not CounterSaveCodec._text_fields(row, ["item_instance_id", "action", "result"]) or not CounterSaveCodec._integers(row, ["night", "start", "minute"]): return "来源调查记录结构无效。"
		if row.size() != 6: return "来源记录含有未知字段。"
		var visit_id: String = row.item_instance_id.trim_prefix("item/")
		if not simulated.has(visit_id): return "来源记录不属于实际来客。"
		var item: ItemInstance = simulated[visit_id]
		var def := catalog.get_definition("items", item.definition_id) as ItemDefinition
		if def.provenance.is_empty(): return "此物没有来源调查内容。"
		var stamp := int(row.night) * (run.night_minutes + 1) + int(row.start)
		if row.night < 1 or row.night > state.summaries.size() or row.start < 0 or row.minute > state.summaries[int(row.night)-1].closed_at or row.minute >= run.night_minutes or int(row.start) % run.time_step != 0 or stamp < last_stamp: return "来源调查时刻无效。"
		if row.action == "counter":
			var visit: CustomerVisit = visits[visit_id]
			if item.provenance.status != "unchecked" or row.minute != row.start + int(def.provenance.check_minutes) or row.start < visit.arrival or row.minute >= visit.expires_at or selection(state, visit_id).night != row.night: return "来源核验不在实际接待时段。"
			if not data.scenario_history.any(func(h: Dictionary) -> bool: return h.visit_id == visit_id and h.command == "verify_source" and h.start == row.start and h.minute == row.minute and h.ok): return "来源核验缺少柜台行动。"
			if not data.scenario_history.any(func(h: Dictionary) -> bool: return h.visit_id == visit_id and h.command == "question" and h.detail == "origin" and h.minute <= row.start and h.ok): return "尚未询问来源就核验。"
		elif row.action == "inquire":
			if not acquisitions.has(visit_id) or item.provenance.investigated or item.provenance.status in ["verified", "mismatch"] or row.minute != row.start + int(def.provenance.inquiry_minutes): return "来源调查重复或前提不足。"
			var bought: Dictionary = acquisitions[visit_id]
			if row.night < bought.night or (row.night == bought.night and row.start < bought.minute): return "先调查后收货。"
			for ticket in data.pawn_tickets:
				if ticket.item_instance_id == item.instance_id and (ticket.status != "defaulted" or row.night <= ticket.closed_night): return "只能调查已经留作现货的当物。"
			for sale in data.sale_records:
				if sale.item_instance_id == item.instance_id and (row.night > sale.night or (row.night == sale.night and row.minute > sale.minute - (catalog.get_definition("buyers", sale.buyer_id) as BuyerDefinition).action_minutes)): return "出售后不能再调查原物。"
			for h in data.scenario_history:
				if h.night == row.night and h.start < row.minute and h.minute > row.start: return "调查与柜台行动耗时重叠。"
			for h in data.pawn_returns:
				if h.night == row.night and row.start < h.minute: return "当户回访未办结前不能调查。"
			for sale in data.sale_records:
				var buyer := catalog.get_definition("buyers", sale.buyer_id) as BuyerDefinition
				if sale.night == row.night and sale.minute > row.start and sale.minute - buyer.action_minutes < row.minute: return "调查与出货耗时重叠。"
		else: return "未知来源调查动作。"
		ProvenanceService.apply(item, row.action)
		if row.result != item.provenance.status: return "来源结论与原物真相不符。"
		var normalized: Dictionary = row.duplicate(true)
		for key in ["night", "start", "minute"]: normalized[key] = int(row[key])
		state.provenance_history.append(normalized)
		last_stamp = int(row.night) * (run.night_minutes + 1) + int(row.minute)
	for item in state.inventory_instances:
		if item.provenance != simulated[item.source_visit_id].provenance: return "库存来源证据与调查历史不符。"
	return ""

static func normalize_plan(value: Variant) -> Variant:
	if not value is Array: return null
	var result: Array = []
	for raw in value:
		if not raw is Dictionary: return null
		var row: Dictionary = raw.duplicate(true)
		for key in ["night", "arrival", "wait_minutes"]:
			if not row.has(key): continue
			if not RunSchema.integer(row[key]): return null
			row[key] = int(row[key])
		result.append(row)
	return result

static func normalize_appointment(value: Variant) -> Variant:
	if not value is Dictionary: return null
	var row: Dictionary = value.duplicate(true)
	for key in ["night", "window_start", "window_end", "capacity"]:
		if not RunSchema.integer(row.get(key)): return null
		row[key] = int(row[key])
	return row

static func validate_timing(state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	for source in state.provenance_history:
		for event in state.event_history:
			if event.night == source.night and event.offered_minute < source.minute and event.minute > source.start: return "来源行动与剧情办理耗时重叠。"
		var pending_mirrors := {}
		for encounter in state.mirror_history:
			if encounter.night != source.night: continue
			var definition := MirrorEncounterService.find_definition(run, encounter.encounter_id)
			var cost := definition.peek_minutes if encounter.action.begins_with("peek") else (definition.pursue_minutes if encounter.action.begins_with("pursue") else 0)
			if encounter.minute > source.start and encounter.minute - cost < source.minute: return "来源行动与窥镜耗时重叠。"
			if encounter.action == "peek": pending_mirrors[encounter.visit_id] = encounter.minute
			elif pending_mirrors.has(encounter.visit_id):
				if source.start >= pending_mirrors[encounter.visit_id] and source.start < encounter.minute: return "窥镜未决时不能办理来源。"
				pending_mirrors.erase(encounter.visit_id)
		for treatment in state.risk_history:
			if treatment.night != source.night or treatment.action not in ["cover", "uncover"]: continue
			var item := InventoryManager.new().find(state, treatment.item_id)
			var rule := RiskManager.new(catalog).rule_for(item)
			var cost := rule.cover_minutes if treatment.action == "cover" else rule.uncover_minutes
			if treatment.minute > source.start and treatment.minute - cost < source.minute: return "来源行动与存放处理耗时重叠。"
	return ""
