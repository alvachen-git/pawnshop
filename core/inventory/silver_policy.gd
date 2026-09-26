class_name SilverPolicy
extends RefCounted

const BUYER := "buyer_silversmith"
const FLAG := "silver_trade_unlocked"
const EVENTS := ["silver_greeting", "silver_goods", "silver_farewell"]
const MATERIALS := ["silver", "silver_plated", "imitation", "other"]
const ORIGINS := ["ordinary", "inherited", "corpse", "burial"]
const BULL := [110, 120, 130, 140, 180]
const BEAR := [90, 80, 70, 60, 40]

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("silver_trade", {}).get("version", 0) == 1

static func enabled_state(state: RunState) -> bool:
	return state.run_definition_id == &"silver_market"

# Changes are durable and replay-verified: an invitation survives later losses.
static func invited_night(state: RunState) -> int:
	if not enabled_state(state): return 0
	for row in state.social.get("changes", []):
		if row.key == "reputation" and int(row.after) > 15: return int(row.night)
	return 0

static func unlocked(state: RunState) -> bool:
	return enabled_state(state) and FLAG in state.narrative_flags

static func due(state: RunState) -> bool:
	var night := invited_night(state)
	return night > 0 and state.current_night_index > night

static func active(state: RunState) -> bool:
	return enabled_state(state) and state.phase == &"pre_open" and state.pending_event_id in EVENTS and not MilitaryIntroduction.active(state)

static func market(seed_value: int, night: int) -> Dictionary:
	var cycle := (maxi(1, night) - 1) / 5
	var regime := VarietyService.rng(seed_value, "silver/regime/0").randi_range(0, 2)
	for index in range(1, cycle + 1):
		var options := [0, 1, 2]; options.erase(regime)
		regime = options[VarietyService.rng(seed_value, "silver/regime/%d" % index).randi_range(0, 1)]
	var day := (maxi(1, night) - 1) % 5
	var percent: int = BULL[day] if regime == 0 else BEAR[day] if regime == 2 else VarietyService.rng(seed_value, "silver/flat/%d" % night).randi_range(90, 110)
	return {"regime": regime, "day": day + 1, "percent": percent}

static func rate(state: RunState, night := 0) -> int:
	return market(state.run_seed, state.current_night_index if night == 0 else night).percent

static func amount(value: int, percent: int) -> int:
	return maxi(1, roundi(value * percent / 100.0))

static func price(state: RunState, item: ItemInstance, definition: ItemDefinition, night := 0) -> int:
	return amount(GoodsExpertise.value(item, definition), rate(state, night))

# Source is an explicit content fact, independent of provenance paperwork.
static func attach(item: ItemInstance, run: RunDefinition) -> void:
	if not enabled(run): return
	var specification: Dictionary = run.variety.silver_trade.items.get(item.definition_id, {})
	var variant: Dictionary = specification.get("variants", {}).get(item.selected_variant_id, {})
	item.silver_trade = {"material": variant.get("material", specification.get("material", "other")), "origin": variant.get("origin", specification.get("origin", "ordinary"))}

static func item_reason(item: ItemInstance, definition: ItemDefinition) -> String:
	if definition.category != "jewelry": return "只收银饰，旁的器物不收。"
	if item.silver_trade.get("material", "other") != "silver": return "非实银饰件，银楼不收。"
	if item.silver_trade.get("origin", "") in ["corpse", "burial"]: return "尸身物、陪葬物，银楼不收。"
	if item.silver_trade.get("origin", "") not in ORIGINS: return "来路尚不明，银楼暂不收。"
	return ""

static func trip_reason(day: DayController) -> String:
	if not unlocked(day.state): return "尚未与银楼掌柜约定收货。"
	return RecyclerPolicy.trip_reason(day).replace("杂货回收", "银楼")

static func model(base: Dictionary, day: DayController, catalog: ContentCatalog) -> Dictionary:
	var event := catalog.get_definition("events", day.state.pending_event_id) as EventDefinition
	var choice := event.choices[0]
	base.active_id = String(event.id); base.customer = "银楼掌柜 · 登门拜访"; base.item = ""; base["itemless"] = true
	base.context_actions = {"customer": [{"id": "dialogue", "label": "交谈", "enabled": true}], "item": []}
	base.visual = {"customer_id": "silver_owner", "portrait_asset": "silver.owner", "customer_name": "银楼掌柜", "attitude": "街口银楼的掌柜", "deadline": "", "introduction": "听街坊提起您的铺子，特来认个门。", "intent": "登门拜访", "item_asset": "", "item_name": "", "item_status": "", "estimate": "", "clues": [], "speech": []}
	base["case_dialogue"] = {"key": base.active_id, "auto_open": true, "pre_open_story": true, "sentence_pages": true, "speaker": "银楼掌柜", "narration_speaker": "柜前", "text": event.body, "buttons": [{"command": "silver_intro", "target_id": base.active_id, "detail": String(choice.id), "label": choice.label, "enabled": true, "reason": ""}]}
	base.trade.body = "银楼掌柜此来认门。"; base.appraisal.body = "柜上没有待验的货物。"
	return base
