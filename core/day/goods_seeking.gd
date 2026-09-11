class_name GoodsSeeking
extends RefCounted

static func reason(state: RunState, target: String) -> String:
	if state.goods_version != 1: return "这局没有寻配茶盏。"
	if PreparationService.used(state, "target", state.current_night_index): return "今夜已经托人定向收货。"
	var item := InventoryManager.new().find(state, target)
	if item == null or item.definition_id != GoodsExpertise.CUP or item.ownership_state != "owned" or "form" not in item.revealed_clue_ids: return "先选一只已看清纹样的自有茶盏。"
	return ""

static func make(state: RunState, run: RunDefinition, catalog: ContentCatalog, target: String, selected: Dictionary) -> Dictionary:
	var item := InventoryManager.new().find(state, target)
	var key := "goods/seek/%d/%s" % [state.current_night_index, target]
	# Reuse the normal creator, with only the eligible cup pools narrowed.
	var filtered: Array = []
	for id in run.variety.customer_ids:
		var customer := catalog.get_definition("customers", id) as CustomerDefinition
		if GoodsExpertise.CUP in customer.item_pool: filtered.append(id)
	var possibilities := []
	for c in run.variety.contexts:
		if c.customer_id in filtered and (state.current_night_index >= 3 or "sell" in c.transaction_modes): possibilities.append(c)
	var context: Dictionary = VarietyService.pick(possibilities, state.run_seed, key + "/person")
	var row := OpeningPreparation.make_row(state, run, catalog, selected.visit_id, int(selected.arrival), "porcelain")
	var customer := catalog.get_definition("customers", context.customer_id) as CustomerDefinition
	row.customer_id = customer.id; row.context_id = context.id; row.item_id = GoodsExpertise.CUP
	row.transaction_modes = context.transaction_modes.duplicate()
	if state.current_night_index < 3: row.transaction_modes.erase("pawn")
	row.situation = context.situation; row.wait_minutes = int(context.wait_minutes)
	row.person.portrait = customer.portrait_asset_id
	var names: Array = customer.persona.names
	var surnames: Array = run.variety.surnames
	var existing: Array = OpeningPreparation.plan(state, run, catalog).filter(func(r: Dictionary) -> bool: return r.visit_id != row.visit_id).map(func(r: Dictionary) -> String: return r.person.name)
	var first := VarietyService.rng(state.run_seed, key + "/name").randi_range(0, names.size() * surnames.size() - 1)
	for offset in names.size() * surnames.size():
		var index := (first + offset) % (names.size() * surnames.size())
		row.person.name = surnames[index / names.size()] + names[index % names.size()]
		if row.person.name not in existing and row.person.name not in FamiliarStories.NAMES: break
	row.terms_id = PawnRedemptionPolicy.terms_for(run, customer, state.run_seed, row.visit_id, row.terms_id)
	row.variant_id = VarietyService.pick(["sound", "flawed", "mended"], state.run_seed, key + "/condition")
	row.goods = {"pattern": int(item.goods.pattern), "side": 1 - int(item.goods.side), "workshop": int(item.goods.workshop) if VarietyService.rng(state.run_seed, key + "/match").randi_range(0, 99) < 50 else 1 - int(item.goods.workshop)}
	return row

# Preparation is replayed before inventory. Only supply the claimed historical
# target here; GoodsSaveCodec later verifies ownership, clues and seeded identity.
static func replay_target(data: Dictionary, state: RunState, target: String) -> bool:
	for row in data.get("inventory_instances", []):
		if not row is Dictionary or row.get("instance_id") != target: continue
		if row.get("definition_id") != GoodsExpertise.CUP or not row.get("goods") is Dictionary or not row.get("revealed_clue_ids") is Array: return false
		if row.goods.size() != 3: return false
		for k in ["pattern", "side", "workshop"]:
			if not RunSchema.integer(row.goods.get(k)) or int(row.goods[k]) not in [0, 1]: return false
		var item := ItemInstance.new(); item.instance_id = target; item.definition_id = GoodsExpertise.CUP
		item.goods = row.goods.duplicate(); item.revealed_clue_ids = row.revealed_clue_ids.duplicate()
		state.inventory_instances = [item]
		return true
	return false
