class_name GoodsExpertise
extends RefCounted

const FAN := "item_folding_fan"
const CUP := "item_tea_cup"
const PATTERNS := ["折梅", "兰草"]

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("goods_expertise_version", 0) == 1

static func traits(seed_value: int, visit_id: String) -> Dictionary:
	return {"pattern": VarietyService.rng(seed_value, visit_id + "/cup/pattern").randi_range(0, 1), "side": VarietyService.rng(seed_value, visit_id + "/cup/side").randi_range(0, 1), "workshop": VarietyService.rng(seed_value, visit_id + "/cup/workshop").randi_range(0, 1)}

static func attach(rows: Array, run: RunDefinition, seed_value: int) -> void:
	if not enabled(run): return
	for row in rows:
		if row.item_id == CUP and not row.has("goods"): row.goods = traits(seed_value, row.visit_id)

static func value(item: ItemInstance, definition: ItemDefinition) -> int:
	if definition.expertise.get("kind") == "fan" and not item.expert_reviewed: return int(definition.expertise.unreviewed_value)
	return definition.find_variant(item.selected_variant_id).true_value

static func pair_ids(a: String, b: String) -> Array:
	var ids := [a, b]; ids.sort(); return ids

static func paired(a: ItemInstance, b: ItemInstance) -> bool:
	return a != null and b != null and a.instance_id != b.instance_id and a.definition_id == CUP and b.definition_id == CUP and not a.goods.is_empty() and not b.goods.is_empty() and a.goods.pattern == b.goods.pattern and a.goods.side != b.goods.side and a.goods.workshop == b.goods.workshop

static func certificate(state: RunState, ids: Array) -> Dictionary:
	for row in state.expertise_history:
		if row.action == "pair" and row.item_ids == ids: return row
	return {}

static func description(item: ItemInstance, definition: ItemDefinition) -> String:
	if item.definition_id == FAN:
		return "行家鉴赏：" + String(definition.expertise.results[item.selected_variant_id]) if item.expert_reviewed else "尚未经行家鉴赏，买家先按普通旧扇收。"
	if item.definition_id == CUP and "form" in item.revealed_clue_ids:
		return "%s纹 · %s式。纹样相近不等于原配，可带两只自有茶盏请行家验配。" % [PATTERNS[int(item.goods.pattern)], "左" if int(item.goods.side) == 0 else "右"]
	return ""

static func reason(day: DayController, catalog: ContentCatalog, action: String, ids: Array) -> String:
	if not enabled(day.definition): return "这局没有行家复核。"
	if action not in ["fan", "pair"] or ids.size() != (1 if action == "fan" else 2): return "请选好要复核的货物。"
	if not CounterSaveCodec._string_array(ids): return "复核货物重复或无效。"
	if day.state.phase != &"open": return "开铺营业后才能委托复核。"
	if not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or not PawnReturnService.current(day.state).is_empty() or MirrorEncounterService.new(catalog).pending(day): return "请先处理眼前的事情。"
	for id in ids:
		var item := InventoryManager.new().find(day.state, id)
		if item == null or item.ownership_state != "owned" or item.definition_id != (FAN if action == "fan" else CUP): return "只能复核铺中自有的对应现货。"
	var first := InventoryManager.new().find(day.state, ids[0])
	if (action == "fan" and first.expert_reviewed) or (action == "pair" and not certificate(day.state, pair_ids(ids[0], ids[1])).is_empty()): return "这份结论已经记下，可免费复看。"
	var fee := 6 if action == "fan" else 4
	var minutes := 20 if action == "fan" else 10
	if day.state.cash < fee: return "现银不足，未委托复核。"
	if not TimeController.new().can_spend(day.state, day.definition, minutes) or day.state.game_minutes + minutes >= day.definition.night_minutes: return "来不及在封铺前完成复核。"
	return ""

static func perform(day: DayController, catalog: ContentCatalog, action: String, ids: Array) -> ActionResult:
	var error := reason(day, catalog, action, ids)
	if not error.is_empty(): return ActionResult.new(false, error)
	ids = ids.duplicate(); ids.sort()
	var first := InventoryManager.new().find(day.state, ids[0])
	var definition := catalog.get_definition("items", first.definition_id) as ItemDefinition
	var fee := 6 if action == "fan" else 4
	var start := day.state.game_minutes
	var result := String(first.selected_variant_id) if action == "fan" else ("matched" if paired(first, InventoryManager.new().find(day.state, ids[1])) else "different")
	var spent := day.spend_action(20 if action == "fan" else 10)
	if not spent.ok: return spent
	if action == "fan": first.expert_reviewed = true
	var id := "expertise/%d" % (day.state.expertise_history.size() + 1)
	day.state.expertise_history.append({"id": id, "action": action, "item_ids": ids, "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes, "fee": fee, "result": result})
	EconomyManager.new().commit(day.state, -fee, first.instance_id, id, "expertise", 0)
	var message := String(definition.expertise.results[result]) if action == "fan" else ("两盏原配：纹样相对，底足制式一致。完好成对交给认配的买家，可另算原配价。" if result == "matched" else "两盏并非原配：纹样、左右式样或底足制式不合，仍可各自出售。")
	return ActionResult.new(true, message)

static func pair_bonus(state: RunState, catalog: ContentCatalog, buyer: BuyerDefinition, item_ids: Array, pairs: Array, require_owned := true) -> Dictionary:
	var bonuses := {}; var seen := []
	for pair in pairs:
		if not pair is Array or pair.size() != 2 or not CounterSaveCodec._string_array(pair): return {"error": "原配货单无效。"}
		var ids := pair_ids(pair[0], pair[1])
		for id in ids:
			if id not in item_ids or id in seen: return {"error": "同一件货不能重复计入原配。"}
			seen.append(id)
		var a := InventoryManager.new().find(state, ids[0]); var b := InventoryManager.new().find(state, ids[1])
		var record := certificate(state, ids)
		if record.is_empty() or record.result != "matched" or not paired(a, b) or a.selected_variant_id != "sound" or b.selected_variant_id != "sound": return {"error": "须选择已经验配且完好的两只茶盏。"}
		if require_owned and (a.ownership_state != "owned" or b.ownership_state != "owned"): return {"error": "原配货物已经出柜。"}
		if buyer.id not in ["buyer_collector", "buyer_lu"]: return {"error": "这位买家只按单件收货。"}
		var service := CommerceService.new(catalog)
		var bonus := floori((service.base_quote(a, buyer) + service.base_quote(b, buyer)) * 0.25)
		bonuses[ids[0]] = (bonus + 1) / 2
		bonuses[ids[1]] = bonus / 2
	return {"error": "", "bonuses": bonuses}
