class_name ProvenanceService
extends RefCounted

const LABELS := {"unchecked": "尚未核验", "verified": "来历已证实", "unconfirmed": "暂无法证实", "mismatch": "凭据与原物有矛盾"}

static func describe(item: ItemInstance) -> String:
	return "" if item.provenance.is_empty() else "来源：" + LABELS[item.provenance.status]

static func known_text(item: ItemInstance, definition: ItemDefinition) -> String:
	var text := describe(item)
	if not item.provenance.is_empty() and item.provenance.status != "unchecked":
		text += "\n" + result_text(item, definition)
		if item.provenance.investigated: text += "\n已委托调查一次。"
	return text

static func outcome(truth: String) -> String:
	return {"none": "unconfirmed", "authentic": "verified", "mismatch": "mismatch"}[truth]

static func check_reason(day: DayController, visit: CustomerVisit, definition: ItemDefinition) -> String:
	if definition.provenance.is_empty() or visit.item.provenance.is_empty(): return "这件东西没有来源核验入口。"
	if "origin" not in visit.asked_question_ids: return "先问清来历，再核对凭据与原物。"
	if visit.item.provenance.status != "unchecked": return "这份来源已经核对过。"
	if day.state.game_minutes + int(definition.provenance.check_minutes) >= visit.expires_at: return "客人将要离开，来不及完成核验。"
	return ""

static func apply(item: ItemInstance, action: String) -> void:
	item.provenance.status = outcome(item.provenance.truth)
	item.provenance.evidence.append(action)
	if action == "inquire": item.provenance.investigated = true

static func record(day: DayController, item: ItemInstance, action: String, start: int) -> void:
	day.state.provenance_history.append({"item_instance_id": item.instance_id, "action": action, "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes, "result": item.provenance.status})

static func result_text(item: ItemInstance, definition: ItemDefinition) -> String:
	return definition.provenance[item.provenance.status]

static func inquiry_reason(day: DayController, item: ItemInstance, definition: ItemDefinition) -> String:
	if item == null or definition == null or item.provenance.is_empty(): return "没有可调查的来源线索。"
	if day.state.phase != &"open" or item.ownership_state != "owned": return "只能在营业时调查铺中自有现货。"
	if item.provenance.investigated or item.provenance.status in ["verified", "mismatch"]: return "来源已查清，或这件物品已调查过。"
	if not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or not PawnReturnService.current(day.state).is_empty() or MirrorEncounterService.new(null).pending(day): return "请先处理眼前的事情。"
	if day.state.cash < int(definition.provenance.inquiry_fee): return "现银不足，未委托调查。"
	if not TimeController.new().can_spend(day.state, day.definition, int(definition.provenance.inquiry_minutes)) or day.state.game_minutes + int(definition.provenance.inquiry_minutes) >= day.definition.night_minutes: return "营业时间不足，未委托调查。"
	return ""

static func inquire(day: DayController, item: ItemInstance, definition: ItemDefinition) -> ActionResult:
	var error := inquiry_reason(day, item, definition)
	if not error.is_empty(): return ActionResult.new(false, error)
	var start := day.state.game_minutes
	day.spend_action(int(definition.provenance.inquiry_minutes))
	apply(item, "inquire")
	record(day, item, "inquire", start)
	EconomyManager.new().commit(day.state, -int(definition.provenance.inquiry_fee), item.instance_id, "inquiry/" + item.instance_id, "provenance_inquiry", 0)
	return ActionResult.new(true, result_text(item, definition))

static func premium(item: ItemInstance, buyer: BuyerDefinition, base: int) -> int:
	if item.provenance.is_empty() or item.provenance.status != "verified": return 0
	return floori(base * int(buyer.provenance.get("premium_bps", 0)) / 10000.0)
