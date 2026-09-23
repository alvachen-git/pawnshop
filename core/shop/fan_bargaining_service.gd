class_name FanBargainingService
extends RefCounted

const COMMAND := "fan_pressure"
const WORDS := "这不是真迹，价钱得再降些。"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("fan_bargaining", {}).get("version", 0) == 1

static func initial() -> Dictionary:
	return {"attempts": {}, "reputation_events": []}

static func data(state: RunState) -> Dictionary:
	return state.shop_growth.get("fan_bargaining", {})

static func attempt(state: RunState, visit: CustomerVisit) -> Dictionary:
	return data(state).get("attempts", {}).get(visit.visit_id, {}) if visit != null else {}

static func asking(state: RunState, visit: CustomerVisit) -> int:
	var row := attempt(state, visit)
	return int(row.asking) if row.get("accepted", false) else visit.trade.asking_price

static func eligible(day: DayController, visit: CustomerVisit) -> bool:
	if not enabled(day.definition) or visit == null: return false
	if not visit.purpose.is_empty() or not visit.night_policy.is_empty() or EarlyRedemption.is_visit(visit): return false
	if visit.item.definition_id != GoodsExpertise.FAN: return false
	var customer := day.state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := day.state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var modes: Array = customer.transaction_modes if visit.transaction_modes.is_empty() else visit.transaction_modes
	return customer.guest_rule.is_empty() and item.item_type == "normal" and item.ghost_rule_id.is_empty() and "sell" in modes and day.definition.variety.fan_bargaining.customer_knowledge.has(customer.id)

static func reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if not eligible(day, visit): return "眼前这笔生意不适合这样谈价。"
	if ShopGrowthService.blocked(day) or MirrorEndingService.active(day.state): return "请先处理眼前的事情。"
	if not detail.is_empty() or amount != 0: return "先谈货，再另行报价。"
	if String(FanAppraisalService.record(day.state, visit.item.instance_id).get("verdict", "")).is_empty(): return "先在鉴物台落笔，记下自己的判断。"
	if visit.trade.belittle_used or not attempt(day.state, visit).is_empty(): return "这份压价说法已经用过，不能再谈一遍。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已经不肯再谈价。"
	var finish := day.state.game_minutes + int(day.definition.variety.fan_bargaining.minutes)
	if finish >= mini(visit.expires_at, day.definition.night_minutes): return "来不及把这轮价谈完，未开始压价。"
	return ""

static func cue(day: DayController, visit: CustomerVisit) -> String:
	if not eligible(day, visit): return ""
	if day.definition.variety.fan_bargaining.customer_knowledge[visit.customer_id] == "informed":
		return "他顺着扇骨看了看：‘这画的笔路，我也看过几本图录。’"
	return "他往门外望了又望：‘画我看不懂，只求眼下换些现钱。’" if visit.situation_id == "urgent" else "他把扇子推近：‘画是谁的笔，我也说不准。’"

static func apply(day: DayController, visit: CustomerVisit) -> String:
	var config: Dictionary = day.definition.variety.fan_bargaining
	var informed: bool = config.customer_knowledge[visit.customer_id] == "informed"
	var percent: int = 0 if informed else int(config.urgent_discount_percent if visit.situation_id == "urgent" else config.ordinary_discount_percent)
	var trade := visit.trade
	trade.belittle_used = true
	trade.rounds_left -= 1
	var row := {"statement": "not_original", "used": true, "accepted": not informed, "percent": percent,
		"before_asking": trade.asking_price, "before_reserve": trade.reserve_price,
		"asking": maxi(1, roundi(trade.asking_price * (100 - percent) / 100.0)),
		"reserve": maxi(1, roundi(trade.reserve_price * (100 - percent) / 100.0)),
		"night": day.state.current_night_index, "minute": day.state.game_minutes}
	if FanConditionService.enabled(day.definition): row["granted_asking"] = row.asking
	data(day.state).attempts[visit.visit_id] = row
	if informed:
		trade.patience -= int(config.informed_patience_cost)
		return "他把扇子转回自己面前：‘真假我自有掂量，这个说法不能让我降价。’\n收购要价仍为%d银元。" % trade.asking_price
	return ("他又望了眼门外：‘我急着用钱，就依您，再让一大截。’" if visit.situation_id == "urgent" else "他迟疑了一会儿：‘既然您这么说，那我再让些。’") + "\n收购要价 %d → %d 银元。仍须另行报价。" % [row.before_asking, row.asking]

static func sale_quote(state: RunState, visit: CustomerVisit, customer: CustomerDefinition, price: int) -> bool:
	var row := attempt(state, visit)
	if not row.get("accepted", false): return TradeController.new().quote(visit.trade, customer, price)
	visit.trade.rounds_left -= 1
	visit.trade.offers.append(price)
	if price >= int(row.reserve): return true
	visit.trade.patience -= customer.terms.failed_quote_cost
	row.asking = maxi(int(row.reserve), int(row.asking) - customer.terms.counter_step)
	return false

static func bought(day: DayController, visit: CustomerVisit, price: int) -> void:
	if not enabled(day.definition): return
	var row := attempt(day.state, visit)
	if not row.get("accepted", false) or visit.item.selected_variant_id != "sound": return
	if int(row.asking) >= int(row.before_asking) or price >= int(row.before_asking): return
	# Later damage concessions must not manufacture a fake-claim concession.
	if FanConditionService.enabled(day.definition) and int(row.granted_asking) >= int(row.before_asking): return
	# Scoped to the owning run, stable when the save library forks an attempt.
	var id := "fan_pressure/purchase/" + visit.visit_id
	var events: Array = data(day.state).reputation_events
	if events.any(func(event: Dictionary) -> bool: return event.id == id): return
	events.append({"id": id, "transaction_id": "purchase/" + visit.visit_id, "item_id": visit.item.instance_id,
		"night": day.state.current_night_index, "delta": int(day.definition.variety.fan_bargaining.reputation_delta),
		"reason": "true_fan_bought_as_fake"})
	if day.state.social_enabled:
		SocialRules.change(day.state, "reputation", int(day.definition.variety.fan_bargaining.reputation_delta), id)

static func expert_confirmation(day: DayController, item: ItemInstance, row: Dictionary) -> String:
	row.reviewed = true
	if row.verdict != "sound": return "\n\n行家已核过这把扇子。此前你未认作名家真迹，这次不增减鉴定名声。"
	var matches := item.selected_variant_id == "sound"
	var appraisal := FanAppraisalService.data(day.state)
	appraisal.standing = clampi(int(appraisal.standing) + (1 if matches else -2), -4, 8)
	return "\n\n" + ("行家认可了你先前认作真迹的判断，眼力添了一份凭据。" if matches else "行家指出这并非名家真迹，你先前的判断失了准头。")
