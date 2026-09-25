class_name PawnInterestPolicy
extends RefCounted

const RATES := {"low": 5, "medium": 10, "high": 20}
const CHANCE_OFFSETS := {"low": 10, "medium": 0, "high": -10}
const EVENTS := ["lu_pawn_collateral", "lu_pawn_interest", "lu_pawn_maturity"]
const FLAG := "pawn_unlocked"
const FIXED := {"customer_wealthy_antique": true, "customer_wealthy_comprador": true, "customer_wealthy_silk": false, "customer_wealthy_factory": false, "customer_wealthy_opera": false}

static func enabled(run: RunDefinition) -> bool:
	return run != null and run.variety.get("pawn_interest_version", 0) == 1

static func applies(state: RunState) -> bool:
	return state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs", state.run_definition_id))

static func unlocked(state: RunState, run: RunDefinition) -> bool:
	return not enabled(run) or (state.current_night_index >= 3 and FLAG in state.narrative_flags)

static func fee(principal: int, tier: String) -> int:
	return ceili(float(principal * int(RATES[tier])) / 100.0)

static func chance(base: int, tier: String) -> int:
	return clampi(base + int(CHANCE_OFFSETS[tier]), 0, 100)

static func terms_id(state: RunState, visit: CustomerVisit, customer: CustomerDefinition, tier: String) -> String:
	var original := VarietyService.terms_for(visit, customer)
	if original == FamiliarStories.TERMS: return original
	var roll := VarietyService.rng(state.run_seed, visit.visit_id + "/pawn-redemption").randi_range(0, 99)
	return PawnRedemptionPolicy.REDEEM if PawnRedemptionPolicy.succeeds(chance(customer.pawn_redemption_chance, tier), roll) else PawnRedemptionPolicy.DEFAULT

static func firm(state: RunState, visit: CustomerVisit) -> bool:
	if FIXED.has(visit.customer_id): return FIXED[visit.customer_id]
	if visit.person.get("id", "") == "familiar/seamstress": return false
	return VarietyService.rng(state.run_seed, String(visit.person.get("id", visit.visit_id)) + "/pawn-temperament").randi_range(0, 99) < 25

static func urgent(state: RunState, visit: CustomerVisit) -> bool:
	if WealthyCustomers.is_customer(visit.customer_id):
		var trade := WealthyCustomers.trade(state, visit)
		for key in ["watch_owner", "pearl_owner", "bangle_owner", "porcelain_owner", "camera_owner"]:
			if trade.get(key, {}).has("urgent"): return trade[key].urgent
		return VarietyService.rng(state.run_seed, visit.visit_id + "/pawn-urgency").randi_range(0, 99) < 30
	if visit.person.get("id", "") == "familiar/seamstress": return true
	return VarietySaveCodec.selection(state, visit.visit_id).get("situation", visit.situation_id) == "urgent"

static func refuses_high(state: RunState, visit: CustomerVisit) -> bool:
	return firm(state, visit) or not urgent(state, visit)

static func cue(state: RunState, visit: CustomerVisit) -> String:
	var words := "‘这笔钱今夜要用，息钱咱们好商量。’" if urgent(state, visit) else "‘我不急着用钱，息钱太重，就再问问别家。’"
	if firm(state, visit): words = "‘今夜就得用钱，可两成的重息，我不接。’" if urgent(state, visit) else "‘不赶着用钱，两成的重息，我更不会接。’"
	return words

static func high_recorded(state: RunState, visit_id: String) -> bool:
	return state.social.get("trades", []).any(func(row: Dictionary) -> bool: return row.visit_id == visit_id + "/pawn-interest/high")

static func reputation(state: RunState, visit: CustomerVisit, tier: String, completed: bool) -> String:
	if not applies(state) or not state.social_enabled: return ""
	var high := tier == "high" and not completed
	var low := tier == "low" and completed and not high_recorded(state, visit.visit_id)
	if not high and not low: return ""
	var event_id := visit.visit_id + "/pawn-interest/" + ("high" if high else "low")
	if state.social.trades.any(func(row: Dictionary) -> bool: return row.visit_id == event_id): return ""
	var positive := 0
	var negative := 0
	for row in state.social.trades:
		if row.night == state.current_night_index:
			positive += maxi(0, int(row.delta)); negative += maxi(0, -int(row.delta))
	var rules: Dictionary = SocialRules.config().reputation
	var delta := -mini(2, maxi(0, int(rules.negative_cap) - negative)) if high else mini(2, maxi(0, int(rules.positive_cap) - positive))
	# Share the existing trade cap, but use a separate id from the principal appraisal.
	state.social.trades.append({"visit_id": event_id, "night": state.current_night_index, "opening": visit.trade.opening_price, "flaw_discount": 0, "basis": 0, "price": 0, "mode": "pawn_interest", "outcome": "high_quoted" if high else "low_completed", "delta": delta})
	if delta != 0: SocialRules.change(state, "reputation", delta, event_id)
	var words := "客人听见两成息钱，皱起眉头。这番报价传出去，怕要伤铺子的口碑。" if high else "客人收好当票：‘息钱收得轻，这份情我记下了。’"
	SocialRules.notice(state, String(visit.person.get("name", "来客")) + "：" + words)
	return words

# Use the existing timing question for ordinary visitors and add it for rich
# visitors that do not have a scenario question. Knowledge is earned by asking.
static func timing_question(day: DayController, visit: CustomerVisit, detail: String) -> bool:
	return enabled(day.definition) and detail == "circumstance" and "pawn" in visit.transaction_modes and not EarlyRedemption.is_visit(visit)

static func enrich(model: Dictionary, day: DayController, visit: CustomerVisit) -> void:
	if not enabled(day.definition): return
	model.trade["pawn_interest"] = {"unlocked": unlocked(day.state, day.definition), "rates": RATES.duplicate(), "due_night": day.state.current_night_index + 3}
	if not timing_question(day, visit, "circumstance"): return
	for visual: Dictionary in [model.visual, model.trade.get("visual", {}), model.dialogue.get("visual", {}), model.appraisal.get("visual", {})]:
		if visual.is_empty(): continue
		visual["pawn_background"] = ""
		visual["pawn_terms"] = "三夜为期 · 息费按选定档位结算"
		if visit.pawn_terms_id == FamiliarStories.TERMS: visual.pawn_terms += "\n" + EarlyRedemption.AGREEMENT
	var asked := "circumstance" in visit.asked_question_ids
	if asked:
		var speech: Array = model.dialogue.visual.speech
		var replaced := false
		for row in speech:
			if String(row.question).contains("这笔钱何时"):
				row.answer = cue(day.state, visit); replaced = true
		if not replaced: speech.append({"question": "这笔钱何时要用？", "answer": cue(day.state, visit)})
		model.dialogue.buttons = model.dialogue.buttons.filter(func(b: Dictionary) -> bool: return not (b.command == "question" and b.detail == "circumstance"))
	elif not model.dialogue.buttons.any(func(b: Dictionary) -> bool: return b.command == "question" and b.detail == "circumstance"):
		var error := "剩余营业时间不足。" if not TimeController.new().can_spend(day.state, day.definition, 5) else ""
		model.dialogue.buttons.append({"command": "question", "detail": "circumstance", "label": "问：这笔钱何时要用？ · 5分钟", "enabled": error.is_empty(), "reason": error})
