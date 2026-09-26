class_name SpecialGuests
extends RefCounted

const NAME := "？？？"
const QUEST_FLAG := "special_bundle_quest_eligible"
const ORDINARY := ["item_blue_bowl", "item_brass_holder", "item_silver_hairpin", "item_pocket_watch", "item_inkstone", "item_clay_teapot", "item_silk_panel", "item_fountain_pen", "item_silver_ring", "item_silver_lock", "item_folding_fan", "item_tea_cup", "item_cotton_coat"]
const LUXURY := ["item_luxury_embroidery", "item_luxury_gold_bangle", "item_luxury_gold_watch", "item_luxury_mantel_clock", "item_luxury_pearl_necklace", "item_luxury_jade_pendant", "item_luxury_album", "item_luxury_porcelain_vase", "item_luxury_repeater", "item_luxury_silver_service"]

static func enabled(run: RunDefinition) -> bool:
	return int(run.variety.get("special_guests", {}).get("version", 0)) in [1, 2, 3]

static func active(state: RunState) -> bool:
	return state.shop_growth.has("special_guests")

static func initial() -> Dictionary:
	return {"targets": {}, "plans": {}, "seen": {}, "history": [], "swap_rolls": {}, "closed_stage": 0, "closed_due": 4, "closed_failed": false}

static func data(state: RunState) -> Dictionary:
	return state.shop_growth.get("special_guests", {})

static func config(state: RunState) -> Dictionary:
	var run := state.ghost_catalog.get_definition("runs", state.run_definition_id) as RunDefinition
	return run.variety.special_guests

static func anonymous(visit: CustomerVisit) -> bool:
	return visit.person.get("name", "") == NAME

static func late(state: RunState, visit: CustomerVisit) -> bool:
	return active(state) and anonymous(visit) and visit.night_policy in ["one_quote", "wet_cloth"]

static func available(state: RunState, row: Dictionary) -> bool:
	return not NightMarketPlan.protected(row) and not row.get("wealthy", false) and not row.has("special_key") and not WealthyCustomers.invited(state, row) and row.visit_id not in OpeningPreparation.known_ids(state, int(row.night)) and not row.visit_id.ends_with("/prep_extra")

static func pick_item(seed_value: int, key: String, ordinary_percent := 80, extra: Array = []) -> String:
	var pool: Array = ORDINARY + extra if VarietyService.rng(seed_value, key + "/tier").randi_range(0, 99) < ordinary_percent else LUXURY
	return VarietyService.pick(pool, seed_value, key + "/item")

static func target_night(state: RunState, rows: Array[Dictionary], key: String, window: Array) -> int:
	if data(state).targets.has(key): return int(data(state).targets[key])
	var nights: Array = []
	for n in range(int(window[0]), int(window[1]) + 1):
		if config(state).closed_nights.any(func(v: Variant) -> bool: return int(v) == n): continue
		if rows.any(func(r: Dictionary) -> bool: return r.night == n and available(state, r)): nights.append(n)
	var target := -1 if nights.is_empty() else int(VarietyService.pick(nights, state.run_seed, "special/" + key + "/night"))
	data(state).targets[key] = target
	return target

static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not enabled(run): return rows
	var n := state.current_night_index
	var d := data(state)
	var key := str(n)
	for index in run.variety.special_guests.hat_windows.size():
		target_night(state, rows, "hat/%d" % index, run.variety.special_guests.hat_windows[index])
	target_night(state, rows, "wet", run.variety.special_guests.wet_window)
	if not d.plans.has(key):
		var changes: Array = []
		var today := rows.filter(func(r: Dictionary) -> bool: return r.night == n)
		var closed_due: bool = not d.closed_failed and int(d.closed_stage) < 3 and n >= int(d.closed_due)
		if closed_due:
			var pool := today.filter(func(r: Dictionary) -> bool: return r.customer_id == GhostGuests.CLOSED or available(state, r))
			# An explicit return appointment survives a fully reserved ordinary roster.
			var seat: Dictionary = pool[0] if not pool.is_empty() else {"visit_id": "%s/%d/bundle_appointment" % [run.id, n], "night": n, "arrival": 300}
			changes.append(make_row(state, catalog, seat, "closed/%d" % int(d.closed_stage), "closed"))
		var windows: Array = run.variety.special_guests.hat_windows
		for index in windows.size() + 1:
			var wet: bool = index == windows.size()
			var id := "wet" if wet else "hat/%d" % index
			var window: Array = run.variety.special_guests.wet_window if wet else windows[index]
			if d.seen.has(id) or n < int(window[0]) or n > int(window[1]): continue
			var target := target_night(state, rows, id, window)
			if target < 0 or n < target or closed_due or SocialRules.closed(state): continue
			var pool := today.filter(func(r: Dictionary) -> bool: return available(state, r) and not changes.any(func(c: Dictionary) -> bool: return c.visit_id == r.visit_id))
			if pool.is_empty(): continue
			var old: Dictionary = VarietyService.pick(pool, state.run_seed, "special/" + id + "/seat/" + key)
			changes.append(make_row(state, catalog, old, id, "wet_cloth" if wet else "one_quote"))
		if timed(state): changes = schedule_times(state, today, changes)
		d.plans[key] = changes
	for change in d.plans[key]:
		if not rows.any(func(r: Dictionary) -> bool: return r.visit_id == change.visit_id and r.night == n):
			rows.append(change.duplicate(true))
			continue
		for i in rows.size():
			if rows[i].visit_id == change.visit_id and rows[i].night == n:
				rows[i] = change.duplicate(true)
	return rows

static func make_row(state: RunState, catalog: ContentCatalog, old: Dictionary, key: String, policy: String) -> Dictionary:
	var row: Dictionary = old.duplicate(true)
	var closed := policy == "closed"
	var town_items: Array = TownLife.config(state).item_ids if TownLife.active(state) else []
	var item_id := "item_clay_teapot" if closed else pick_item(state.run_seed, "special/" + key, int(config(state).ordinary_percent), town_items)
	var item := catalog.get_definition("items", item_id) as ItemDefinition
	row.merge({"customer_id": GhostGuests.CLOSED if closed else "customer_hawker" if policy == "one_quote" else "customer_citizen", "context_id": "", "item_id": item_id, "variant_id": VarietyService.pick(item.possible_variants, state.run_seed, "special/" + key + "/variant").id, "source": "", "reaction": "evade", "situation": "ordinary", "terms_id": "", "transaction_modes": ["sell"], "wait_minutes": 90 if closed else 70, "special_key": key, "person": {"id": "special/" + key, "name": NAME, "portrait": "asset.customer_hawker" if closed or policy == "one_quote" else "asset.customer_citizen"}}, true)
	if policy == "wet_cloth" and WetGoodsRisk.enabled(state): row.person.portrait = "special.wet_bundle_v45"
	if TownLife.active(state) and item.id in town_items: row.variant_id = TownLife.variant(item, state.run_seed, "special/" + key + "/variant")
	row.erase("goods")
	if not closed:
		row["night_policy"] = policy
		row["night_aftermath"] = "held_audio" if policy == "wet_cloth" else "fright"
	return row

static func prepare(state: RunState, visit: CustomerVisit, row: Dictionary, item: ItemDefinition) -> void:
	if not active(state) or not row.has("special_key"): return
	visit.person.name = NAME
	if timed(state):
		# New schedules store absolute clock minutes, independent of redemption delays.
		visit.arrival = int(row.arrival)
		visit.expires_at = visit.arrival + int(row.wait_minutes)
	if String(row.special_key).begins_with("closed/"):
		if timed(state) and String(row.special_key) != "closed/2" and not data(state).closed_failed:
			visit.voice.completed = "他收好银元，在门边停了一下：‘下回我还夜深了来。掌柜，莫太早落闩。’"
		return
	var normal := maxi(1, roundi(item.base_value * 1.2))
	if WealthyCustomers.is_item(item.id):
		# Initialize existing appraisal truth with a neutral sale profile.
		# Restore identity before presenting or transacting with this visitor.
		var cid := visit.customer_id
		var voice := visit.voice.duplicate(true)
		visit.customer_id = "customer_wealthy_silk"
		WealthyCustomers.prepare(state, visit)
		normal = visit.trade.opening_price
		visit.customer_id = cid
		visit.voice = voice
	if item.id == CoatProcurement.ITEM:
		normal = maxi(1, roundi(float(SocialRules.config().coat.sound_value if row.variant_id == "sound" else SocialRules.config().coat.worn_value) * 1.2))
	if TownLife.active(state) and item.id == "item_padded_vest": normal = maxi(1, roundi(item.find_variant(row.variant_id).true_value * 1.2))
	visit.trade.opening_price = maxi(1, roundi(normal * float(config(state).wet_discount))) if visit.night_policy == "wet_cloth" else maxi(1, roundi(item.base_value * 0.9))
	visit.trade.asking_price = visit.trade.opening_price
	visit.trade.reserve_price = maxi(1, roundi(visit.trade.opening_price * 0.85))
	visit.trade.rounds_left = 1 if visit.night_policy == "one_quote" else 3
	visit.voice.introduction = "他把毡帽压低，将东西搁在柜上：‘货可以看，价只报一回。不合适，我就走。’" if visit.night_policy == "one_quote" else "包布滴着水，地上却没有湿痕。他将东西推到灯下：‘掌柜看好，价钱好商量。’"
	visit.voice.completed = "他收起银元，转身消失在门外。"
	visit.voice.origin = "他抖了抖袖口：‘经手留下的旧物。’"
	visit.scenario_id = ""

static func activate(state: RunState, visit: CustomerVisit) -> void:
	if not active(state): return
	var row := VarietySaveCodec.selection(state, visit.visit_id)
	if row.has("special_key") or visit.customer_id == GhostGuests.SWAP:
		var key := "swap" if visit.customer_id == GhostGuests.SWAP else String(row.special_key)
		if not data(state).seen.has(key):
			data(state).seen[key] = {"night": state.current_night_index, "visit_id": visit.visit_id}
			data(state).history.append({"kind": "arrive", "key": key, "visit_id": visit.visit_id, "night": state.current_night_index, "minute": state.game_minutes})

static func finish(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not active(state): return
	var row := VarietySaveCodec.selection(state, visit.visit_id)
	if not row.has("special_key") and visit.customer_id != GhostGuests.SWAP: return
	var key := "swap" if visit.customer_id == GhostGuests.SWAP else String(row.special_key)
	data(state).history.append({"kind": "finish", "key": key, "visit_id": visit.visit_id, "night": state.current_night_index, "minute": state.game_minutes, "outcome": outcome})
	if not key.begins_with("closed/"): return
	var d := data(state)
	if outcome != "bought": d.closed_failed = true; return
	if d.closed_failed: return
	d.closed_stage = int(d.closed_stage) + 1
	if int(d.closed_stage) == 3:
		if QUEST_FLAG not in state.narrative_flags: state.narrative_flags.append(QUEST_FLAG)
	else: d.closed_due = int(config(state).closed_nights[int(d.closed_stage)])

static func quote_failed(state: RunState, visit: CustomerVisit) -> void:
	if not active(state) or visit.customer_id != GhostGuests.CLOSED: return
	data(state).closed_failed = true
	data(state).history.append({"kind": "quote_failed", "visit_id": visit.visit_id, "night": state.current_night_index, "minute": state.game_minutes})

static func suspend(state: RunState) -> void:
	if not active(state): return
	var d := data(state)
	if not d.closed_failed and int(d.closed_stage) < 3 and int(d.closed_due) <= state.current_night_index:
		d.closed_due = state.current_night_index + 1

static func swap_roll(state: RunState, visit: CustomerVisit) -> bool:
	if not active(state): return true
	if anonymous(visit) or SocialRules.closed(state) or state.current_night_index < 5 or state.current_night_index > 12: return false
	var rolls: Dictionary = data(state).swap_rolls
	var key := str(state.current_night_index)
	if rolls.has(key): return false
	var accepted := VarietyService.rng(state.run_seed, "special/swap/" + key).randi_range(0, 99) < int(config(state).swap_percent)
	rolls[key] = accepted
	return accepted

static func held_items(state: RunState) -> Array[String]:
	var result: Array[String] = []
	if not active(state): return result
	for item in state.inventory_instances:
		if item.acquisition_type != "purchase" or item.ownership_state != "owned": continue
		var row := VarietySaveCodec.selection(state, item.source_visit_id)
		if row.get("special_key") == "wet": result.append(item.instance_id)
	return result

static func price_reason(state: RunState, visit: CustomerVisit, command: String) -> String:
	if not late(state, visit): return ""
	if command in ["luxury_pressure", "gramophone_claim", "watch_bluff", "watch_claim", "camera_claim", "pearl_claim", "porcelain_claim", "bangle_claim"] or (visit.night_policy == "one_quote" and command in ["fan_pressure", "condition_pressure", "intimidate"]):
		return "请直接报出收购价。"
	return ""

static func enrich(model: Dictionary, day: DayController, service: CounterService, visit: CustomerVisit) -> void:
	if not active(day.state) or not anonymous(visit): return
	model.customer = NAME + "\n" + String(visit.voice.get("introduction", ""))
	model.visual.customer_name = NAME
	if WetGoodsRisk.enabled(day.state) and visit.night_policy == "wet_cloth": model.visual.portrait_asset = "special.wet_bundle_v45"
	for feature in ["appraisal", "dialogue", "trade"]:
		if model[feature].get("visual", {}) is Dictionary and not model[feature].get("visual", {}).is_empty():
			model[feature].visual.customer_name = NAME
			if WetGoodsRisk.enabled(day.state) and visit.night_policy == "wet_cloth": model[feature].visual.portrait_asset = "special.wet_bundle_v45"
	if not late(day.state, visit): return
	for key in ["gramophone_claims", "watch_claims", "pearl_claims", "bangle_claims", "camera_claims", "porcelain_claims"]:
		model.trade.erase(key)
	model.trade.can_offer = service.reason(day, "offer", visit.visit_id, "", 1).is_empty()
	model.trade.can_pawn = false
	model.trade.asking_price = visit.trade.asking_price
	model.trade.body = String(visit.voice.introduction) + "\n要价%d银元 · 剩余报价%d次。" % [visit.trade.asking_price, visit.trade.rounds_left]
	model.trade.buttons = model.trade.buttons.filter(func(b: Dictionary) -> bool: return price_reason(day.state, visit, b.command).is_empty())
	model.trade.visual.visit_constraint = "只听一次正式报价。" if visit.night_policy == "one_quote" else "只办卖断。"
	model.trade.visual.asking = visit.trade.asking_price
	model.trade.visual.erase("fan_statement")
	model.trade.visual.erase("fan_judgement")

# Version 3 keeps its clock rules separate from v44/v45 journal replay.
static func timed(state: RunState) -> bool:
	return active(state) and int(config(state).version) >= 3

static func window(state: RunState, policy: String) -> Array:
	return config(state).arrival_windows[policy]

static func swap_time_allowed(state: RunState, visit: CustomerVisit) -> bool:
	if not timed(state): return true
	var band := window(state, "swap")
	return visit.arrival >= int(band[0]) and visit.arrival <= int(band[1]) and state.game_minutes >= int(band[0]) and state.game_minutes <= int(band[1])

static func schedule_times(state: RunState, today: Array, changes: Array) -> Array:
	var delay := 0
	for row in PawnReturnService.plan(state.pawn_tickets.map(func(t: PawnTicket) -> Dictionary: return t.to_data()), state.current_night_index, state.ghost_catalog, FamiliarStories.history_data(state)):
		if state.ghost_version == 1 and state.person_deaths.any(func(d: Dictionary) -> bool: return d.person_id == row.get("person", {}).get("id", "")): continue
		delay += int(row.minutes)
	var occupied: Dictionary = {}
	for row in today: occupied[row.visit_id] = int(row.arrival) + delay
	var scheduled: Array = []
	for row in changes:
		var previous: int = int(occupied.get(row.visit_id, -1))
		occupied.erase(row.visit_id)
		var policy := "closed" if String(row.special_key).begins_with("closed/") else String(row.night_policy)
		var band := window(state, policy)
		var candidates: Array = []
		# Prefer breathing room; crowded appointment nights may use adjacent five-minute slots.
		for gap in [15, 5]:
			for minute in range(int(band[0]), int(band[1]) + 1, 5):
				if occupied.values().all(func(other: Variant) -> bool: return absi(minute - int(other)) >= gap): candidates.append(minute)
			if not candidates.is_empty(): break
		if candidates.is_empty():
			if previous >= 0: occupied[row.visit_id] = previous
			continue
		row.arrival = int(VarietyService.pick(candidates, state.run_seed, "special/" + String(row.special_key) + "/arrival/" + str(state.current_night_index)))
		occupied[row.visit_id] = row.arrival
		scheduled.append(row)
	return scheduled
