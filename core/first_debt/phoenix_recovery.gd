class_name PhoenixRecovery
extends RefCounted

const GATE := "fd_phoenix_departure"
const HINT := "fd_phoenix_hint"
const LEAVE := "卖镯人收好包裹：‘掌柜若改了主意，托句话给我，我再带来。’\n开铺前可约卖镯人带凤镯来。"

static func enabled(s: RunState) -> bool:
	return s.run_definition_id in ["camera_unified", "porcelain_release", "first_debt_recovery", "first_debt_recovery_release"]

static func available(s: RunState) -> bool:
	return enabled(s) and (FirstDebt.saw_seller(s) or not FirstDebt.last(s, GATE).is_empty()) and not FirstDebt.item_exists(s, FirstDebt.PHOENIX) and not FirstDebt.settled(s)

static func prep_reason(s: RunState) -> String:
	if not available(s): return "眼下没有需要约回的卖镯人。"
	if DragonSearch.appointment_night(s, "phoenix_invite") >= s.current_night_index: return "卖镯人已有约定；停业时会顺延，无须再托话。"
	if SocialRules.closed(s): return "今夜停业，待能开铺时再约卖镯人。"
	return ""

# Eligibility is captured by the same journal action as departure. This stops a
# later risk resolution or Aqi arrival from retroactively producing her remark.
static func capture(s: RunState, prior_visit: String, history_start: int, interrupted := false) -> bool:
	if not enabled(s) or not FirstDebt.last(s, GATE).is_empty() or FirstDebt.item_exists(s, FirstDebt.PHOENIX): return false
	for row in s.visit_history.slice(history_start):
		if row.customer_id != "fd_seller" or row.visit_id != prior_visit or row.outcome == "shop_closed": continue
		if s.phase != &"open": return false
		var present := FirstDebt.flag(s, "aq_seated") and not FirstDebt.left_today(s) and s.game_minutes < 240
		var safe := not interrupted and s.risk_pending.is_empty() and s.pending_event_id.is_empty() and PawnReturnService.current(s).is_empty() and not SocialRules.blocked(s) and not MirrorEndingService.active(s)
		s.event_history.append({"event_id": GATE, "choice_id": "hint" if present and safe else "quiet", "night": s.current_night_index, "phase": "open", "offered_minute": s.game_minutes, "minute": s.game_minutes})
		return true
	return false

static func hint_due(s: RunState) -> bool:
	if not enabled(s) or FirstDebt.flag(s, "fd_phoenix_hint_seen") or s.phase != &"open": return false
	var gate := FirstDebt.last(s, GATE)
	return gate.get("choice_id", "") == "hint" and gate.night == s.current_night_index and s.game_minutes < 240 and FirstDebt.flag(s, "aq_seated") and not FirstDebt.left_today(s) and s.risk_pending.is_empty() and s.pending_event_id.is_empty() and not SocialRules.blocked(s) and not MirrorEndingService.active(s) and PawnReturnService.current(s).is_empty()

static func notice(s: RunState) -> String:
	if not available(s): return ""
	if DragonSearch.appointment_night(s, "phoenix_invite") >= s.current_night_index: return "已约卖镯人带凤镯来，19:00起等空柜接待；停业时顺延。"
	return "卖镯人还留着联络口信。开铺前可约他带凤镯来，再验货谈价。"
