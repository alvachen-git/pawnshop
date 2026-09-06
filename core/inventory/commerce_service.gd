class_name CommerceService
extends RefCounted

var catalog: ContentCatalog
var pawns := PawnController.new()

func _init(content: ContentCatalog) -> void:
	catalog = content

func quote(item: ItemInstance, buyer: BuyerDefinition) -> int:
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	var base := maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))
	return base + ProvenanceService.premium(item, buyer, base)

func sale_reason(day: DayController, item: ItemInstance, buyer: BuyerDefinition) -> String:
	if not day.definition.market.is_empty():
		var error := trip_reason(day, buyer)
		return error if not error.is_empty() else item_reason(day, item, buyer)
	if item == null or buyer == null or buyer.id not in day.definition.buyer_ids: return "物品或买家机会不存在。"
	for flag in buyer.required_flags:
		if flag not in day.state.narrative_flags: return "尚未取得买家介绍；请查看铺中记事。"
	if item.ownership_state != "owned": return "只有店铺所有的现货可出售；在当物品不可出售。"
	if day.state.phase != &"open": return "买家只在营业时收货。"
	if day.state.current_night_index < buyer.night_min or day.state.current_night_index > buyer.night_max or day.state.game_minutes < buyer.window_start or day.state.game_minutes >= buyer.window_end: return "当前不在买家到访窗口。"
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	var appointment_error := OrdinarySamplePlan.buyer_reason(day.state, buyer.id, definition.category, day.state.current_night_index, day.state.game_minutes)
	if not appointment_error.is_empty(): return appointment_error
	if definition.category not in buyer.categories or buyer.channel not in definition.sell_channels: return "此买家不收这类货。"
	var count := 0
	for sale in day.state.sale_records:
		if sale.buyer_id == buyer.id and sale.night == day.state.current_night_index: count += 1
	if buyer.capacity_per_night > 0 and count >= buyer.capacity_per_night: return "此买家今夜额度已用完。"
	if not TimeController.new().can_spend(day.state, day.definition, buyer.action_minutes): return "时间不足。"
	return ""

func execute(day: DayController, command: String, target: String, detail: String) -> ActionResult:
	if command in ["redeem", "extend"]:
		var ticket := pawns.find(day.state, target)
		var terms: PawnTermsDefinition = null if ticket == null else catalog.get_definition("pawn_terms", ticket.terms_id)
		return pawns.execute(day, ticket, terms, command)
	if command == "inquire":
		var target_item := InventoryManager.new().find(day.state, target)
		var item_def := null if target_item == null else catalog.get_definition("items", target_item.definition_id) as ItemDefinition
		return ProvenanceService.inquire(day, target_item, item_def)
	if command != "sell": return ActionResult.new(false, "未知库存/当票操作。")
	if not day.definition.market.is_empty(): return sell_batch(day, detail, [target])
	var item := InventoryManager.new().find(day.state, target)
	var buyer := catalog.get_definition("buyers", detail) as BuyerDefinition
	var error := sale_reason(day, item, buyer)
	if not error.is_empty(): return ActionResult.new(false, error)
	var price := quote(item, buyer)
	day.spend_action(buyer.action_minutes)
	if day.state.phase != &"open" or day.state.game_minutes >= buyer.window_end: return ActionResult.new(false, "交货耗时后错过买家窗口；货款未变动。")
	var profit := price - item.acquisition_price
	EconomyManager.new().commit(day.state, price, item.instance_id, "sale/" + item.instance_id, "sale", profit)
	item.ownership_state = "sold"
	day.state.sale_records.append({"item_instance_id": item.instance_id, "buyer_id": String(buyer.id), "night": day.state.current_night_index, "minute": day.state.game_minutes, "price": price, "cost_basis": item.acquisition_price, "realized_profit": profit})
	return ActionResult.new(true, "出售收银 %d；成本 %d，已实现盈亏 %+d。" % [price, item.acquisition_price, profit])

func item_reason(day: DayController, item: ItemInstance, buyer: BuyerDefinition) -> String:
	if item == null or buyer == null: return "物品或买家不存在。"
	if item.ownership_state != "owned": return "只有铺中自有现货可以出售。"
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	if definition.category not in buyer.categories or buyer.channel not in definition.sell_channels: return "此买家不收这类货。"
	if MarketService.is_special(day.definition, buyer) and definition.category != MarketService.category(day): return "不合陆掌眼眼下的收货偏好。"
	return ""

func trip_reason(day: DayController, buyer: BuyerDefinition) -> String:
	if buyer == null or buyer.id not in day.definition.buyer_ids: return "买家不存在。"
	for flag in buyer.required_flags:
		if flag not in day.state.narrative_flags: return "尚未取得买家介绍；请查看铺中记事。"
	if day.state.phase != &"open": return "开铺营业后才能交货。"
	if not day.state.risk_pending.is_empty() or not day.state.pending_event_id.is_empty() or MirrorEncounterService.new(catalog).pending(day): return "请先处理眼前的事情。"
	if not PawnReturnService.current(day.state).is_empty(): return "原当户还在店里，请先办妥当票。"
	for visit in day.state.visits:
		if visit.status in ["active", "waiting"]: return "店里还有客人，请先接待或送客，再去交货。"
	if day.state.current_night_index < buyer.night_min or day.state.current_night_index > buyer.night_max or day.state.game_minutes < buyer.window_start or day.state.game_minutes >= buyer.window_end: return "当前不在买家收货时段。"
	if day.state.game_minutes + buyer.action_minutes >= mini(buyer.window_end, day.definition.night_minutes): return "来不及在收货结束前往返20分钟。"
	return ""

func sell_batch(day: DayController, buyer_id: String, item_ids: Array) -> ActionResult:
	if day.definition.market.is_empty(): return ActionResult.new(false, "这局沿用逐件交货。")
	var buyer := catalog.get_definition("buyers", buyer_id) as BuyerDefinition
	var error := trip_reason(day, buyer)
	if not error.is_empty(): return ActionResult.new(false, error)
	if item_ids.is_empty(): return ActionResult.new(false, "请先选好要卖的货。")
	var rows: Array[Dictionary] = []
	var seen: Array = []
	var income := 0
	var cost := 0
	for id in item_ids:
		if not id is String or id in seen: return ActionResult.new(false, "货单有重复或无效货物，请重新选择。")
		seen.append(id)
		var item := InventoryManager.new().find(day.state, id)
		error = item_reason(day, item, buyer)
		if not error.is_empty(): return ActionResult.new(false, error)
		var price := quote(item, buyer)
		income += price
		cost += item.acquisition_price
		rows.append({"item_instance_id": id, "price": price, "cost_basis": item.acquisition_price, "realized_profit": price - item.acquisition_price})
	var start := day.state.game_minutes
	var market := MarketService.current(day.definition, day.state.run_seed, day.state.current_night_index, start)
	var batch_id := "batch/%d" % (day.state.sale_batches.size() + 1)
	# Everything that can reject is checked before time or money changes.
	var spent := day.spend_action(buyer.action_minutes)
	if not spent.ok: return spent
	for row in rows:
		var item := InventoryManager.new().find(day.state, row.item_instance_id)
		EconomyManager.new().commit(day.state, row.price, item.instance_id, "sale/" + item.instance_id, "sale", row.realized_profit)
		item.ownership_state = "sold"
		row.merge({"buyer_id": buyer_id, "night": day.state.current_night_index, "minute": day.state.game_minutes, "batch_id": batch_id})
		day.state.sale_records.append(row)
	day.state.sale_batches.append({"id": batch_id, "buyer_id": buyer_id, "item_ids": item_ids.duplicate(), "night": day.state.current_night_index, "start": start, "minute": day.state.game_minutes, "market_id": market.id})
	return ActionResult.new(true, "交货%d件，收银%d；成本%d，交易毛利%+d。往返20分钟。" % [rows.size(), income, cost, income - cost])
