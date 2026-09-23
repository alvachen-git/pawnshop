class_name FirstDebt
extends RefCounted

const PHOENIX := "fd_phoenix"
const DRAGON := "fd_dragon"
const DOCUMENTS := ["fd_ticket", "fd_receipt", "fd_mark", "fd_spending", "fd_customer_ticket", "fd_protection", "fd_yin_link", "fd_yin_echo"]
static func enabled(run: RunDefinition) -> bool:
	return int(run.variety.get("first_debt_version", 0)) in [1, 2, 3]

static func revised(s: RunState) -> bool:
	return s.run_definition_id in ["first_debt_reckoning", "first_debt_dragon_search"]

static func last(state: RunState, id: String) -> Dictionary:
	for i in range(state.event_history.size() - 1, -1, -1):
		if state.event_history[i].event_id == id: return state.event_history[i]
	return {}

static func flag(state: RunState, key: String) -> bool:
	return key in state.narrative_flags

static func owned(state: RunState, id: String) -> ItemInstance:
	for item in state.inventory_instances:
		if item.definition_id == id and item.ownership_state == "owned": return item
	return null

static func settled(state: RunState) -> bool:
	return flag(state, "fd_clear") or flag(state, "fd_peace")

static func outcome(state: RunState) -> String:
	return "原物交还陈家 · 清" if flag(state, "fd_clear") else "陈家知情受偿 · 和" if flag(state, "fd_peace") else "旧事尚未了结"

static func saw_seller(state: RunState) -> bool:
	return flag(state, "fd_receipt_read") or flag(state, "fd_mark_read") or state.visit_history.any(func(r: Dictionary) -> bool: return r.get("customer_id") == "fd_seller" and r.get("outcome") not in ["shop_closed", "timed_out"])

static func item_exists(state: RunState, id: String) -> bool:
	return state.inventory_instances.any(func(i: ItemInstance) -> bool: return i.definition_id == id)

# Deterministic overlay of an ordinary seat. Never duplicate an acquired unique object.
static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not enabled(run) or state.current_night_index < 11: return rows
	var n := state.current_night_index
	var initial: Array[String] = []
	var revisits: Array[String] = []
	if not item_exists(state, PHOENIX):
		if not saw_seller(state): initial.append("fd_seller")
		elif int(last(state, "fd_seller").get("night", -2)) + 1 == n: revisits.append("fd_seller")
	var chen_seen := state.visit_history.any(func(r: Dictionary) -> bool: return r.get("customer_id") == "fd_chen" and r.get("outcome") not in ["timed_out", "shop_closed"])
	if n >= 12 and not chen_seen: initial.append("fd_chen")
	var used: Array[int] = []
	for who in initial + revisits:
		var slot := VisitSlotDefinition.new(who, 0 if who == "fd_seller" else 60, who, PHOENIX if who == "fd_seller" else "item_silk_panel", "sound", n, n)
		var authored := SevenNightPlan.story_row(run, catalog, slot, n, state.run_seed)
		authored.source = ""
		if DragonSearch.enabled(state): authored["familiar_reserved"] = true
		if who in revisits:
			authored["first_debt_appointment"] = true
			rows.append(authored)
		else:
			for i in rows.size():
				if i in used or rows[i].night != n or rows[i].get("familiar_reserved", false): continue
				used.append(i); rows[i] = authored; break
	return rows

# A completed ordinary visit is the source of the optional recognition scene.
# No extra pending-event state, customer slot, item instance or clock tick.
static func chen_trade(s: RunState) -> Dictionary:
	for i in range(s.visit_history.size() - 1, -1, -1):
		var row: Dictionary = s.visit_history[i]
		if row.customer_id != "fd_chen" or row.night != s.current_night_index: continue
		if row.outcome == "shop_closed": return {}
		if row.outcome == "timed_out" and not s.bargaining_history.any(func(h: Dictionary) -> bool: return h.visit_id == row.visit_id): return {}
		return row
	return {}

static func chen_recognition_due(s: RunState, continuous := true) -> bool:
	if not revised(s) or s.phase != &"open" or flag(s, "fd_chen_requested") or flag(s, "fd_family_read"): return false
	if not last(s, "fd_chen_recognize").is_empty() or owned(s, PHOENIX) == null: return false
	var trade := chen_trade(s)
	# Recognition belongs to this handoff, never to a later gap after another
	# reception. Historical transcripts retain the older, delayed eligibility.
	return not trade.is_empty() and (not continuous or int(trade.minute) == s.game_minutes)

static func chen_delivered_today(s: RunState) -> bool:
	if not revised(s) or int(last(s, "fd_family").get("night", -1)) != s.current_night_index: return false
	# Preserve an already-started later conversation in historical v29 saves.
	for id in ["fd_truth", "fd_amend", "fd_compensation", "fd_settle"]:
		if int(last(s, id).get("night", -1)) == s.current_night_index: return false
	return true

# Terminal replies hold the portrait in the View only; they never create another visit.
static func chen_departed_today(s: RunState) -> bool:
	if not DragonSearch.enabled(s) or s.get_meta("legacy_chen_visits", false): return false
	for id in ["fd_search_motive", "fd_settle", "fd_followup", "fd_meeting_end"]:
		if int(last(s, id).get("night", -1)) == s.current_night_index: return true
	return false

static func chen_recent_result(s: RunState) -> bool:
	if chen_departed_today(s): return false
	# Recognition ends this visit. The UI holds Chen only while its reply is read.
	if not revised(s) or s.event_history.is_empty() or chen_delivered_today(s): return false
	var h: Dictionary = s.event_history.back()
	return h.event_id in ["fd_family", "fd_truth", "fd_amend", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"] and h.night == s.current_night_index and h.minute == s.game_minutes

# A returning visitor waits for a gap in reception. This presence is read-only and
# never consumes a customer seat, expires another visit, or blocks a business command.
static func chen_waiting(s: RunState, legacy_replay := false) -> bool:
	if chen_departed_today(s): return false
	if DragonSearch.enabled(s) and not s.get_meta("legacy_chen_visits", false) and not last(s, "fd_search_motive").is_empty():
		if DragonSearch.appointment_night(s, "chen_invite") != s.current_night_index: return false
	if DragonSearch.enabled(s) and int(last(s, "fd_search_motive").get("night", -1)) == s.current_night_index: return false
	if not legacy_replay and chen_delivered_today(s): return false
	if s.current_night_index < 12 or s.game_minutes >= 480: return false
	if int(last(s, "fd_meeting_end").get("night", -1)) == s.current_night_index: return false
	var request := last(s, "fd_chen_request")
	if request.is_empty():
		request = last(s, "fd_chen_recognize")
		if revised(s) and request.get("choice_id", "") != "ask": request = {}
	if request.is_empty() or int(request.night) >= s.current_night_index: return false
	return not settled(s) or (not flag(s, "fd_followed") and int(last(s, "fd_settle").get("night", -1)) < s.current_night_index)

static func reason(day: DayController, counter: CounterService, id: String, choice: String, legacy_replay := false) -> String:
	var s := day.state
	if DragonSearch.enabled(s) and (MirrorEncounterService.new(counter.catalog).pending(day) or SocialRules.blocked(s)): return "先处理眼前的事情。"
	if DragonSearch.enabled(s) and id in ["fd_lu", "fd_dragon"]: return "先托人寻找，再约陆掌眼带来。"
	if not enabled(day.definition) or s.phase in [&"pre_open", &"dead", &"bankrupt", &"run_ended", &"day_summary", &"sleep_resolution"]: return "现在不能翻看或办理。"
	if not s.risk_pending.is_empty() or not s.pending_event_id.is_empty() or MirrorEndingService.active(s) or not PawnReturnService.current(s).is_empty(): return "先处理眼前的事情。"
	var v := counter.customers.active(s)
	var phoenix_available := owned(s, PHOENIX) != null or (v != null and v.item != null and v.item.definition_id == PHOENIX)
	if id in DragonSearch.EVENTS:
		var search_error := DragonSearch.reason(day, counter, id, choice)
		if not search_error.is_empty(): return search_error
	if id in ["fd_customer_ticket", "fd_protection", "fd_yin_link", "fd_yin_echo"]:
		if not revised(s): return "资料不属于这局。"
		if id == "fd_customer_ticket": return "" if flag(s, "fd_family_read") else "陈家还没有带来原票。"
		if id == "fd_protection": return "" if flag(s, "fd_ticket_read") and flag(s, "fd_receipt_read") else "尚未翻到这页。"
		if id == "fd_yin_link": return "" if flag(s, "fd_spending_read") and flag(s, "aq_ledger_open") else "还没有可核对的押记。"
		if id == "fd_yin_echo": return "" if settled(s) and flag(s, "fd_yin_link_read") else "账页上没有新的字迹。"
	if id == "fd_compensation" and settled(s): return "这笔旧事已经议妥。"
	if id == "fd_ticket": return "" if flag(s, "aq_ticket_seen") else "还没有这张旧票。"
	if id == "fd_spending": return "" if flag(s, "fd_receipt_read") and flag(s, "fd_ticket_read") else "尚未翻到这页。"
	if id in ["fd_receipt", "fd_mark"]:
		return "" if phoenix_available or flag(s, id + "_read") else "尚未看过这件货的随附资料。"
	if s.phase != &"open": return "开铺后再托话办理。"
	if v != null and not (id == "fd_chen_recognize" and chen_recognition_due(s)) and not ((not revised(s) or legacy_replay) and v.customer_id == "fd_chen" and id in ["fd_chen_recognize", "fd_family", "fd_truth", "fd_amend", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"]): return "先招呼柜前的客人。"
	if id in ["fd_family", "fd_truth", "fd_amend", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"] and not chen_waiting(s, legacy_replay): return "等陈小满得空再谈。"
	match id:
		"fd_seller":
			if not saw_seller(s) or item_exists(s, PHOENIX): return "眼下没有需要约回的卖镯人。"
		"fd_chen_recognize":
			if revised(s) and not (legacy_replay and v != null and v.customer_id == "fd_chen"):
				if not chen_recognition_due(s, not legacy_replay): return "先把眼前这笔生意办完。"
			elif v == null or v.customer_id != "fd_chen" or owned(s, PHOENIX) == null or flag(s, "fd_family_read"): return "现在没有可核对的旧物。"
		"fd_family":
			var request := last(s, "fd_chen_request")
			if request.is_empty(): request = last(s, "fd_chen_recognize")
			if request.is_empty() or int(request.night) >= s.current_night_index: return "原当票还没带来，明日再谈。" if revised(s) else "旧记还没带来，明日再谈。"
		"fd_dragon":
			if item_exists(s, DRAGON): return "这只龙镯已经交过货。"
			var request := last(s, "fd_lu")
			if request.is_empty() or int(request.night) >= s.current_night_index: return "龙镯还没带来。"
			if s.cash < 180: return "现银不足180银元。"
		"fd_truth":
			if flag(s, "fd_truth_told"): return "实情已经说清。"
			if flag(s, "fd_lied") and choice == "tell": return "先将前次隐瞒的事说清。"
		"fd_amend":
			if flag(s, "fd_truth_told"): return "实情已经说清。"
		"fd_settle":
			if settled(s): return "这笔旧事已经议妥。"
			if choice == "return" and (owned(s, PHOENIX) == null or owned(s, DRAGON) == null): return "两只金镯还没有备齐。"
			if revised(s) and choice == "pay" and not flag(s, "fd_compensation_agreed"): return "先和陈小满商量赔偿。"
			if choice == "pay" and s.cash < 300: return "现银不足300银元。"
		"fd_followup":
			var ending := last(s, "fd_settle")
			if not settled(s) or ending.is_empty() or int(ending.night) >= s.current_night_index: return "改日再听她说说近况。"
		"fd_meeting_end":
			if not chen_waiting(s, legacy_replay): return "陈小满已经走了。"
		"fd_aqi_stay", "fd_aqi_leave", "fd_aqi_thread", "fd_aqi_boat", "fd_aqi_box":
			if chen_waiting(s): return "先招呼客人，等会儿再聊。"
			if s.current_night_index < 11 or s.game_minutes >= 240: return "阿七已经回去了。"
			if id != "fd_aqi_stay" and (not flag(s, "aq_seated") or left_today(s)): return "阿七不在柜边。"
			if id == "fd_aqi_stay" and (flag(s, "aq_seated") or left_today(s)): return "今天已经说过了。"
	return ""

static func left_today(s: RunState) -> bool:
	return int(last(s, "fd_aqi_leave").get("night", -1)) == s.current_night_index or (int(last(s, "fd_aqi_stay").get("night", -1)) == s.current_night_index and last(s, "fd_aqi_stay").get("choice_id") == "no")

static func choose(day: DayController, events: EventDirector, counter: CounterService, id: String, choice_id: String, legacy_replay := false) -> ActionResult:
	if id not in day.definition.event_ids: return ActionResult.new(false, "资料不属于这局。")
	var e := events.catalog.get_definition("events", id) as EventDefinition
	if e == null or e.presentation.get("scene", "") != "first_debt": return ActionResult.new(false, "资料不存在。")
	var c := e.find_choice(choice_id)
	if c == null: return ActionResult.new(false, "选项不存在。")
	var error := reason(day, counter, id, choice_id, legacy_replay)
	if not error.is_empty(): return ActionResult.new(false, error)
	var s := day.state
	if not CounterDomainValidator._contains_all(s.narrative_flags, e.required_flags) or not c.available(s.narrative_flags, s.inventory_instances): return ActionResult.new(false, "还没有看过相关资料。")
	var prev := last(s, id)
	if not prev.is_empty() and (not e.presentation.get("repeat_daily", false) or (prev.night == s.current_night_index and prev.choice_id == choice_id)): return ActionResult.new(false, "这段已经记下。")
	if c.minutes > 0:
		if s.game_minutes + c.minutes >= day.definition.night_minutes: return ActionResult.new(false, "今夜来不及办妥。")
		var spent := day.spend_action(c.minutes)
		if not spent.ok: return spent
	if id == "fd_dragon_deal" and choice_id == "buy": DragonSearch.acquire(s)
	if id == "fd_dragon":
		var item := ItemInstance.new()
		item.instance_id = "first_debt/dragon"
		item.definition_id = DRAGON
		item.selected_variant_id = "sound"
		item.revealed_clue_ids.assign(["form", "mark", "repair"])
		InventoryManager.new().acquire(s, item, "first_debt/ruifeng", 180)
		EconomyManager.new().commit(s, -180, item.instance_id, "first_debt/buy_dragon", "acquisition", 0)
	if id == "fd_settle" and choice_id == "pay": EconomyManager.new().commit(s, -300, "", "first_debt/compensate", "debt_compensation", 0)
	if id == "fd_settle" and choice_id == "return":
		for item in [owned(s, PHOENIX), owned(s, DRAGON)]:
			item.ownership_state = "returned"
			EconomyManager.new().commit(s, 0, item.instance_id, "first_debt/return/" + item.instance_id, "debt_return", -item.acquisition_price)
	for f in c.grant_flags:
		if f not in s.narrative_flags: s.narrative_flags.append(f)
	s.event_history.append({"event_id": id, "choice_id": choice_id, "night": s.current_night_index, "phase": String(s.phase), "offered_minute": s.game_minutes - c.minutes, "minute": s.game_minutes})
	var result := response(s, id, c.result)
	if DragonSearch.enabled(s) and id == "fd_search_motive":
		result += "\n“往后若有事找我，开铺前托人捎句话便是。”"
	if DragonSearch.enabled(s) and id == "fd_settle" and choice_id != "return":
		result += "\n陈小满收好布包，向你告辞。"
	if (id in ["fd_truth", "fd_amend"] and choice_id == "tell") or (id == "fd_settle" and choice_id == "pay"):
		result += "\n你也把眼下知道的下落告诉了她：" + whereabouts(s)
	if id == "fd_followup" and not revised(s): result = "陈小满带来一个重新衬好的镯匣：“两只放在一起，正好。”" if flag(s, "fd_clear") else "“做活的家什添齐了，房租也留了些。”陈小满把新缝的包袱扎好。"
	return ActionResult.new(true, result)

static func model(day: DayController, events: EventDirector, counter: CounterService) -> Dictionary:
	if not enabled(day.definition): return {}
	var s := day.state
	var result := {"text": "", "buttons": [], "documents": [], "outcome": outcome(s) if flag(s, "fd_truth_told") else ""}
	for id in DOCUMENTS + ["fd_family"]:
		if id == "fd_yin_echo": continue
		if last(s, id).is_empty(): continue
		var e := events.catalog.get_definition("events", id) as EventDefinition
		result.documents.append({"id": id, "title": e.title, "text": response(s, id, e.choices[0].result)})
	for id in day.definition.event_ids:
		if not id.begins_with("fd_") or (id.begins_with("fd_aqi_") and id != "fd_aqi_stay"): continue
		var e := events.catalog.get_definition("events", id) as EventDefinition
		if not CounterDomainValidator._contains_all(s.narrative_flags, e.required_flags): continue
		if not e.presentation.get("repeat_daily", false) and not last(s, id).is_empty(): continue
		for c in e.choices:
			if revised(s) and not c.available(s.narrative_flags, s.inventory_instances): continue
			if not last(s, id).is_empty() and last(s, id).night == s.current_night_index and last(s, id).choice_id == c.id: continue
			var error := reason(day, counter, id, c.id)
			if error.begins_with("现银不足") or error == "两只金镯还没有备齐。" or error.is_empty():
				result.buttons.append({"context": e.body, "command": "fd_event", "target_id": id, "detail": c.id, "label": c.label + (" · %d分钟" % c.minutes if c.minutes else ""), "enabled": error.is_empty(), "reason": error})
	if not s.event_history.is_empty() and str(s.event_history.back().event_id).begins_with("fd_"):
		var h: Dictionary = s.event_history.back()
		var e := events.catalog.get_definition("events", h.event_id) as EventDefinition
		result.text = response(s, h.event_id, e.find_choice(h.choice_id).result)
		if h.event_id == "fd_followup" and not revised(s): result.text = "陈小满带来重新衬好的镯匣：‘两只放在一起，正好。’" if flag(s, "fd_clear") else "‘做活的家什添齐了，房租也留了些。’陈小满把新缝的包袱扎好。"
	return result

static func decorate(model: Dictionary, day: DayController, events: EventDirector, counter: CounterService) -> void:
	var s := day.state
	var debt := FirstDebt.model(day, events, counter)
	var v := counter.customers.active(s)
	model.inventory["first_debt"] = debt
	if revised(s):
		decorate_reckoning(model, day, events, counter, debt)
		if DragonSearch.enabled(s): DragonSearch.decorate(model, day, counter)
		return
	for b in debt.buttons:
		if b.target_id in ["fd_receipt", "fd_mark", "fd_chen_recognize", "fd_customer_ticket"]:
			model.dialogue.buttons.append(b)
			if b.target_id == "fd_mark": model.appraisal.buttons.append(b)
	if v != null:
		if v.customer_id == "fd_chen":
			for b in debt.buttons:
				if b.target_id in ["fd_family", "fd_truth", "fd_amend", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"]: model.dialogue.buttons.append(b)
			append_chen_context(model.dialogue, events)
		if v.customer_id in ["fd_seller", "fd_chen"]:
			model.dialogue["preserve_ticket_body"] = true
			if not debt.text.is_empty() and not model.dialogue.body.contains(debt.text): model.dialogue.body += "\n\n" + debt.text
		if v.customer_id == "fd_chen" and owned(s, PHOENIX) != null and not flag(s, "fd_family_read"):
			model["first_debt_relic"] = true
			model.dialogue.body += "\n\n柜边搁着收来的凤镯。陈小满看了看凤尾：‘祖父让我留心一只尾上补过的凤镯。我没见过原物，不敢认。’" if revised(s) else "\n\n柜边搁着收来的凤镯。陈小满看了看凤尾：‘我爹说过，家里有一对，凤尾补过。我自己没有见过，不敢说就是。’"
		return
	if s.phase != &"open" or not s.pending_event_id.is_empty() or not s.risk_pending.is_empty() or not PawnReturnService.current(s).is_empty() or MirrorEndingService.active(s): return
	var chen := chen_waiting(s)
	var aqi := not flag(s, "aq_seated") and not left_today(s) and s.current_night_index >= 11 and s.game_minutes < 240
	if not chen and not aqi:
		if not debt.text.is_empty() and model.dialogue.body.contains(debt.text):
			model.dialogue.body = model.dialogue.body.substr(model.dialogue.body.find(debt.text))
			model.dialogue["preserve_ticket_body"] = true
		return
	model.active_id = "first_debt/%d/%s" % [s.current_night_index, "chen" if chen else "aqi"]
	model.customer = "陈小满" if chen else "阿七"
	model.item = "柜台暂空"; model["itemless"] = true
	model.context_actions = {"customer": [{"id": "dialogue", "label": "说说话", "enabled": true}], "item": []}
	var introduction := "陈小满在门边等客人走开，才把包袱放上柜沿：‘掌柜，旧纸带来了。’" if not flag(s, "fd_family_read") else "陈小满把祖父留下的原当票放在手边，等你开口。"
	if not chen: introduction = "阿七在门边探了探头：‘掌柜，今天能坐在这里看一会儿吗？’"
	model.visual = {"customer_id": "fd_chen" if chen else "fd_aqi", "portrait_asset": "", "customer_name": model.customer, "attitude": "等你得空说话", "deadline": "02:00" if chen else "22:00", "introduction": introduction, "intent": "", "item_asset": "", "item_name": "", "item_status": "柜台暂空", "estimate": "", "clues": [], "speech": []}
	model.dialogue = {"body": introduction + ("\n\n" + debt.text if not debt.text.is_empty() else ""), "buttons": [], "visit_id": model.active_id, "preserve_ticket_body": true}
	for b in debt.buttons:
		if (chen and b.target_id in ["fd_family", "fd_truth", "fd_amend", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"]) or (not chen and b.target_id == "fd_aqi_stay"): model.dialogue.buttons.append(b)

	if chen: append_chen_context(model.dialogue, events)

static func decorate_reckoning(model: Dictionary, day: DayController, events: EventDirector, counter: CounterService, debt: Dictionary) -> void:
	var s := day.state
	var v := counter.customers.active(s)
	var recognition := chen_recognition_due(s)
	if DragonSearch.enabled(s) and (MirrorEncounterService.new(counter.catalog).pending(day) or SocialRules.blocked(s)): return
	if v != null and not recognition:
		# Documents about the seller's own article remain available; no previous
		# document or Chen story is ever appended to ordinary customer dialogue.
		if v.customer_id == "fd_seller":
			for b in debt.buttons:
				if b.target_id in ["fd_receipt", "fd_mark"]:
					model.dialogue.buttons.append(b)
					if b.target_id == "fd_mark": model.appraisal.buttons.append(b)
		return
	if s.phase != &"open" or not s.pending_event_id.is_empty() or not s.risk_pending.is_empty() or not PawnReturnService.current(s).is_empty() or MirrorEndingService.active(s): return
	if DragonSearch.enabled(s) and int(last(s, "fd_search_motive").get("night", -1)) == s.current_night_index: return
	if chen_departed_today(s): return
	if not recognition and not chen_recent_result(s) and not chen_waiting(s):
		decorate_aqi_request(model, s, debt)
		return
	var intro := "陈小满把祖父留下的原当票放在手边，等你开口。"
	if recognition:
		var trade := chen_trade(s)
		intro = "绣片的生意办妥了。陈小满收好钱，目光落在当铺柜子里的凤镯上。" if trade.outcome == "bought" else "绣片的价钱没有谈成。陈小满收好包袱，临走时看见当铺柜子里的凤镯。"
	# A newly selected customer may already be active in the queue, but has not
	# been presented. Finish Chen's visit before exposing their trade controls.
	if recognition:
		model["continuous_from"] = chen_trade(s).visit_id
		model.trade.can_offer = false
		model.trade.can_pawn = false
		model.trade.buttons = []
		model.appraisal.buttons = []
		model.trade.body = "陈小满还在柜前，先听她把话说完。"
		model.appraisal.body = model.trade.body
	model.active_id = "first_debt/%d/chen" % s.current_night_index
	model.customer = "陈小满"
	model.item = "柜台暂空"
	model["itemless"] = true
	model["first_debt_relic"] = false
	model.context_actions = {"customer": [{"id": "dialogue", "label": "说说话", "enabled": true}], "item": []}
	model.visual = {"customer_id": "fd_chen", "portrait_asset": "", "customer_name": "陈小满", "attitude": "等你得空说话", "deadline": "02:00", "introduction": "绣片的生意已经谈完。" if recognition else "带来祖父留下的原当票。", "intent": "", "item_asset": "", "item_name": "", "item_status": model.item, "estimate": "", "clues": [], "speech": []}
	var buttons: Array = []
	for b in debt.buttons:
		if b.target_id in (["fd_chen_recognize"] if recognition else ["fd_search_motive", "fd_family", "fd_customer_ticket", "fd_amend", "fd_truth", "fd_compensation", "fd_settle", "fd_followup", "fd_meeting_end"]): buttons.append(b)
	# One topic at a time; settlement alternatives already contain a way to defer.
	for topic in ["fd_chen_recognize", "fd_family", "fd_amend", "fd_truth", "fd_search_motive", "fd_settle", "fd_compensation", "fd_followup"]:
		if not buttons.any(func(b: Dictionary) -> bool: return b.target_id == topic): continue
		buttons = buttons.filter(func(b: Dictionary) -> bool: return b.target_id == topic or (topic in ["fd_settle", "fd_search_motive"] and b.target_id == "fd_compensation") or (topic in ["fd_family", "fd_followup"] and b.target_id == "fd_meeting_end"))
		if topic == "fd_search_motive": buttons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id == topic and b.target_id != topic)
		break
	var text := intro
	if chen_recent_result(s) and buttons.is_empty():
		var h: Dictionary = s.event_history.back()
		var e := events.catalog.get_definition("events", h.event_id) as EventDefinition
		text = response(s, h.event_id, e.find_choice(h.choice_id).result)
	if recognition:
		text += "\n" + (events.catalog.get_definition("events", "fd_chen_recognize") as EventDefinition).body
	else:
		for id in ["fd_family", "fd_amend", "fd_truth", "fd_search_motive", "fd_settle", "fd_compensation", "fd_followup"]:
			if buttons.any(func(b: Dictionary) -> bool: return b.target_id == id):
				text = (events.catalog.get_definition("events", id) as EventDefinition).body
				break
	if DragonSearch.enabled(s) and buttons.any(func(b: Dictionary) -> bool: return b.target_id == "fd_search_motive"): text = DragonSearch.motive_text(s, text)
	model["case_dialogue"] = {"text": text, "buttons": buttons, "auto_open": recognition, "key": model.active_id + ("/recognition" if recognition else "/visit")}
	# Compatibility read model for input routing, without a second text dump.
	model.dialogue = {"body": text, "buttons": buttons, "visit_id": model.active_id, "preserve_ticket_body": true}

static func decorate_aqi_request(model: Dictionary, s: RunState, debt: Dictionary) -> void:
	if flag(s, "aq_seated") or left_today(s) or s.current_night_index < 11 or s.game_minutes >= 240: return
	model.active_id = "first_debt/%d/aqi" % s.current_night_index
	model.customer = "阿七"; model.item = "柜台暂空"; model["itemless"] = true
	model.context_actions = {"customer": [{"id": "dialogue", "label": "说说话", "enabled": true}], "item": []}
	var intro := "阿七在门边探了探头：‘掌柜，今天能坐在这里看一会儿吗？’"
	model.visual = {"customer_id": "fd_aqi", "portrait_asset": "", "customer_name": "阿七", "attitude": "等你得空说话", "deadline": "22:00", "introduction": intro, "intent": "", "item_asset": "", "item_name": "", "item_status": "柜台暂空", "estimate": "", "clues": [], "speech": []}
	model.dialogue = {"body": intro, "buttons": debt.buttons.filter(func(b: Dictionary) -> bool: return b.target_id == "fd_aqi_stay"), "visit_id": model.active_id, "preserve_ticket_body": true}

static func append_chen_context(dialogue: Dictionary, events: EventDirector) -> void:
	for id in ["fd_family", "fd_amend", "fd_truth", "fd_search_motive", "fd_settle", "fd_compensation", "fd_followup"]:
		if dialogue.buttons.any(func(b: Dictionary) -> bool: return b.get("target_id", "") == id):
			var e := events.catalog.get_definition("events", id) as EventDefinition
			dialogue.body += "\n\n" + e.body
			break
	if dialogue.buttons.any(func(b: Dictionary) -> bool: return b.get("target_id", "") in ["fd_truth", "fd_settle"]):
		dialogue.buttons = dialogue.buttons.filter(func(b: Dictionary) -> bool: return b.get("target_id", "") != "fd_meeting_end")

static func whereabouts(s: RunState) -> String:
	var lines: Array[String] = []
	for id in [PHOENIX, DRAGON]:
		var name := "凤镯" if id == PHOENIX else "龙镯"
		if owned(s, id) != null: lines.append(name + "在铺里。")
		elif item_exists(s, id): lines.append(name + ("已交还陈家。" if flag(s, "fd_clear") else "已经卖出，眼下追不回来。"))
		elif id == PHOENIX: lines.append("凤镯由卖家带走，还没有收进铺里。")
		elif DragonSearch.enabled(s) and flag(s, "fd_search_message"): lines.append("龙镯在陆掌眼手上，还未买下。")
		elif flag(s, "fd_dragon_requested"): lines.append("陆掌眼提过银楼旧货柜里那只龙镯，还未买下。")
		else: lines.append("另一只的下落尚未核实。")
	return "".join(lines)

# Responses derive only from recorded facts. No rendering code grants knowledge.
static func response(s: RunState, id: String, text: String) -> String:
	if not revised(s): return text
	if id == "fd_yin_echo":
		return text + "\n瑞字四十七下，多了一个“%s”字。纸上的旧账还在，并没有被涂去。" % ("清" if flag(s, "fd_clear") else "和")
	if id == "fd_followup":
		return "陈小满带来重新衬好的旧镯匣：‘祖父留下的匣子，我一直收着。如今两只都能放回去了。’" if flag(s, "fd_clear") else "陈小满说添齐了做活的家什。祖父的原票仍在布包里：‘我应下了和解，也还记得他交代的事。’"
	if id in ["fd_truth", "fd_amend"] and flag(s, "fd_truth_told") and flag(s, "fd_protection_read"):
		text += "\n你将送礼账和营署回条推过去。陈小满把它们与初九的旧记对上：‘难怪后来连门都不让进。’"
	if id == "fd_compensation": text += "\n你说明眼下所知的下落：" + whereabouts(s)
	return text
