class_name TownLife
extends RefCounted

const PROFESSIONS := ["customer_porter", "customer_musician", "customer_washerwoman", "customer_soldier"]
const ITEMS := ["item_abacus", "item_copper_handwarmer", "item_kerosene_lamp", "item_leather_suitcase", "item_erhu", "item_padded_vest"]
const JEWELRY_ITEMS := ["item_silver_earrings", "item_copper_handwarmer", "item_kerosene_lamp", "item_leather_suitcase", "item_erhu", "item_padded_vest"]
const REPAIR := "town_repair"

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("town_life", {}).get("version", 0) == 1

static func items(run: RunDefinition) -> Array:
	return run.variety.get("town_life", {}).get("item_ids", ITEMS)

static func active(state: RunState) -> bool:
	return state.shop_growth.has("town_life")

static func initial() -> Dictionary:
	return {"version":1, "origins":{}, "arrivals":{}}

static func config(state: RunState) -> Dictionary:
	return (state.ghost_catalog.get_definition("runs", state.run_definition_id) as RunDefinition).variety.town_life

# Independent streams: inventory truth and public provenance never depend on this.
# This API is for gameplay code only; presentation must not call it.
static func internal_origin(state: RunState, instance_id: String) -> Dictionary:
	return state.shop_growth.get("town_life", {}).get("origins", {}).get(instance_id, {}).duplicate(true)

static func register_origin(state: RunState, visit: CustomerVisit) -> void:
	if not active(state) or visit.customer_id != "customer_soldier": return
	var origins: Dictionary = state.shop_growth.town_life.origins
	if origins.has(visit.item.instance_id): return
	origins[visit.item.instance_id] = {"source_customer":visit.customer_id, "source_person":visit.person.get("id", ""), "visit_id":visit.visit_id, "night":state.current_night_index, "kind":"looted_from_dead" if VarietyService.rng(state.run_seed, "town/origin/" + visit.visit_id).randi_range(0,99) < int(config(state).soldier_loot_percent) else "ordinary"}

static func pick_candidate(candidates: Array, seed_value: int, key: String) -> Dictionary:
	var professions: Array = []
	for row in candidates:
		if row.customer_id not in professions: professions.append(row.customer_id)
	var profession: String = VarietyService.pick(professions, seed_value, key + "/profession")
	var matches: Array = candidates.filter(func(row: Dictionary) -> bool: return row.customer_id == profession)
	var goods: Array = []
	for row in matches:
		if row.item_id not in goods: goods.append(row.item_id)
	var item_id: String = VarietyService.pick(goods, seed_value, key + "/item")
	return VarietyService.pick(matches.filter(func(row: Dictionary) -> bool: return row.item_id == item_id), seed_value, key + "/context").duplicate(true)

static func variant(item: ItemDefinition, seed_value: int, key: String) -> String:
	var total := 0.0
	for option in item.possible_variants: total += option.weight
	var roll := VarietyService.rng(seed_value, key).randf() * total
	for option in item.possible_variants:
		roll -= option.weight
		if roll < 0: return option.id
	return item.possible_variants.back().id

static func clothing(state: RunState, item_id: String) -> bool:
	return item_id == CoatProcurement.ITEM or (active(state) and item_id in config(state).clothing_ids)

static func clothing_name(state: RunState) -> String:
	return "御寒衣物" if active(state) else "棉袄"

static func prepare(state: RunState, visit: CustomerVisit, item: ItemDefinition) -> void:
	if not active(state) or visit.customer_id not in PROFESSIONS: return
	var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	visit.trade.rounds_left = customer.max_quote_rounds
	visit.trade.patience = customer.patience
	if visit.transaction_modes.is_empty(): visit.transaction_modes.assign(customer.transaction_modes)
	if visit.customer_id == "customer_musician" and item.id == "item_erhu":
		visit.transaction_modes.assign(["pawn"])
		visit.voice.introduction = "这把琴是吃饭的家伙，只肯活当。两成的重息我不接，您开个能周转的数。"
	register_origin(state, visit)

static func activate(state: RunState, visit: CustomerVisit) -> void:
	if not active(state) or visit.customer_id not in PROFESSIONS: return
	var arrivals: Dictionary = state.shop_growth.town_life.arrivals
	if arrivals.has(visit.visit_id): return
	arrivals[visit.visit_id] = {"minute":state.game_minutes}
	if visit.customer_id == "customer_porter":
		var deadline := visit.arrival + int(config(state).porter_window_minutes)
		visit.voice.introduction = "码头还等着卸货。%s前头一回报到%d银元，我就交货；耽搁了，再照原价谈。" % [TimeController.clock_text(1080, deadline), fast_price(state, visit)]
	elif visit.customer_id == "customer_soldier":
		var bands: Dictionary = config(state).soldier_bands
		var score := int(state.social.military)
		var band: String = "friendly" if score >= int(bands.friendly.threshold) else "hostile" if score <= int(bands.hostile.threshold) else "ordinary"
		var terms: Dictionary = bands[band]
		var item := state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
		var value: float = item.find_variant(visit.item.selected_variant_id).true_value if clothing(state, item.id) else item.base_value
		visit.trade.opening_price = maxi(1, roundi(value * float(terms.ask)))
		visit.trade.asking_price = visit.trade.opening_price
		visit.trade.reserve_price = maxi(1, roundi(visit.trade.opening_price * float(terms.reserve)))
		visit.trade.patience = int(terms.patience)
		visit.voice.introduction = {"friendly":"孙长官说过这家铺子。都是熟面孔，价钱好商量。", "ordinary":"这身衣裳您认得。东西在这儿，价钱别开得太难看。", "hostile":"营里提过这家铺子。今夜少跟我绕弯，照价拿钱。"}[band]

static func fast_price(state: RunState, visit: CustomerVisit) -> int:
	return maxi(1, ceili(visit.trade.opening_price * float(config(state).porter_first_offer_percent) / 100.0))

static func fast_available(state: RunState, visit: CustomerVisit) -> bool:
	return active(state) and visit.customer_id == "customer_porter" and visit.trade.offers.is_empty() and state.game_minutes <= visit.arrival + int(config(state).porter_window_minutes)

static func fast_threshold(state: RunState, visit: CustomerVisit) -> int:
	return mini(visit.trade.reserve_price, fast_price(state, visit)) if fast_available(state, visit) else -1

static func repair_question(state: RunState, visit: CustomerVisit, detail: String) -> bool:
	return active(state) and visit.customer_id == "customer_washerwoman" and detail == REPAIR and (state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition).category == "textile"

static func repair(state: RunState, visit: CustomerVisit) -> String:
	var item := state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var truth := item.find_variant(visit.item.selected_variant_id)
	# Choose one real condition clue, never the cosmetic 'form' clue or valuation.
	for id in truth.clue_ids:
		var clue := item.find_clue(id)
		if clue == null or clue.judgement == "unknown": continue
		if id not in visit.item.revealed_clue_ids: visit.item.revealed_clue_ids.append(id)
		return "她翻起布角，指给你看：" + clue.text
	return "她把布面展平：这件的针脚，还得您自己细看。"

static func enrich(model: Dictionary, day: DayController, service: CounterService, visit: CustomerVisit) -> void:
	if not active(day.state): return
	if visit.customer_id == "customer_porter":
		model.trade["profession_notice"] = ("赶工价：首报价至少%d银元，须在%s前提交。" % [fast_price(day.state, visit), TimeController.clock_text(day.definition.opening_minute, visit.arrival + int(config(day.state).porter_window_minutes))] if fast_available(day.state, visit) else "赶工价已过，照眼下价钱商量。")
	if visit.customer_id == "customer_musician" and visit.item.definition_id == "item_erhu": model.trade["profession_notice"] = "这把二胡只办活当，不接两成重息。"
	if model.trade.has("profession_notice"): model.trade.body += "\n" + String(model.trade.profession_notice)
	if repair_question(day.state, visit, REPAIR):
		var reason := service.reason(day, "question", visit.visit_id, REPAIR)
		model.dialogue.buttons.append({"command":"question", "detail":REPAIR, "label":"问织物修补情况 · 5分钟", "enabled":reason.is_empty(), "reason":reason})

static func valid_config(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not RunSchema.integer(value.get("goods_revision", 1)) or int(value.get("goods_revision", 1)) not in [1,2]: return false
	for key in ["start_night", "soldier_loot_percent", "porter_window_minutes", "porter_first_offer_percent"]:
		if not RunSchema.integer(value.get(key)): return false
	if value.start_night < 3 or value.soldier_loot_percent < 0 or value.soldier_loot_percent > 100: return false
	if value.porter_window_minutes < 0 or int(value.porter_window_minutes) % 5 != 0 or value.porter_first_offer_percent < 1 or value.porter_first_offer_percent > 100: return false
	if not value.get("condition_weights") is Array or value.condition_weights.size() != 3: return false
	if value.condition_weights.map(func(weight: Variant) -> int: return int(weight)) != [60,30,10] or value.get("item_ids") != (JEWELRY_ITEMS if value.get("goods_revision", 1) == 2 else ITEMS): return false
	if value.get("clothing_ids") != [CoatProcurement.ITEM,"item_padded_vest"] or value.get("wearable_variants") != ["sound","worn"]: return false
	if not value.get("soldier_bands") is Dictionary: return false
	for key in ["friendly","ordinary","hostile"]:
		var band: Variant = value.soldier_bands.get(key)
		if not band is Dictionary: return false
		if not (band.get("ask") is float or band.get("ask") is int) or not (band.get("reserve") is float or band.get("reserve") is int): return false
		if band.ask <= 0 or band.reserve <= 0 or band.reserve > 1 or not RunSchema.integer(band.get("patience")) or band.patience < 1: return false
	return RunSchema.integer(value.soldier_bands.friendly.get("threshold")) and RunSchema.integer(value.soldier_bands.hostile.get("threshold")) and value.soldier_bands.friendly.threshold > value.soldier_bands.hostile.threshold
