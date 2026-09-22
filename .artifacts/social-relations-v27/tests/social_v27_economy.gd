extends "res://tests/social_v27.gd"

func run() -> void:
	if not setup(): quit(1); return
	var rows: Array = []
	for seed_value in [1,2,3,5,8,13,21,34,42,55,89,144]:
		for threats in [false,true]:
			rows.append(simulate(seed_value,threats))
	DirAccess.make_dir_recursive_absolute("res://docs/v27")
	FileAccess.open("res://docs/v27/economy.json",FileAccess.WRITE).store_string(JSON.stringify({"method":"12 matched seeds, 10 nights; same gifts until plaque, buy only profitable ordinary goods at hidden reserve for controlled economy comparison; retain coats for orders; refuse occult objects; no claim of human playtest balance", "runs":rows},"  "))
	print("V27 ECONOMY: %d runs, %d passes, %d failures" % [rows.size(),passes,failures])
	quit(0 if failures == 0 else 1)

func handle_pending(s: RunSession) -> void:
	driver.drain(s)
	var p: Dictionary = s._day.state.social.pending
	if p.is_empty(): return
	match p.kind:
		"supply": s.social_command("decline_supply")
		"fee": s.social_command("pay" if s._day.state.cash >= int(p.cost) else "refuse")
		"closure": s.social_command("pay" if s._day.state.cash >= int(p.cost) else "close")
		"claim": s.social_command("claim_return" if MilitaryService.reason(s._day,"claim_return").is_empty() else "claim_later")

func do_orders(s: RunSession) -> void:
	if not s._day.state.social.introduced: return
	if s._day.state.social.contract.is_empty() and MilitaryService.reason(s._day,"accept_contract").is_empty(): s.social_command("accept_contract")
	if s._day.state.social.contract.is_empty(): return
	var stock := CoatProcurement.stock(s._day.state)
	if stock.size() < 3: return
	var ids: Array = stock.slice(0,3).map(func(item: ItemInstance) -> String: return item.instance_id)
	var detail := detail_for(s,ids)
	if MilitaryService.reason(s._day,"deliver",detail).is_empty():
		check(s.social_command("deliver",detail).ok,"simulation delivery")
		s.social_command("accept_contract")

func sell_surplus(s: RunSession) -> void:
	for buyer_id in ["buyer_lu","buyer_collector","buyer_silversmith","buyer_recycler"]:
		var buyer := catalog.get_definition("buyers",buyer_id) as BuyerDefinition
		if buyer_id not in s.definition.buyer_ids or not s._commerce.trip_reason(s._day,buyer).is_empty(): continue
		var ids: Array = []
		for item in s._day.state.inventory_instances:
			if item.definition_id == CoatProcurement.ITEM or not s._commerce.item_reason(s._day,item,buyer).is_empty(): continue
			if s._commerce.quote(item,buyer) >= item.acquisition_price: ids.append(item.instance_id)
		if not ids.is_empty(): check(s.sell_batch(buyer_id,ids).ok,"simulation resale")

func simulate(seed_value: int, threats: bool) -> Dictionary:
	var s := fresh_growth(seed_value)
	var nights: Array = []
	for n in range(1,11):
		handle_pending(s)
		if s._day.state.phase in [&"bankrupt",&"dead",&"run_ended"]: break
		check(s._day.state.current_night_index == n,"simulation advances one night")
		if not s._day.state.social.plaque_awarded and MilitaryService.reason(s._day,"gift").is_empty(): s.social_command("gift")
		do_orders(s)
		if s.can_execute("open_shop"): s.execute("open_shop")
		driver.drain(s)
		var offered_coats := s._day.state.visits.filter(func(v: CustomerVisit) -> bool: return v.item != null and v.item.definition_id == CoatProcurement.ITEM).size()
		var visitors := s._day.state.visits.filter(func(v: CustomerVisit) -> bool: return ReputationService.eligible(s._day.state,v)).size()
		for step in 180:
			driver.drain(s)
			var returning := PawnReturnService.current(s._day.state)
			if not returning.is_empty():
				s.counter_command("redeem",returning.id); continue
			if s._day.state.phase != &"open" or s._day.state.game_minutes >= 455: break
			do_orders(s)
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				sell_surplus(s)
				s.bell_command("wait")
				continue
			var item := catalog.get_definition("items",v.item.definition_id) as ItemDefinition
			if item.item_type != "normal" or v.purpose != "" or not v.night_policy.is_empty():
				s.counter_command("reject",v.visit_id); continue
			var modes: Array = v.transaction_modes
			if "sell" not in modes:
				s.counter_command("reject",v.visit_id); continue
			if threats and MilitaryPlaque.reason(s._day.state,v).is_empty(): s.counter_command("intimidate",v.visit_id)
			var ceiling := 16 if v.item.definition_id == CoatProcurement.ITEM else 0
			for id in s.definition.buyer_ids:
				var buyer := catalog.get_definition("buyers",id) as BuyerDefinition
				if item.category in buyer.categories and buyer.night_min <= n and buyer.night_max >= n and buyer.required_flags.all(func(flag: String)->bool:return flag in s._day.state.narrative_flags):
					ceiling = maxi(ceiling,s._commerce.quote(v.item,buyer))
			if v.trade.reserve_price <= ceiling and s._day.state.cash >= v.trade.reserve_price and s._counter.reason(s._day,"offer",v.visit_id,"",v.trade.reserve_price).is_empty():
				s.counter_command("offer",v.visit_id,"",v.trade.reserve_price)
			else: s.counter_command("reject",v.visit_id)
		driver.drain(s); do_orders(s); sell_surplus(s)
		if s.can_execute("close_shop"): s.execute("close_shop")
		if s.can_execute("wait_until_seal"): s.execute("wait_until_seal")
		for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id,"keep")
		if s.can_execute("resolve_night"): s.execute("resolve_night")
		nights.append({"night":n,"coats_offered":offered_coats,"ordinary_visitors":visitors,"orders_total":s._day.state.social.contracts.filter(func(row:Dictionary)->bool:return row.result=="completed").size(),"cash":s._day.state.cash,"reputation":s._day.state.social.reputation,"military":s._day.state.social.military,"plaque":s._day.state.social.plaque_awarded,"threats_total":s._day.state.social.intimidations.size(),"phase":s._day.state.phase})
		if s._day.state.phase in [&"bankrupt",&"dead",&"run_ended"]: break
		for command in ["enter_room","sleep","finish_sleep","continue_run"]:
			driver.drain(s)
			if s.can_execute(command): s.execute(command)
			else: break
	if seed_value == 42: verify(s,"economy end " + str(threats))
	return {"seed":seed_value,"intimidation":threats,"nights":nights,"final_phase":s._day.state.phase}
