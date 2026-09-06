class_name BatchSaleReadModel
extends RefCounted

static func build(day: DayController, service: CommerceService) -> Dictionary:
	var buyers: Array = []
	var categories := {"porcelain": "瓷器", "metal": "金属器", "jewelry": "首饰", "watches": "钟表", "stationery": "文房", "textile": "绣品", "ghost": "鬼货"}
	var market := MarketService.current(day.definition, day.state.run_seed, day.state.current_night_index, day.state.game_minutes)
	var demand := MarketService.demand(day.definition, market)
	for id in day.definition.buyer_ids:
		var buyer := service.catalog.get_definition("buyers", id) as BuyerDefinition
		var special := MarketService.is_special(day.definition, buyer)
		var wanted: Array = [demand.name] if special else buyer.categories.map(func(key: String) -> String: return categories.get(key, key))
		var reason := service.trip_reason(day, buyer)
		var unlocked := CounterDomainValidator._contains_all(day.state.narrative_flags, buyer.required_flags)
		var stock: Array = []
		for item in day.state.inventory_instances:
			if item.ownership_state != "owned": continue
			var definition := service.catalog.get_definition("items", item.definition_id) as ItemDefinition
			var item_error := service.item_reason(day, item, buyer)
			if not unlocked: item_error = "取得介绍后才能询价。"
			var price := service.quote(item, buyer) if item_error.is_empty() else 0
			var base := maxi(1, roundi(definition.find_variant(item.selected_variant_id).true_value * buyer.value_multiplier))
			stock.append({"id": item.instance_id, "name": definition.display_name, "cost": item.acquisition_price, "price": price,
				"premium": ProvenanceService.premium(item, buyer, base) if item_error.is_empty() else 0, "reason": item_error})
		buyers.append({"id": id, "name": buyer.display_name, "wanted": "、".join(wanted), "reason": reason, "stock": stock,
			"window": "%s–%s" % [TimeController.clock_text(day.definition.opening_minute, buyer.window_start), TimeController.clock_text(day.definition.opening_minute, buyer.window_end)],
			"note": demand.body if special else "按实物品相报价，收货件数不限。"})
	return {"buyers": buyers, "history": MarketService.history_text(day), "clock": TimeController.clock_text(day.definition.opening_minute, day.state.game_minutes),
		"return_clock": TimeController.clock_text(day.definition.opening_minute, day.state.game_minutes + 20), "market_id": market.id, "run_token": day.state.run_token}
