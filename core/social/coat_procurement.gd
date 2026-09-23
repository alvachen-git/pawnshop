class_name CoatProcurement
extends RefCounted

const ITEM := "item_cotton_coat"

static func stock(state: RunState) -> Array[ItemInstance]:
	return state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.definition_id == ITEM and item.ownership_state == "owned" and item.selected_variant_id in ["sound", "worn"])

static func delivery_reason(state: RunState, detail: String) -> String:
	var payload: Variant = JSON.parse_string(detail)
	if not payload is Dictionary or payload.size() != 2 or not payload.get("ids") is Array or not RunSchema.integer(payload.get("order")): return "请选择三件自有棉袄，一并交货。"
	if state.social.contract.is_empty() or int(payload.order) != int(state.social.contract.number): return "这张采购单已经变动，请重新选货。"
	var ids: Array = payload.ids
	if ids.size() != int(state.social.contract.quantity): return "须选齐三件棉袄，才能一并交货。"
	var seen := {}
	for id in ids:
		if not id is String or seen.has(id): return "同一件棉袄不能重复交货。"
		seen[id] = true
		var item := InventoryManager.new().find(state, id)
		if item == null or item not in stock(state): return "只能交自有、完整或旧而可穿的棉袄；不能挪用在当物。"
	return ""

static func deliver(state: RunState, detail: String) -> void:
	var payload: Dictionary = JSON.parse_string(detail)
	var ids: Array = payload.ids
	# Validation is complete before any inventory/ledger mutation. Apportion the
	# single 50-yuan reward for the existing per-item cost-basis ledger.
	var total := int(state.social.contract.reward)
	var count := ids.size()
	var batch := "military/coats/%d" % int(state.social.contract.number)
	for i in count:
		var share := int(total / count) + (1 if i < total % count else 0)
		CommerceService.commit_sale(state, InventoryManager.new().find(state, ids[i]), "military_procurement", share, batch)
	state.social.contract["delivered_ids"] = ids.duplicate()
	MilitaryService.finish_contract(state, "completed", int(state.social.contract.delta))

static func overlay(state: RunState, rows: Array[Dictionary]) -> void:
	if not state.social_enabled: return
	var config: Dictionary = SocialRules.config().coat
	for row in rows:
		if not ReputationService.ordinary(row) or row.has("seven_role") or row.get("person", {}).get("id", "").begins_with("familiar/"): continue
		# Authored appointments and preparation invitations keep their chosen goods.
		if state.preparation_history.any(func(record: Dictionary) -> bool: return record.action in ["target", "seek", "attract"] and row.visit_id in record.visit_ids): continue
		if row.get("coat_assigned", false): continue
		if VarietyService.rng(state.run_seed, row.visit_id + "/cotton_coat").randi_range(0, 99) >= int(config.chance_percent): continue
		row.item_id = ITEM
		row.variant_id = "sound" if VarietyService.rng(state.run_seed, row.visit_id + "/cotton_condition").randi_range(0, 99) < int(config.sound_percent) else "worn"
		row.source = ""
		row.erase("goods")
		row["coat_assigned"] = true
