class_name QingbangSupplies
extends RefCounted

static func find(state: RunState, id: String) -> Dictionary:
	if not QingbangRules.active(state): return {}
	for row in state.social.qingbang.supplies:
		if id in [row.visit_id,row.instance_id]: return row
	return {}

static func spawn(state: RunState) -> void:
	if not QingbangRules.active(state) or SocialRules.closed(state): return
	for row in state.social.qingbang.supplies:
		if row.night != state.current_night_index or state.visits.any(func(v: CustomerVisit) -> bool: return v.visit_id == row.visit_id): continue
		var customer := state.ghost_catalog.get_definition("customers","customer_hawker") as CustomerDefinition
		var visit := CustomerVisit.new()
		visit.visit_id = row.visit_id
		visit.customer_id = customer.id
		visit.person = {"id":"qingbang/" + row.id,"name":"青帮介绍的带货人","portrait":customer.portrait_asset_id}
		visit.voice = customer.persona.duplicate(true)
		visit.voice.introduction = row.title + "\n" + row.cue + "\n‘货在这儿，先验再议。’"
		visit.voice.source_claim = row.cue
		visit.arrival = 0
		visit.expires_at = 180
		visit.transaction_modes.assign(["sell"])
		visit.item = ItemInstance.new()
		visit.item.instance_id = row.instance_id
		visit.item.definition_id = row.item
		visit.item.selected_variant_id = row.variant
		visit.trade.opening_price = int(row.price)
		visit.trade.asking_price = int(row.price)
		visit.trade.reserve_price = maxi(1,ceili(float(row.price)*0.9))
		visit.trade.rounds_left = customer.max_quote_rounds
		visit.trade.patience = customer.patience
		state.visits.push_front(visit)

static func departed(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	var row := find(state,visit.visit_id)
	if row.is_empty() or row.has("outcome"): return
	row["outcome"] = outcome
	if outcome != "bought": return
	row.bought = true
	row["paid"] = visit.item.acquisition_price
	row["bought_night"] = state.current_night_index
	var q: Dictionary = state.social.qingbang
	if int(q.last_trade_reward) != state.current_night_index:
		q.last_trade_reward = state.current_night_index
		QingbangRules.change(state,int(QingbangRules.config().trade_delta),"supply_trade")
	if row.disputed:
		q.claims.append({"id":row.instance_id,"status":"waiting","due":state.current_night_index + 2,"postponed":false})
	QingbangRules.notice(state,"收下%s，付%d银元。沈伯钧托人说，这笔买卖记下了。" % [row.title,int(row.paid)])

static func inquiry(state: RunState, id: String) -> Dictionary:
	for row in state.social.qingbang.inquiries:
		if row.id == id: return row
	return {}

static func reason(day: DayController, command: String, detail: String) -> String:
	var state := day.state
	var q: Dictionary = state.social.qingbang
	if command == "check_supply":
		var visit := CustomerManager.new().active(state)
		if visit == null or visit.visit_id != detail or state.phase != &"open": return "须先接待带货人。"
		var supply := find(state,detail)
		if supply.is_empty() or supply.investigated: return "这件货的来源已经核查。"
		if state.cash < 2 or state.game_minutes + 10 >= mini(visit.expires_at,day.definition.night_minutes): return "需2银元、10分钟，须在带货人离开前查完。"
		return ""
	if command == "read_inquiry":
		var row := inquiry(state,detail)
		return "" if not row.is_empty() and row.status == "delivered" else "还没有新的调查回报。"
	var item := InventoryManager.new().find(state,detail)
	if item == null or item.ownership_state != "owned" or not QingbangDamage.ordinary(state,item): return "只能打听铺中自有普通现货的来路。"
	if q.inquiries.any(func(r: Dictionary) -> bool: return r.status == "waiting"): return "前一项打听尚未回话。"
	if not inquiry(state,detail).is_empty(): return "这件货已经托人打听过。"
	if item.provenance.get("status","unchecked") in ["verified","mismatch"] or item.provenance.get("investigated",false): return "来路已核查，不能重复委托。"
	var supply := find(state,detail)
	if not supply.is_empty() and supply.investigated: return "这件货的来路已经问明。"
	if state.cash < int(QingbangRules.config().inquiry_cost): return "打听需10银元，现银不足。"
	return ""

static func report(state: RunState, item: ItemInstance) -> String:
	var supply := find(state,item.instance_id)
	if not supply.is_empty(): return supply.report
	var definition := state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
	if not item.provenance.is_empty():
		var status := ProvenanceService.outcome(item.provenance.truth)
		return "托人查到的口信：" + String(definition.provenance.get(status,"暂时没有找到可作证的人，来路仍不能坐实。"))
	var claim: String = definition.provenance.get("claim","")
	return ("街面打听到的口信：" + claim + "。这次没有找到可独立作证的人，来路仍不能坐实。") if not claim.is_empty() else "托问过附近的货栈和旧货铺，暂时没人认得这件货。未找到原主或出让字据，来路仍不能坐实。"

static func perform(day: DayController, command: String, detail: String) -> ActionResult:
	var state := day.state
	var text := ""
	if command == "check_supply":
		var row := find(state,detail)
		row.investigated = true
		EconomyManager.new().commit(state,-2,"","qingbang/check/" + detail,"qingbang_expense")
		day.spend_action(10)
		CustomerManager.new().update(state)
		text = row.report
	elif command == "read_inquiry":
		var row := inquiry(state,detail)
		row.status = "read"
		text = row.report
	else:
		var item := InventoryManager.new().find(state,detail)
		var definition := state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
		var row := {"id":detail,"title":definition.display_name,"due":state.current_night_index + 1,"status":"waiting","report":report(state,item)}
		state.social.qingbang.inquiries.append(row)
		EconomyManager.new().commit(state,-int(QingbangRules.config().inquiry_cost),detail,"qingbang/inquiry/" + detail,"qingbang_expense")
		text = "已托人打听%s，花费10银元。第%d夜回话；货物先出手也不影响收信。" % [definition.display_name,int(row.due)]
	QingbangRules.notice(state,text)
	return ActionResult.new(true,text)

static func deliver_inquiries(state: RunState) -> void:
	for row in state.social.qingbang.inquiries:
		if row.status != "waiting" or state.current_night_index < int(row.due): continue
		row.status = "delivered"
		QingbangRules.notice(state,"关于%s的打听有了回话，可在青帮的‘打听’页拆阅。" % row.title)
		var supply := find(state,row.id)
		if not supply.is_empty(): supply.investigated = true
		var item := InventoryManager.new().find(state,row.id)
		if item != null and not item.provenance.is_empty() and supply.is_empty(): ProvenanceService.apply(item,"inquire")

static func claim_for(state: RunState, id: String) -> Dictionary:
	for row in state.social.qingbang.claims:
		if row.id == id: return row
	return {}

static func claim_reason(day: DayController, command: String, detail: String) -> String:
	var state := day.state
	var q: Dictionary = state.social.qingbang
	if q.pending.get("kind","") != "claim" or q.pending.id != detail: return "眼下没有这桩追索。"
	var supply := find(state,detail)
	if command == "claim_return":
		var item := InventoryManager.new().find(state,detail)
		if item == null or item.ownership_state != "owned": return "原物已经不在可退还状态，须另谈处置。"
	if command == "claim_compensate" and state.cash < ceili(float(supply.paid)/2): return "和解所需现银不足。"
	if command == "claim_intervene" and int(q.relation) < 20: return "沈伯钧眼下不肯替你出面。"
	return ""

static func claim(day: DayController, command: String, detail: String) -> ActionResult:
	var state := day.state
	var q: Dictionary = state.social.qingbang
	var row := claim_for(state,detail)
	var supply := find(state,detail)
	var text := ""
	match command:
		"claim_return":
			var item := InventoryManager.new().find(state,detail)
			CommerceService.commit_sale(state,item,"qingbang_return",item.acquisition_price)
			QingbangRules.change(state,-4,"return_disputed_goods")
			SocialRules.change(state,"reputation",2,"qingbang_public_return")
			text = "原物退还旧主，青帮退回收货款。旧主向街坊说明当铺肯讲道理；沈伯钧收了回话，脸色冷了些。"
		"claim_compensate":
			EconomyManager.new().commit(state,-ceili(float(supply.paid)/2),"","qingbang/compensate/" + detail,"qingbang_expense")
			SocialRules.change(state,"reputation",2,"qingbang_public_compensation")
			text = "你付了议定的补偿，旧主签下和解字据，向街坊说明不再追索。"
		"claim_intervene":
			QingbangRules.change(state,4,"intervention")
			SocialRules.change(state,"reputation",-4,"qingbang_public_intervention")
			text = "沈伯钧当着街坊的面把旧主带走。来人不再争辩，围观的人却朝当铺指指点点。"
		"claim_later":
			if not row.postponed:
				row.postponed = true
				row.due = state.current_night_index + 1
				q.pending = {}
				text = "旧主答应明夜再来，请你留好凭据，准备一个交代。"
				QingbangRules.notice(state,text)
				return ActionResult.new(true,text)
			SocialRules.change(state,"reputation",-4,"qingbang_public_complaint")
			text = "旧主不肯再等，拿着字据去向街坊诉说这桩事。"
	row.status = command
	row["ended"] = state.current_night_index
	q.pending = {}
	QingbangRules.notice(state,text)
	return ActionResult.new(true,text)
