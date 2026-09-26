extends "res://tests/town_life_rules.gd"

func run() -> void:
	var loaded:=JsonContentProvider.new("res://data/town_life_manifest.json").load_catalog()
	check(loaded.is_success(),"integrated campaign content")
	if not loaded.is_success():quit(1);return
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog
	run_def._initial_cash=30000
	var s:=fresh_special(42);var professions:Dictionary={};var goods:Dictionary={};var wet_damage:=false;var pawned:=0;var delivered:=false
	print("CAMPAIGN targets=",SpecialGuests.data(s._day.state).targets)
	for n in range(1,21):
		driver.drain(s);talk(s)
		if n>=2 and not SocialRules.closed(s._day.state):
			var stock:=CoatProcurement.stock(s._day.state).filter(func(item:ItemInstance)->bool:return item.instance_id not in SpecialGuests.held_items(s._day.state))
			if stock.size()>=3 and not delivered:
				check(s.social_command("accept_contract").ok,"natural mixed contract")
				var detail:=JSON.stringify({"ids":stock.slice(0,3).map(func(item:ItemInstance)->String:return item.instance_id),"order":s._day.state.social.contract.number})
				check(s.social_command("deliver",detail).ok,"natural military delivery");delivered=true
			var sale:Array=[]
			for item in s._day.state.inventory_instances:
				if item.ownership_state!="owned" or item.definition_id=="item_weeping_mirror":continue
				if TownLife.clothing(s._day.state,item.definition_id) and item.instance_id not in SpecialGuests.held_items(s._day.state):continue
				if item.instance_id in SpecialGuests.held_items(s._day.state) and WetGoodsRisk.age(s._day.state,item)<6:continue
				if s._commerce.item_reason(s._day,item,catalog.get_definition("buyers",RecyclerPolicy.BUYER)).is_empty():sale.append(item.instance_id)
			if not sale.is_empty():check(s.sell_batch(RecyclerPolicy.BUYER,sale).ok,"natural preopen sale")
		act(s,"open_shop");driver.drain(s)
		for step in 220:
			var v:=s._counter.customers.active(s._day.state)
			if v==null:
				var returning:=PawnReturnService.current(s._day.state)
				if not returning.is_empty():
					check(s.counter_command(returning.command,returning.id).ok,"pawn return");continue
				if not s.bell_model().enabled:break
				s.bell_command("wait");driver.drain(s);continue
			if v.customer_id==MedicineStory.CUSTOMER:
				talk(s);v=s._counter.customers.active(s._day.state)
				if v==null or v.customer_id!=MedicineStory.CUSTOMER:continue
				check(s.counter_command("offer",v.visit_id,"",200).ok,"medicine funds")
			elif v.customer_id==GhostGuests.SWAP:
				check(s.counter_command("swap_reject",v.visit_id).ok,"decline swap")
			elif v.customer_id==GhostGuests.CLOSED:
				check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"closed bundle no inspection")
			elif v.night_policy in ["one_quote","wet_cloth"]:
				check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"special guest sale")
				if v.night_policy=="wet_cloth":print("WET PURCHASE ",v.item.definition_id," held=",SpecialGuests.held_items(s._day.state))
			elif v.customer_id in TownLife.PROFESSIONS or v.item.definition_id in TownLife.ITEMS or TownLife.clothing(s._day.state,v.item.definition_id):
				professions[v.customer_id]=true;goods[v.item.definition_id]=true
				if TownLife.repair_question(s._day.state,v,TownLife.REPAIR):check(s.counter_command("question",v.visit_id,TownLife.REPAIR).ok,"natural repair clue")
				if "pawn" in v.transaction_modes and (v.customer_id=="customer_musician" or "sell" not in v.transaction_modes):
					check(s.counter_command("pawn",v.visit_id,"medium",v.trade.asking_price).ok,"natural musician pawn");pawned+=1
				else:check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"natural town purchase")
			else:check(s.counter_command("reject",v.visit_id).ok,"decline other trade")
			driver.drain(s)
			if failures:break
		if s._day.state.phase==&"open":act(s,"close_shop")
		if s._day.state.phase==&"closed_processing":act(s,"wait_until_seal")
		for ticket in s.pawn_disposal_model():check(s.choose_pawn_disposal(ticket.id,"keep").ok,"keep matured collateral")
		act(s,"resolve_night");driver.drain(s)
		if not s._day.state.risk_pending.is_empty():s.risk_command("retreat",s._day.state.risk_pending)
		act(s,"enter_room");driver.drain(s);act(s,"sleep");driver.drain(s);act(s,"finish_sleep");driver.drain(s)
		wet_damage=wet_damage or s._day.state.personal_risk_history.any(func(row:Dictionary)->bool:return row.source==WetGoodsRisk.SOURCE and row.kind=="damage")
		if n in [6,15,20]:verify(s,"town transactions night "+str(n))
		act(s,"continue_run")
		if failures:break
	check(s._day.state.current_night_index==21,"twenty nights completed")
	for id in TownLife.PROFESSIONS:check(professions.has(id),"profession naturally traded "+id)
	check(pawned>0 and delivered,"natural pawn and military delivery")
	check(SpecialGuests.QUEST_FLAG in s._day.state.narrative_flags,"bundle quest eligibility integrated")
	print("CAMPAIGN wet history=",SpecialGuests.data(s._day.state).history.filter(func(row:Dictionary)->bool:return str(row).contains("wet")))
	check(wet_damage,"wet held for five nights has existing consequence")
	var payload:=SaveCodec.new().encode(s._day.state,48)
	check(not payload.shop_growth.town_life.origins.is_empty(),"soldier provenance serialized")
	var first: String=payload.shop_growth.town_life.origins.keys()[0]
	payload.shop_growth.town_life.origins[first].kind="forged"
	InvestigationSaveCodec.clear_cache();check(SaveCodec.new().decode(payload,run_def,48,catalog,true)==null,"forged secret rejected by replay")
	print("TOWN CAMPAIGN: %d passes, %d failures; goods=%s" % [passes,failures,goods.keys()]);quit(0 if failures==0 else 1)
