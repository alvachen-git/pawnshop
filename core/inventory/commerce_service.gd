class_name CommerceService
extends RefCounted

var catalog: ContentCatalog
var pawns := PawnController.new()

func _init(content: ContentCatalog) -> void:
	catalog = content

func quote(item: ItemInstance, buyer: BuyerDefinition) -> int:
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	return maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))

func sale_reason(day: DayController, item: ItemInstance, buyer: BuyerDefinition) -> String:
	if item == null or buyer == null or buyer.id not in day.definition.buyer_ids: return "物品或买家机会不存在。"
	if item.ownership_state != "owned": return "只有店铺所有的现货可出售；在当物品不可出售。"
	if day.state.phase != &"open": return "买家只在营业时收货。"
	if day.state.current_night_index < buyer.night_min or day.state.current_night_index > buyer.night_max or day.state.game_minutes < buyer.window_start or day.state.game_minutes >= buyer.window_end: return "当前不在买家到访窗口。"
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	if definition.category not in buyer.categories or buyer.channel not in definition.sell_channels: return "此买家不收这类货。"
	var count := 0
	for sale in day.state.sale_records:
		if sale.buyer_id == buyer.id and sale.night == day.state.current_night_index: count += 1
	if count >= buyer.capacity_per_night: return "此买家今夜额度已用完。"
	if not TimeController.new().can_spend(day.state, day.definition, buyer.action_minutes): return "时间不足。"
	return ""

func execute(day: DayController, command: String, target: String, detail: String) -> ActionResult:
	if command in ["redeem", "extend"]:
		var ticket := pawns.find(day.state, target)
		var terms: PawnTermsDefinition = null if ticket == null else catalog.get_definition("pawn_terms", ticket.terms_id)
		return pawns.execute(day, ticket, terms, command)
	if command != "sell": return ActionResult.new(false, "未知库存/当票操作。")
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
