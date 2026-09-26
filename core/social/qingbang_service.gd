class_name QingbangService
extends RefCounted

static func conflict(state: RunState, run: RunDefinition) -> bool:
	if not state.social.pending.is_empty() or SocialRules.night(state).get("military_event",false) or MilitaryIntroduction.active(state) or not state.pending_event_id.is_empty(): return true
	var appointment := InvestigationService.appointment(state)
	if appointment.get("status","") == "booked" and appointment.night == state.current_night_index: return true
	# Only actual, fixed daytime meetings reserve a whole night. Bedroom scenes,
	# ordinary authored customers and unmet story prerequisites do not starve fees.
	for id in run.event_ids:
		var event := state.ghost_catalog.get_definition("events",id) as EventDefinition
		if event.kind != "anchor" or event.phase not in ["pre_open","open"] or event.night_min != state.current_night_index or event.night_max != state.current_night_index: continue
		var probe := RunSnapshot.copy(state)
		probe.phase = StringName(event.phase)
		probe.game_minutes = event.window_start
		if EventDirector.new(state.ghost_catalog).eligible(probe,event): return true
	return false

static func dawn(state: RunState, run: RunDefinition) -> void:
	if not QingbangRules.active(state): return
	var q: Dictionary = state.social.qingbang
	var n := state.current_night_index
	QingbangSupplies.deliver_inquiries(state)
	if n in q.checked: return
	q.checked.append(n)
	if n < 4: return
	if not q.introduced:
		if not MilitaryIntroduction.active(state): q.dialogue = {"kind":"intro","step":0,"id":"qingbang/intro"}
		return
	if not q.pending.is_empty() or not q.dialogue.is_empty() or conflict(state,run): return
	if n >= int(q.next_fee):
		q.pending = {"kind":"fee","id":"qingbang/fee/%d" % n,"night":n,"cost":QingbangRules.fee(q.relation)}
		q.next_fee = n + int(QingbangRules.config().fee_interval)
		q.dialogue = {"kind":"fee","step":0,"id":q.pending.id}
		return
	for claim in q.claims:
		if claim.status == "waiting" and n >= int(claim.due):
			q.pending = {"kind":"claim","id":claim.id}
			QingbangRules.notice(state,"旧货主拿着凭据找上门，请翻看《往来簿》的青帮来信。")
			return
	if n - int(q.last_supply) <= int(QingbangRules.config().supply_quiet): return
	if VarietyService.rng(state.run_seed,"qingbang/supply/chance/%d" % n).randi_range(0,99) >= int(QingbangRules.config().supply_chance): return
	var pool: Array = QingbangRules.config().supplies.filter(func(r: Dictionary) -> bool: return r.id != q.last_supply_id)
	var offer: Dictionary = VarietyService.pick(pool,state.run_seed,"qingbang/supply/%d" % n).duplicate(true)
	q.pending = {"kind":"supply","id":"qingbang/supply/%d" % n,"offer":offer}
	QingbangRules.notice(state,"沈伯钧递来货单，请你先看出处，再决定是否约人带货。")

static func opening(day: DayController) -> void:
	var state := day.state
	if not QingbangRules.active(state): return
	var q: Dictionary = state.social.qingbang
	var n := state.current_night_index
	if n in q.opening_checked: return
	q.opening_checked.append(n)
	if not q.introduced or SocialRules.closed(state) or conflict(state,day.definition): return
	if int(q.relation) >= int(QingbangRules.config().raid_threshold) or n <= int(q.last_refusal) or n - int(q.last_raid) <= int(QingbangRules.config().raid_quiet): return
	if q.fees.any(func(f: Dictionary) -> bool: return f.night == n): return
	if q.supplies.any(func(f: Dictionary) -> bool: return f.night == n): return
	if VarietyService.rng(state.run_seed,"qingbang/raid/%d" % n).randi_range(0,99) >= int(QingbangRules.config().raid_chance): return
	var id := "qingbang/raid/%d" % n
	q.dialogue = {"kind":"raid","step":0,"id":id,"items":QingbangDamage.pick(state,id)}

static func reason(day: DayController, command: String, detail: String) -> String:
	var state := day.state
	if not QingbangRules.active(state): return "尚无这项往来。"
	var q: Dictionary = state.social.qingbang
	if command == "talk": return "" if not q.dialogue.is_empty() and detail == QingbangConversation.token(state) else "柜前的话已说过，请按眼前来意作答。"
	if not q.introduced: return "还没有认识青帮的管事。"
	if state.phase not in [&"pre_open",&"open"]: return "请在开铺前或营业时办理。"
	var answering_fee: bool = command in ["pay", "refuse"] and q.dialogue.get("kind", "") == "fee" and q.dialogue.get("id", "") == detail
	if (not q.dialogue.is_empty() and not answering_fee) or MilitaryIntroduction.active(state) or not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or not PawnReturnService.current(state).is_empty() or MirrorEncounterService.new(state.ghost_catalog).pending(day): return "请先把柜前的事情办完。"
	match command:
		"pay","refuse":
			if q.pending.get("kind","") != "fee" or detail != q.pending.id: return "这回的照应钱已经有了答复。"
			if command == "pay" and state.cash < int(q.pending.cost): return "现银不足，不能交清这笔钱。"
		"gift":
			if not detail.is_empty(): return "请按眼前的往来办理。"
			if state.phase != &"pre_open" or PreparationService.used(state,"finish",state.current_night_index): return "须在开铺前准备尚未结束时托人。"
			if PreparationService.count(state) >= 2: return "今夜行动点已经用完。"
			if state.current_night_index - int(q.last_gift) <= int(QingbangRules.config().gift_quiet): return "礼才送到，须隔两个完整夜次再递。"
			if state.cash < int(QingbangRules.config().gift_cost): return "备礼需20银元，现银不足。"
		"select_supply","decline_supply":
			if q.pending.get("kind","") != "supply" or detail != q.pending.id: return "这份货单已经答复。"
			if state.phase != &"pre_open" or SocialRules.closed(state): return "今夜不能约新货。"
		"check_supply","inquire","read_inquiry": return QingbangSupplies.reason(day,command,detail)
		"claim_return","claim_compensate","claim_intervene","claim_later": return QingbangSupplies.claim_reason(day,command,detail)
		_: return "没有这项青帮往来。"
	return ""

static func perform(day: DayController, command: String, detail: String) -> ActionResult:
	var error := reason(day,command,detail)
	if not error.is_empty(): return ActionResult.new(false,error)
	if command == "talk": return QingbangConversation.advance(day)
	var state := day.state
	var q: Dictionary = state.social.qingbang
	var n := state.current_night_index
	var text := ""
	match command:
		"pay","refuse":
			var p: Dictionary = q.pending.duplicate(true)
			if command == "pay":
				EconomyManager.new().commit(state,-int(p.cost),"",p.id,"qingbang_expense")
				QingbangRules.change(state,int(QingbangRules.config().fee_delta),"fee_paid")
				text = "沈伯钧点过%d银元，收起钱袋：‘账记下了，下回第%d夜再来。’" % [int(p.cost),int(q.next_fee)]
			else:
				q.last_refusal = n
				QingbangRules.change(state,int(QingbangRules.config().refuse_delta),"fee_refused")
				text = "沈伯钧收回钱袋：‘掌柜不肯照规矩来，往后铺里磕了碰了，可别怪弟兄们不客气。’今夜仍可营业；这笔钱不记欠账。"
			p["result"] = command
			q.fees.append(p)
			q.pending = {}
			q.dialogue = {}
		"gift":
			EconomyManager.new().commit(state,-int(QingbangRules.config().gift_cost),"","qingbang/gift/%d" % n,"qingbang_expense")
			q.last_gift = n
			q.gifts.append({"night":n})
			QingbangRules.change(state,int(QingbangRules.config().gift_delta),"gift")
			text = "薄礼送到了。沈伯钧让人回话：‘掌柜肯讲情面，往后的话就好说。’花费20银元，占1行动点。"
		"select_supply","decline_supply":
			var offer: Dictionary = q.pending.offer.duplicate(true)
			q.last_supply = n
			q.last_supply_id = offer.id
			if command == "select_supply":
				var id: String = q.pending.id
				offer.merge({"visit_id":id,"instance_id":"item/" + id,"night":n,"bought":false,"investigated":false})
				q.supplies.append(offer)
			q.pending = {}
			text = "已约带货人开铺后登门，可以验货、查问，再谈收不收。" if command == "select_supply" else "你谢绝了货单，沈伯钧收好，没有为难。"
		"check_supply","inquire","read_inquiry": return QingbangSupplies.perform(day,command,detail)
		_: return QingbangSupplies.claim(day,command,detail)
	QingbangRules.notice(state,text)
	return ActionResult.new(true,text)
