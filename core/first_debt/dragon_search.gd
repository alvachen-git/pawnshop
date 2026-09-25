class_name DragonSearch
extends RefCounted

# All durable facts are existing preparation/event records. Models never write.
const RUN := "first_debt_dragon_search"
const EVENTS := ["fd_search_motive", "fd_dragon_quote", "fd_dragon_deal"]

static func enabled(s: RunState) -> bool:
	return s.run_definition_id in [RUN, "first_debt_unified", "bangle_unified", "porcelain_unified", "camera_unified", "porcelain_release", "first_debt_recovery", "first_debt_recovery_release"]

static func preparation(s: RunState, action: String) -> Dictionary:
	for i in range(s.preparation_history.size() - 1, -1, -1):
		if s.preparation_history[i].action == action: return s.preparation_history[i]
	return {}

static func appointment_night(s: RunState, action := "dragon_invite") -> int:
	var row := preparation(s, action)
	if row.is_empty(): return -1
	var night := int(row.night)
	# A closure postpones this same paid preparation, not a new appointment.
	while night <= s.current_night_index:
		var closed := false
		for snapshot in s.social.get("nights", []):
			if snapshot.night == night: closed = snapshot.get("closed", false); break
		if not closed: return night
		night += 1
	return night

static func prep_reason(s: RunState, action: String) -> String:
	if not enabled(s): return "这局没有这项准备。"
	if action == "chen_invite":
		if FirstDebt.last(s, "fd_search_motive").is_empty(): return "眼下还没有另约陈小满的事。"
		if FirstDebt.flag(s, "fd_followed"): return "陈家的后话已经说完。"
		if appointment_night(s, action) >= s.current_night_index: return "陈小满已有约定；停业时会顺延，无须再托话。"
		if SocialRules.closed(s): return "今夜停业，待能开铺时再约陈小满。"
		return ""
	if FirstDebt.settled(s) or FirstDebt.item_exists(s, FirstDebt.DRAGON): return "这件事已经办妥。"
	if action == "dragon_search":
		if not FirstDebt.flag(s, "fd_search_promised"): return "还没有答应替陈家寻找另一只。"
		if not preparation(s, action).is_empty(): return "寻找龙镯的口信已经托出。"
	else:
		if not FirstDebt.flag(s, "fd_search_message"): return "还没收到龙镯的下落。"
		if appointment_night(s) >= s.current_night_index: return "陆掌眼已有约定；停业时会顺延，无须再托话。"
		if SocialRules.closed(s): return "今夜停业，待能开铺时再约陆掌眼。"
	return ""

static func message_due(s: RunState) -> bool:
	return enabled(s) and not preparation(s, "dragon_search").is_empty() and not FirstDebt.flag(s, "fd_search_message")

static func waiting(s: RunState) -> bool:
	if not enabled(s) or s.phase != &"open" or s.game_minutes < 60 or SocialRules.closed(s): return false
	if appointment_night(s) != s.current_night_index or FirstDebt.item_exists(s, FirstDebt.DRAGON) or FirstDebt.settled(s): return false
	return int(FirstDebt.last(s, "fd_dragon_deal").get("night", -1)) != s.current_night_index

static func quoted(s: RunState) -> bool:
	return int(FirstDebt.last(s, "fd_dragon_quote").get("night", -1)) == s.current_night_index

static func price(s: RunState) -> int:
	return 150 if FirstDebt.last(s, "fd_dragon_quote").get("choice_id") == "fair" else 200

static func ready(day: DayController, counter: CounterService) -> bool:
	var s := day.state
	return waiting(s) and counter.customers.active(s) == null and s.pending_event_id.is_empty() and s.risk_pending.is_empty() and not MirrorEndingService.active(s) and PawnReturnService.current(s).is_empty() and not SocialRules.blocked(s) and not MilitaryIntroduction.active(s) and not MirrorEncounterService.new(counter.catalog).pending(day)

static func reason(day: DayController, counter: CounterService, id: String, choice: String) -> String:
	var s := day.state
	if not enabled(s): return "这局没有这桩约定。"
	if id == "fd_search_motive":
		if FirstDebt.flag(s, "fd_compensation_agreed"): return "赔偿已经谈妥，先把这件事办完。"
		if not FirstDebt.chen_waiting(s) or FirstDebt.settled(s): return "等陈小满得空再谈。"
		if FirstDebt.flag(s, "fd_search_promised"): return "已经答应替她打听。"
		if int(FirstDebt.last(s, id).get("night", -1)) == s.current_night_index: return "陈小满已告辞，改日再谈。"
		return ""
	if not ready(day, counter): return "等陆掌眼到了空柜前再谈。"
	if id == "fd_dragon_quote":
		if quoted(s): return "这次的价钱已经谈定。"
		var correct := "fair" if int(s.social.reputation) >= 0 else "dear"
		if choice != correct: return "请按这回的价钱谈。"
	if id == "fd_dragon_deal":
		if not quoted(s): return "先验看龙镯、问清价钱。"
		if choice == "buy" and s.cash < price(s): return "现银不足%d银元。" % price(s)
	return ""

static func acquire(s: RunState) -> void:
	var item := ItemInstance.new()
	item.instance_id = "first_debt/dragon"
	item.definition_id = FirstDebt.DRAGON
	item.selected_variant_id = "sound"
	item.revealed_clue_ids.assign(["form", "mark", "repair"])
	InventoryManager.new().acquire(s, item, "first_debt/lu", price(s))
	EconomyManager.new().commit(s, -price(s), item.instance_id, "first_debt/buy_dragon", "acquisition", 0)

static func motive_text(s: RunState, body: String) -> String:
	if FirstDebt.owned(s, FirstDebt.PHOENIX) == null:
		body = body.replace("如今凤的找着了，龙的还不知道在哪里。", "凤的下落已经对上了，龙的还不知道在哪里。")
		body += "\n你把凤镯眼下的去处告诉她：" + FirstDebt.whereabouts(s)
	return body

static func decorate(model: Dictionary, day: DayController, counter: CounterService) -> void:
	var s := day.state
	if not ready(day, counter): return
	# Existing appointment actors (especially the mirror husband) keep priority.
	if not str(model.get("active_id", "")).is_empty() and not str(model.active_id).begins_with("first_debt/"): return
	var buttons: Array = []
	var id := "fd_dragon_deal" if quoted(s) else "fd_dragon_quote"
	var e := counter.catalog.get_definition("events", id) as EventDefinition
	for c in e.choices:
		var error := reason(day, counter, id, c.id)
		if not error.is_empty() and not error.begins_with("现银不足"): continue
		buttons.append({"command": "fd_event", "target_id": id, "detail": c.id, "label": "付%d银元收下龙镯 · 5分钟" % price(s) if c.id == "buy" else c.label, "enabled": error.is_empty(), "reason": error})
	var text := e.body
	if quoted(s): text = "陆掌眼把龙镯留在布上：‘方才说定的，%d银元。掌柜可拿定主意了？’" % price(s)
	model.active_id = "first_debt/%d/lu" % s.current_night_index
	model.customer = "陆掌眼"; model.item = "龙镯"; model["itemless"] = false
	model.context_actions = {"customer": [{"id": "dialogue", "label": "验看与谈价", "enabled": true}], "item": [{"id": "dialogue", "label": "验看与谈价", "enabled": true}]}
	model.visual = {"customer_id": "fd_lu", "portrait_asset": "fd.lu", "customer_name": "陆掌眼", "attitude": "应约带货来", "deadline": "收铺前", "introduction": "你托人寻找的龙镯，带来了。", "intent": "旧货转让", "item_asset": "fd.dragon", "item_name": "龙镯", "item_status": "陆掌眼携来", "estimate": "%d银元" % price(s) if quoted(s) else "验看后谈价", "clues": [], "speech": []}
	model["case_dialogue"] = {"text": text, "buttons": buttons, "auto_open": false, "speaker": "陆掌眼", "key": model.active_id}
	model.dialogue = {"body": text, "buttons": buttons, "visit_id": model.active_id, "preserve_ticket_body": true}
	model.trade.can_offer = false; model.trade.can_pawn = false
	model.trade.buttons = []; model.appraisal.buttons = []

static func notice(s: RunState) -> String:
	if not enabled(s): return ""
	if FirstDebt.item_exists(s, FirstDebt.DRAGON): return "龙镯已从陆掌眼处买回。"
	if not FirstDebt.last(s, "fd_dragon_quote").is_empty(): return "陆掌眼带来的龙镯，工记与纹样同陈家原票相合。未成交时，可在开铺前另约。"
	if FirstDebt.flag(s, "fd_search_message"): return "陆掌眼手上有一只符合描述的龙镯，可在开铺前约来验看。"
	if not preparation(s, "dragon_search").is_empty(): return "已托人寻找龙镯，收铺后等口信。"
	if FirstDebt.flag(s, "fd_search_promised"): return "答应替陈家打听另一只龙镯，开铺前可托人寻找。"
	return ""
