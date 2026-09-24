class_name MilitaryService
extends RefCounted

const LEGACY_INTRODUCTION := "第二日开铺前，孙大元登门，将名帖放在柜上。\n\n‘我姓孙，孙大元。这一带的街面，归我管。今日过来，同掌柜打个招呼。往后在这里做生意，规矩还是要守的。’\n\n‘营里偶尔有些差事，单子会送到铺上，记在《往来簿》里。掌柜得空翻看。接不接，由你斟酌；既接下了，便照单办妥。’\n\n你收下名帖，将这笔往来记入簿中。"
const INTRODUCTION := "第二日开铺前，孙大元登门，自称奉营部之命，负责这一带的街面巡查和军需采办。\n\n他提到城门岗哨与巡兵，又说铺子该查、该停，营部一纸命令就能定；若往来办得妥当，好货与差事也会想到当铺。\n\n眼下营里采购棉袄，采购单会记在《往来簿》里。接单由掌柜自定，备齐货后交货领赏。你称他孙长官，收下名帖，将这笔往来记入簿中。"

static func band(value: int) -> Dictionary:
	for row in SocialRules.config().bands:
		if value <= int(row.max): return row
	return {}

static func buyer_night(state: RunState, buyer_id: String) -> int:
	return state.current_night_index - int(state.social.buyer_delays.get(buyer_id, 0)) if state.social_enabled else state.current_night_index

static func quiet(last: int, night: int, length: int) -> bool:
	return night - last <= length

static func protected_night(state: RunState, run: RunDefinition) -> bool:
	var appointment := InvestigationService.appointment(state)
	if appointment.get("status", "") == "booked" and appointment.night == state.current_night_index: return true
	for event_id in run.event_ids:
		var event := state.ghost_catalog.get_definition("events", event_id) as EventDefinition
		if DragonSearch.enabled(state) and (event.presentation.get("scene", "") == "first_debt" or event.id == "ds_search_message"): continue
		if event.kind != "anchor" or state.current_night_index < event.night_min or state.current_night_index > event.night_max: continue
		if not event.required_flags.all(func(flag: String) -> bool: return flag in state.narrative_flags): continue
		if event.excluded_flags.any(func(flag: String) -> bool: return flag in state.narrative_flags): continue
		if state.event_history.filter(func(row: Dictionary) -> bool: return row.event_id == event.id).size() >= event.max_count: continue
		if not event.required_items.all(func(id: String) -> bool: return state.inventory_instances.any(func(item: ItemInstance) -> bool: return item.definition_id == id and item.ownership_state in ["owned", "pledged"])): continue
		return true
	# Authored callers (mirror, ghost bargains) must never disappear behind a seal.
	for visit in state.visits:
		if visit.purpose in ["husband_meeting"] or not (state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition).guest_rule.is_empty(): return true
	for row in state.ordinary_selections:
		if row.night == state.current_night_index and row.get("context_id", "").is_empty(): return true
	return false

static func dawn(state: RunState, run: RunDefinition) -> void:
	if not state.social_enabled or state.phase != &"pre_open": return
	var snap := SocialRules.night(state)
	if snap.is_empty() or snap.military_checked: return
	# Snapshot all draws before preparation; UI reads never draw or change state.
	snap.military_checked = true
	var n := state.current_night_index
	if n < 2: return
	if not state.social.introduced:
		if state.social.has("intro_step"):
			state.social.intro_step = 0
			return
		state.social.introduced = true
		MilitaryPlaque.award(state)
		SocialRules.military_notice(state, INTRODUCTION)
	for supply in state.social.supplies:
		if not supply.get("bought", false) or not supply.disputed or supply.get("claim_created", false) or n < int(supply.bought_night) + 2: continue
		supply.claim_created = true
		state.social.claims.append({"id": supply.instance_id, "supply_id": supply.id, "price": supply.paid, "status": "waiting", "due": n, "postponed": false})
	for claim in state.social.claims:
		if claim.status == "waiting" and claim.due <= n:
			state.social.pending = {"kind": "claim", "id": claim.id}
			snap["military_event"] = true
			return
	if quiet(int(state.social.last_event), n, int(SocialRules.config().quiet_nights)): return
	var policy := band(state.social.military)
	var kind := ""
	if state.social.first_fee_due and int(state.social.military) <= -20: kind = "fee"
	else:
		var roll := VarietyService.rng(state.run_seed, "military/event/%d" % n).randi_range(0, 99)
		# Disjoint intervals: a forbidden closure does not become a second fee draw.
		if roll < int(policy.closure):
			if state.social.fee_seen and state.social.threatened and not protected_night(state, run) and not quiet(int(state.social.last_closure), n, int(SocialRules.config().closure_quiet_nights)): kind = "closure"
		elif roll < int(policy.closure) + int(policy.fee): kind = "fee"
		elif int(policy.supply) > 0 and roll < int(policy.supply): kind = "supply"
	if kind.is_empty(): return
	snap["military_event"] = true
	state.social.pending = {"kind": kind, "night": n, "cost": int(policy.release_cost if kind == "closure" else policy.fee_cost)}
	if kind == "supply":
		var pool: Array = SocialRules.config().supplies.filter(func(row: Dictionary) -> bool: return int(row.tier) <= int(state.social.military) and row.id != state.social.last_supply)
		var offers: Array = []
		for i in (2 if int(state.social.military) >= 80 else 1):
			var picked: Dictionary = VarietyService.pick(pool, state.run_seed, "military/supply/%d/%d" % [n, i])
			offers.append(picked.duplicate(true)); pool.erase(picked)
		state.social.pending["offers"] = offers
	if kind == "fee": SocialRules.military_notice(state, "门口来了两个穿军衣的人。孙大元捎话，要你备%d银元‘照应街面’。翻开柜台上的《往来簿》，把话说清。" % int(policy.fee_cost))
	if kind == "closure": SocialRules.military_notice(state, "孙大元带来停业令：‘今夜不许接新生意。若要撤令，开门前把手续办妥。’疏通需%d银元，须在开铺前办妥。" % int(policy.release_cost))
	if kind == "supply": SocialRules.military_notice(state, "孙大元托来口信，有几件旧物想请你先过目。价钱和来路写在柜台上的《往来簿》里。")

static func end_event(state: RunState) -> void:
	state.social.last_event = state.current_night_index
	state.social.pending = {}

static func contract_template(_state: RunState) -> Dictionary:
	return SocialRules.config().contracts[0].duplicate(true)

static func claim_for(state: RunState, id: String) -> Dictionary:
	for row in state.social.claims:
		if row.id == id: return row
	return {}

static func supply_for(state: RunState, id: String) -> Dictionary:
	for row in state.social.supplies:
		if row.visit_id == id or row.instance_id == id: return row
	return {}

static func reason(day: DayController, command: String, detail := "") -> String:
	var state := day.state
	if not state.social_enabled or not state.social.introduced: return "经办人尚未来过，眼下没有军方往来。"
	if state.phase not in [&"pre_open", &"open"]: return "这件事须在开铺前或营业时办理。"
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or not PawnReturnService.current(state).is_empty() or MirrorEncounterService.new(state.ghost_catalog).pending(day) or MirrorEndingService.active(state): return "请先处理眼前的事情。"
	var pending: Dictionary = state.social.pending
	var contract: Dictionary = state.social.contract
	match command:
		"gift":
			if state.phase != &"pre_open" or PreparationService.used(state, "finish", state.current_night_index): return "须在准备结束前托人送礼。"
			if PreparationService.count(state) >= 2: return "今夜两次准备已经用完。"
			if not state.social.gifts.is_empty() and quiet(int(state.social.gifts.back().night), state.current_night_index, 2): return "上次的礼才送到，隔两夜再托人。"
			if state.cash < int(SocialRules.config().gift_cost): return "送礼需20银元，现银不足。"
		"accept_contract", "decline_contract":
			if SocialRules.blocked(state): return "先把眼前的军方来意处理妥当。"
			if not contract.is_empty(): return "先前接下的棉袄还没交齐。"
		"cancel_contract":
			if SocialRules.blocked(state): return "先把眼前的军方来意处理妥当。"
			if contract.is_empty(): return "没有已经接下的采购单。"
		"deliver":
			if SocialRules.blocked(state): return "先把眼前的军方来意处理妥当。"
			if SocialRules.closed(state): return "今夜不办新交货；采购期限已顺延。"
			if contract.is_empty(): return "没有已经接下的采购单。"
			return CoatProcurement.delivery_reason(state, detail)
		"pay", "refuse", "close", "select_supply", "decline_supply":
			if state.phase != &"pre_open" or pending.is_empty(): return "这桩来意已经处理。"
			var kind: String = pending.kind
			var allowed: Dictionary = {"fee": ["pay", "refuse"], "closure": ["pay", "close"], "supply": ["select_supply", "decline_supply"]}
			if command not in allowed.get(kind, []): return "这不是眼前可办理的事。"
			if command == "pay" and state.cash < int(pending.cost): return "现银不足，需要%d银元。" % int(pending.cost)
			if command == "select_supply" and not pending.offers.any(func(row: Dictionary) -> bool: return row.id == detail): return "这批货里没有这一件。"
		"check_supply":
			var visit := CustomerManager.new().active(state)
			if state.phase != &"open" or visit == null or visit.visit_id != detail: return "须先接待带这件货来的人。"
			var supply := supply_for(state, detail)
			if supply.is_empty() or supply.get("investigated", false): return "这份来源已经问过，或不是这批货。"
			if state.cash < 2 or state.game_minutes + 10 >= mini(visit.expires_at, day.definition.night_minutes): return "核查需2银元、10分钟，须在客人离开前办妥。"
		"claim_return", "claim_compensate", "claim_military", "claim_later":
			if pending.get("kind", "") != "claim": return "眼下没有这桩追索。"
			var claim := claim_for(state, pending.id)
			if command == "claim_return":
				var item := InventoryManager.new().find(state, claim.id)
				if item == null or item.ownership_state != "owned": return "原物已不在铺里，须另谈赔偿或协调。"
			if command == "claim_compensate" and state.cash < ceili(float(claim.price) / 2): return "赔偿需%d银元，现银不足。" % ceili(float(claim.price) / 2)
			if command == "claim_military" and int(state.social.military) < 20: return "经办人眼下不肯替你出面；可以先托人打点，或另谈处置。"
		_: return "没有这项往来。"
	if command not in ["deliver", "select_supply", "check_supply"] and not detail.is_empty(): return "请按眼前这桩事务办理。"
	return ""

static func perform(day: DayController, command: String, detail := "") -> ActionResult:
	if command == "intro_talk": return MilitaryIntroduction.advance(day, detail)
	var error := reason(day, command, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	var social: Dictionary = state.social
	var n := state.current_night_index
	var text := ""
	match command:
		"gift":
			var cost: int = SocialRules.config().gift_cost
			EconomyManager.new().commit(state, -cost, "", "military/gift/%d" % n, "military_expense")
			social.gifts.append({"night": n, "cost": cost})
			SocialRules.change(state, "military", int(SocialRules.config().gift_delta), "gift")
			text = "礼已托人送到，花费%d银元，占一次准备。经办人收下名帖，说往后有事可以递话。" % cost
		"accept_contract":
			var order := contract_template(state)
			order.merge({"accepted": n, "due": 0, "number": social.contracts.size() + 1})
			social.contract = order
			text = "棉袄采购已接下。自有棉袄三件一并交货，完成奖励50银元，不限期限。"
		"decline_contract":
			social.last_contract = n
			text = "你暂且谢绝。孙大元收回单子：‘哪天有货，再来找我。’"
		"cancel_contract":
			finish_contract(state, "cancelled", -10)
			text = "你退回已接的单子。经办人皱起眉，把你的名字另划了一笔。"
		"deliver":
			CoatProcurement.deliver(state, detail)
			text = "孙大元点清三件棉袄，付了50银元：‘这批收妥。还有货，可以再接一单。’"
		"pay", "refuse", "close":
			var pending: Dictionary = social.pending
			var kind: String = pending.kind
			if command == "pay": EconomyManager.new().commit(state, -int(pending.cost), "", "military/%s/%d" % [kind, n], "military_expense")
			if kind == "fee":
				social.first_fee_due = false; social.fee_seen = true; social.threatened = true
				SocialRules.change(state, "military", 2 if command == "pay" else -8, "protection_" + command)
				text = "银元交清，来人收了条子。‘近来别惹麻烦，真要封门，可就不是这点钱了。’" if command == "pay" else "你没有交钱。来人把空钱袋拍在柜上：‘下回再说不凑手，就等着歇铺吧。’今夜仍可营业。"
			else:
				social.last_closure = n
				if command == "close": suspend(day)
				text = "停业令已经撤下，今夜可以照常营业。" if command != "close" else "今夜停接新生意。息费照付，原当户仍可来赎；受阻的约定顺延一夜。可开门守铺办理旧票，或整理铺中旧物。"
			end_event(state)
		"select_supply":
			for offered in social.pending.offers:
				if offered.id != detail: continue
				var row: Dictionary = offered.duplicate(true)
				var id := "%s/%d/military_supply" % [day.definition.id, n]
				row.merge({"night": n, "visit_id": id, "instance_id": "item/" + id, "selected": true, "bought": false, "investigated": false})
				social.supplies.append(row); social.last_supply = row.id
			text = "已约带货人开铺后到柜前。这件货尚未付款，可以先验物、问来路，再决定是否收下。"
			end_event(state)
		"decline_supply":
			social.last_supply = social.pending.offers[0].id
			end_event(state)
			text = "你谢过这次介绍，经办人收回货单，没有追问。"
		"check_supply":
			var row := supply_for(state, detail)
			day.spend_action(10)
			EconomyManager.new().commit(state, -2, "", "military/check/" + detail, "military_expense")
			row.investigated = true
			text = row.report
			CustomerManager.new().update(state)
		"claim_return", "claim_compensate", "claim_military", "claim_later":
			var claim := claim_for(state, social.pending.id)
			if command == "claim_return":
				var item := InventoryManager.new().find(state, claim.id)
				CommerceService.commit_sale(state, item, "military_return", item.acquisition_price)
				SocialRules.change(state, "military", -4, "return_disputed_goods")
				SocialRules.change(state, "reputation", 2, "owner_witness_return")
				text = "你把原物交还旧主，经办人退回货款。旧主在门口向街坊说明此事，经办人却冷了脸。"
			elif command == "claim_compensate":
				EconomyManager.new().commit(state, -ceili(float(claim.price) / 2), "", "military/compensate/" + claim.id, "military_expense")
				SocialRules.change(state, "reputation", 2, "owner_witness_compensation")
				text = "双方按原收货款的一半议定补偿。旧主签下和解字据，在门口向街坊说清不再追索；货物由你留存或照原去向处理。"
			elif command == "claim_military":
				SocialRules.change(state, "military", 4, "military_intervention")
				SocialRules.change(state, "reputation", -4, "street_witness_intervention")
				text = "经办人当着街坊把旧主劝走，说这件事由营里接手。旧主回头看了铺门一眼，围着的人也散了。"
			else:
				if not claim.postponed:
					claim.postponed = true; claim.due = n + 1; social.pending = {}
					text = "旧主答应明夜再来，盼你留好物证，把钱和话都理清。"
				else:
					SocialRules.change(state, "reputation", -4, "owner_public_complaint")
					text = "你仍未能给出处理办法。旧主不再等，拿着字据去街坊间诉说这桩事。"
			if command != "claim_later" or social.pending.get("kind", "") == "claim":
				claim.status = command; claim["ended"] = n; social.pending = {}
	SocialRules.military_notice(state, text)
	return ActionResult.new(true, text)

static func finish_contract(state: RunState, result: String, amount: int) -> void:
	var row: Dictionary = state.social.contract.duplicate(true)
	row["result"] = result; row["ended"] = state.current_night_index
	state.social.contracts.append(row)
	state.social.contract = {}
	state.social.last_contract = state.current_night_index
	SocialRules.change(state, "military", amount, "contract_" + result)

static func settle(_state: RunState) -> void:
	pass # Cotton-coat orders have no deadline.

static func suspend(day: DayController) -> void:
	var state := day.state
	SocialRules.night(state).closed = true
	for visit in state.visits:
		# Preserve named/familiar and specifically invited visits for the next night.
		var invited := state.preparation_history.any(func(r: Dictionary) -> bool: return r.night == state.current_night_index and r.action in ["attract", "target", "seek"] and visit.visit_id in r.visit_ids)
		for original in state.ordinary_selections:
			if original.visit_id == visit.visit_id and (original.get("familiar_reserved", false) or original.get("early_redemption", false) or invited):
				var row: Dictionary = original.duplicate(true)
				row.night = state.current_night_index + 1
				state.social.deferred_visits.append(row)
		visit.status = "suspended"
	# Fixed buyer appointments keep their authored price/window; move the night only.
	for buyer_id in day.definition.buyer_ids:
		var buyer := state.ghost_catalog.get_definition("buyers", buyer_id) as BuyerDefinition
		if buyer.night_min == buyer.night_max and state.current_night_index == buyer.night_min + int(state.social.buyer_delays.get(buyer_id, 0)):
			state.social.buyer_delays[buyer_id] = int(state.social.buyer_delays.get(buyer_id, 0)) + 1
			SocialRules.military_notice(state, "%s原定今夜的收货，已托人改到第%d夜，时段与收货条件照旧。" % [buyer.display_name, state.current_night_index + 1])

static func spawn_supply(state: RunState) -> void:
	if not state.social_enabled or SocialRules.closed(state): return
	for row in state.social.supplies:
		if row.night != state.current_night_index or state.visits.any(func(v: CustomerVisit) -> bool: return v.visit_id == row.visit_id): continue
		var customer := state.ghost_catalog.get_definition("customers", "customer_hawker") as CustomerDefinition
		var visit := CustomerVisit.new()
		visit.visit_id = row.visit_id; visit.customer_id = customer.id
		visit.person = {"id": "military/" + row.id, "name": "孙大元介绍的带货人", "portrait": customer.portrait_asset_id}
		visit.voice = customer.persona.duplicate(true)
		visit.voice.introduction = row.title + "\n" + row.cue + "\n‘货在这儿，掌柜先验，再谈价。’"
		visit.voice.source_claim = row.cue
		visit.arrival = 0; visit.expires_at = 180
		visit.transaction_modes.assign(["sell"])
		visit.item = ItemInstance.new()
		visit.item.instance_id = row.instance_id; visit.item.definition_id = row.item; visit.item.selected_variant_id = row.variant
		visit.trade.opening_price = int(row.price); visit.trade.asking_price = int(row.price); visit.trade.reserve_price = maxi(1, ceili(float(row.price) * 0.9))
		visit.trade.rounds_left = customer.max_quote_rounds; visit.trade.patience = customer.patience
		state.visits.push_front(visit)

static func departed(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not state.social_enabled: return
	var row := supply_for(state, visit.visit_id)
	if row.is_empty(): return
	row["outcome"] = outcome
	if outcome == "bought":
		row.bought = true; row["bought_night"] = state.current_night_index; row["paid"] = visit.item.acquisition_price
