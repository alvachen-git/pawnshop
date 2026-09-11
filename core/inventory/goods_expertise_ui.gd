class_name GoodsExpertiseUI
extends RefCounted

static func enrich(model: Dictionary, day: DayController, service: CommerceService) -> void:
	if not GoodsExpertise.enabled(day.definition): return
	model.goods_notes = {}
	model.buttons = model.buttons.filter(func(b: Dictionary) -> bool: return b.command != "inquire" or InventoryManager.new().find(day.state, b.target_id).provenance.status != "unconfirmed")
	for button in model.buttons:
		if button.command == "inquire": button.label = String(button.label).replace("委托来源调查", "查验来历凭据")
	for item in day.state.inventory_instances:
		var def := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
		model.goods_notes[item.instance_id] = GoodsExpertise.description(item, def)
		if item.ownership_state != "owned": continue
		if item.definition_id == GoodsExpertise.FAN and not item.expert_reviewed:
			add(model, day, service, "fan", [item.instance_id], "请行家鉴赏品质 · 6银元 / 20分钟")
		if item.definition_id != GoodsExpertise.CUP: continue
		for other in day.state.inventory_instances:
			if other.definition_id != GoodsExpertise.CUP or other.instance_id == item.instance_id or other.ownership_state != "owned": continue
			var ids := GoodsExpertise.pair_ids(item.instance_id, other.instance_id)
			var certificate := GoodsExpertise.certificate(day.state, ids)
			var label := "货签%d茶盏（第%d夜，成本%d）" % [day.state.inventory_instances.find(other) + 1, other.acquired_night, other.acquisition_price]
			if certificate.is_empty() and item.instance_id < other.instance_id: add(model, day, service, "pair", ids, "与货签%d茶盏验配 · 4银元 / 10分钟" % (day.state.inventory_instances.find(other) + 1))
			elif not certificate.is_empty(): model.goods_notes[item.instance_id] += "\n与%s：%s。" % [label, "原配" if certificate.result == "matched" else "并非原配"]

static func add(model: Dictionary, day: DayController, service: CommerceService, action: String, ids: Array, label: String) -> void:
	var reason := GoodsExpertise.reason(day, service.catalog, action, ids)
	model.buttons.append({"command": "expert_" + action, "target_id": ids[0], "detail": "" if ids.size() == 1 else ids[1], "label": label, "enabled": reason.is_empty(), "reason": reason})

static func sale_pairs(day: DayController, service: CommerceService, buyer: BuyerDefinition) -> Array:
	var result := []
	if not GoodsExpertise.enabled(day.definition): return result
	for record in day.state.expertise_history:
		if record.action != "pair" or record.result != "matched": continue
		var ids: Array = record.item_ids
		var checked := GoodsExpertise.pair_bonus(day.state, service.catalog, buyer, ids, [ids])
		if not checked.error.is_empty(): continue
		var a := InventoryManager.new().find(day.state, ids[0]); var b := InventoryManager.new().find(day.state, ids[1])
		if not service.item_reason(day, a, buyer).is_empty() or not service.item_reason(day, b, buyer).is_empty(): continue
		result.append({"ids": ids.duplicate(), "label": "原配茶盏 · 货签%d＋货签%d" % [day.state.inventory_instances.find(a) + 1, day.state.inventory_instances.find(b) + 1], "bonus": int(checked.bonuses[ids[0]]) + int(checked.bonuses[ids[1]])})
	return result
