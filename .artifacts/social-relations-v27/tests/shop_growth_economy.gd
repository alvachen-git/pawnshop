extends "res://tests/shop_growth.gd"

func run() -> void:
	if not setup(): quit(1); return
	var results: Array = []
	for seed_value in 32:
		for strategy in ["none", "bench", "display", "both"]:
			results.append(simulate(seed_value, strategy))
		if seed_value % 8 == 7: print("ECONOMY seeds finished: ", seed_value + 1)
	var report := {"seeds": 32, "nights": 10, "policy": "All strategies hold first hairpin overnight. Observe then use available tool checks. Offer min(asking, floor(known midpoint * 0.85)) once and retain 110 silver for fees/upgrades; refuse if not accepted. Opening tutorial hairpin purchased at visible asking. One held item displayed when available; other stock sold at best currently available public quote. Accept display opening offer. Close after arrivals finish. No private item values or seller reserve used by policy.", "runs": results}
	var summaries := {}
	for strategy in ["none", "bench", "display", "both"]:
		var totals := {"runs": 0, "chances": 0, "buyers": 0, "sales": 0, "cash_change": 0, "sales_revenue": 0, "facility_spend": 0, "inventory_cost": 0, "peak_inventory_cost": 0, "missed": 0, "bankrupt": 0, "inspection_minutes": 0, "business_profit": 0}
		for row in results:
			if row.strategy != strategy: continue
			totals.runs += 1
			for key in totals:
				if key != "runs": totals[key] += row[key]
		summaries[strategy] = totals
	report["summary"] = summaries
	DirAccess.make_dir_recursive_absolute("res://docs/qa/shop-growth")
	FileAccess.open("res://docs/qa/shop-growth/economy.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SHOP GROWTH ECONOMY: %d passes, %d failures; %s" % [passes, failures, JSON.stringify(summaries)])
	quit(0 if failures == 0 else 1)

func simulate(seed_value: int, strategy: String) -> Dictionary:
	var s := fresh_growth(seed_value)
	s.replaying = true # Suppress presentation/IO while using the same public commands.
	var inspection := 0
	var peak_inventory_cost := 0
	for n in range(1, 11):
		driver.drain(s)
		if n == 2:
			if strategy in ["bench", "both"]: check(s.growth_command("build", "bench").ok, "experiment bench")
			if strategy in ["display", "both"]: check(s.growth_command("build", "display").ok, "experiment display")
		if s._day.state.shop_growth.display and s._day.state.shop_growth.display_id.is_empty():
			for item in s._day.state.inventory_instances:
				if ShopGrowthService.item_reason(s._day.state, item).is_empty(): s.growth_command("display", item.instance_id); break
		act(s, "open_shop"); driver.drain(s)
		for step in 200:
			var occupied := 0
			for held in s._day.state.inventory_instances:
				if held.ownership_state == "owned": occupied += held.acquisition_price
			peak_inventory_cost = maxi(peak_inventory_cost, occupied)
			if s._day.state.phase != &"open": break
			driver.drain(s)
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				sell_available(s, n)
				if s._counter.customers.active(s._day.state) != null: continue
				if not s.bell_model().enabled: break
				check(s.bell_command("wait").ok, "economic wait")
				continue
			if v.purpose == "display_buyer": s.counter_command("display_accept", v.visit_id); continue
			if not v.purpose.is_empty() or not v.night_policy.is_empty(): s.counter_command("reject", v.visit_id); continue
			var item := catalog.get_definition("items", v.item.definition_id) as ItemDefinition
			var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
			if item.item_type != "normal" or customer.guest_rule == "no_appraisal": s.counter_command("reject", v.visit_id); continue
			for action in item.appraisal_actions:
				if v.status != "active": break
				if s._counter.reason(s._day, "appraise", v.visit_id, action.id).is_empty():
					var start := s._day.state.game_minutes
					s.counter_command("appraise", v.visit_id, action.id)
					inspection += s._day.state.game_minutes - start
			if v.status != "active": continue
			var bounds := AppraisalSystem.new().valuation(v.item, item)
			var price := v.trade.asking_price if v.item.definition_id == "intro_silver_hairpin" else mini(v.trade.asking_price, floori((bounds.x + bounds.y) * 0.425))
			var buy := v.item.definition_id == "intro_silver_hairpin" or s._day.state.cash - price >= 110
			if buy and s._counter.reason(s._day, "offer", v.visit_id, "", price).is_empty(): s.counter_command("offer", v.visit_id, "", price)
			if v.status == "active": s.counter_command("reject", v.visit_id)
		if s._day.state.phase == &"open": sell_available(s, n)
		finish_night(s)
		if s._day.state.phase in [&"bankrupt", &"dead"]: break
	check(s._day.state.phase in [&"run_ended", &"bankrupt"], "ten night economic boundary")
	if seed_value == 0 and strategy == "both": fixture(s, "ending")
	var stats := {"seed": seed_value, "strategy": strategy, "cash_change": s._day.state.cash - 300, "sales_revenue": 0, "facility_spend": 0, "inventory_cost": 0, "inspection_minutes": inspection, "business_profit": 0, "chances": 0, "buyers": 0, "sales": 0, "missed": 0, "bankrupt": int(s._day.state.phase == &"bankrupt")}
	stats["peak_inventory_cost"] = peak_inventory_cost
	for row in s._day.state.shop_growth.opportunities:
		if not row.item_id.is_empty(): stats.chances += 1
		if row.arrives: stats.buyers += 1
		if row.status == "display_sold": stats.sales += 1
	for item in s._day.state.inventory_instances:
		if item.ownership_state == "owned": stats.inventory_cost += item.acquisition_price
	for row in s._day.state.visit_history:
		if row.outcome in ["timed_out", "shop_closed"] and not row.visit_id.ends_with("/display_buyer"): stats.missed += 1
	for row in s._day.state.ledger_entries:
		if row.kind == "sale": stats.sales_revenue += row.amount
		if row.kind == "facility_investment": stats.facility_spend -= row.amount
	for row in s._day.state.summaries: stats.business_profit += row.operating_profit
	return stats

func sell_available(s: RunSession, night: int) -> void:
	var stock: Array = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state == "owned" and i.instance_id != s._day.state.shop_growth.display_id and (night > 1 or i.definition_id != "intro_silver_hairpin"))
	for item in stock:
		var best := ""; var price := 0
		for buyer_id in s.definition.buyer_ids:
			var buyer := catalog.get_definition("buyers", buyer_id) as BuyerDefinition
			if s._commerce.sale_reason(s._day, item, buyer).is_empty() and s._commerce.quote(item, buyer) > price: price = s._commerce.quote(item, buyer); best = buyer_id
		if not best.is_empty(): s.sell_batch(best, [item.instance_id]); driver.drain(s)
