class_name MilitaryPlaque
extends RefCounted

const DESCRIPTION := "孙大元赠的军方照应牌，已经挂在铺中。\n普通收购与活当可借牌压价，让当前要价下降10%，每位客人限一次。强压人一头，也会损伤铺子的口碑。"

static func award(state: RunState) -> void:
	if not state.social_enabled or state.social.plaque_awarded or not state.social.introduced: return
	if int(state.social.military) < int(SocialRules.config().plaque.threshold): return
	state.social.plaque_awarded = true
	SocialRules.military_notice(state, "孙大元送来一块‘军方照应’木牌，替你挂在铺中：‘往后来人谈价，也知道这铺子有人照应。’")

static func used(state: RunState, visit: CustomerVisit) -> bool:
	return state.social_enabled and state.social.intimidations.any(func(row: Dictionary) -> bool: return row.visit_id == visit.visit_id)

static func reason(state: RunState, visit: CustomerVisit) -> String:
	if not state.social_enabled or not state.social.plaque_awarded: return "铺中尚未挂上军方照应牌。"
	if not ReputationService.eligible(state, visit): return "这位来客不适合借军方的名头压价。"
	var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	if customer == null or not customer.guest_rule.is_empty(): return "这位来客不吃军方这一套。"
	if used(state, visit): return "已经借牌压过一次价，不能再压。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已经不肯再谈价。"
	return ""

static func intimidate(state: RunState, visit: CustomerVisit) -> String:
	var trade := visit.trade
	var shown_before := FanBargainingService.asking(state, visit)
	var before := trade.asking_price
	var reserve := trade.reserve_price
	var percent := int(SocialRules.config().plaque.price_percent)
	trade.asking_price = maxi(1, ceili(float(before * percent) / 100.0))
	trade.reserve_price = maxi(1, ceili(float(reserve * percent) / 100.0))
	if WealthyCustomers.active(state) and WealthyCustomers.is_customer(visit.customer_id):
		var luxury := WealthyCustomers.trade(state,visit)
		luxury.intimidation = float(percent) / 100.0
		trade.reserve_price = maxi(trade.reserve_price,int(luxury.funding))
		trade.asking_price = maxi(trade.asking_price,trade.reserve_price)
	var fan := FanBargainingService.attempt(state, visit)
	if fan.get("accepted", false):
		fan.asking = maxi(1, ceili(float(int(fan.asking) * percent) / 100.0))
		fan.reserve = maxi(1, ceili(float(int(fan.reserve) * percent) / 100.0))
	state.social.intimidations.append({"visit_id":visit.visit_id, "night":state.current_night_index, "asking_before":before, "asking_after":trade.asking_price, "reserve_before":reserve, "reserve_after":trade.reserve_price})
	SocialRules.change(state, "reputation", -int(SocialRules.config().plaque.reputation_cost), "intimidation/" + visit.visit_id)
	visit.voice.completed = "他数过银元，朝墙上的木牌瞥了一眼，把钱收进衣襟，没有再说话。"
	return "你抬手指了指军方照应牌。客人把嘴边的话咽回去：‘那就再让一成。’\n要价 %d → %d 银元。" % [shown_before, FanBargainingService.asking(state, visit)]
