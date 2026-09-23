extends "res://tests/pearl_appraisal.gd"

func run() -> void:
	if not setup(): quit(1); return
	thresholds()
	pawns_and_sales()
	old_saves()
	print("PEARL ECONOMY: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)

func thresholds() -> void:
	for skill in ["expert","ordinary","novice"]:
		for tier in 3:
			for correct in [true,false]:
				for part in ["material","repair"]:
					var s:=pearl(); var v:CustomerVisit=s._day.state.visits[0]; var id:=v.item.instance_id
					check(s.fan_command("luxury_begin",id,"2").ok,"threshold apparatus")
					if tier>0:
						for i in (3 if tier==2 else 1): bead_action(s,{"op":"hole","index":i})
						for i in tier: bead_action(s,{"op":"compare","index":0,"other":i+1})
					PearlEconomy.owner(s._day.state,v).skill=skill
					var choice:String = ("none" if correct else "all") if part=="material" else ("intact" if correct else "altered")
					var chance:=PearlNegotiation.chance(s._day.state,v,part,choice)
					check(chance==(WatchNegotiation.TRUE_CHANCES if correct else WatchNegotiation.FALSE_CHANCES)[tier][["expert","ordinary","novice"].find(skill)],"all pearl belief thresholds")
					var d:=PearlNegotiation.data(s._day.state,v); d.rolls[part]=chance-1
					check(claim(s,{part:choice}).ok and d.responses.back().parts[part].accepted,"threshold accepts below probability")
	# Grouping and order cannot alter rolls or final prices.
	for personality in ["easy","careful","firm"]:
		var states:=[]
		for separate in [true,false]:
			var s:=pearl(); var v:CustomerVisit=s._day.state.visits[0]; var o:=PearlEconomy.owner(s._day.state,v)
			o.rate=100; o.urgent=false; o.belief={"material":"none","repair":"intact"}; PearlEconomy.reprice_initial(s._day.state,v); PearlNegotiation.prepare(s._day.state,v)
			var d:=PearlNegotiation.data(s._day.state,v); d.personality=personality
			for part in d.rolls: d.rolls[part]=0
			if separate:
				check(claim(s,{"repair":"altered"}).ok,"first issue"); check(claim(s,{"material":"some"}).ok,"second issue")
			else: check(claim(s,{"material":"some","repair":"altered"}).ok,"combined issue")
			states.append({"belief":d.belief,"rolls":d.rolls,"ask":v.trade.asking_price,"reserve":v.trade.reserve_price})
		check(states[0]==states[1],"order and grouping same final belief and price")
	var s:=pearl(); var v:CustomerVisit=s._day.state.visits[0]
	var rep:int=s._day.state.social.reputation
	v.trade.patience=1; check(s.counter_command("offer",v.visit_id,"",1).ok,"low refused quote")
	check(s._day.state.social.reputation==rep,"low quote exempt negative reward")

func pawns_and_sales() -> void:
	for cid in WealthyCustomers.NAMES:
		for redeem in [false,true]:
			var s:=pearl("mended","minor",false,cid,"pawn"); var v:CustomerVisit=s._day.state.visits[0]
			v.pawn_terms_id="sample_three_redeem" if redeem else "sample_three_default"
			var actual:int=v.item.goods.pearl_value.actual
			var n:=PearlNegotiation.data(s._day.state,v); n.personality="easy"; n.rolls.material=0
			check(claim(s,{"material":"all"}).ok,"pawn claim")
			var funding:int=WealthyCustomers.trade(s._day.state,v).funding
			check(v.trade.reserve_price>=funding,"holder funding preserved")
			var cost:=v.trade.reserve_price
			check(s.counter_command("pawn",v.visit_id,"",cost).ok,"pawn purchase")
			var ticket:PawnTicket=s._day.state.pawn_tickets.back()
			check(ticket.due_night==7 and ticket.redemption_amount==cost+ceili(cost*.1),"three-night fee")
			for buyer_id in run_def.buyer_ids: check(not s._commerce.item_reason(s._day,v.item,catalog.get_definition("buyers",buyer_id)).is_empty(),"unowned collateral cannot sell")
			s._day.state.current_night_index=7; s._day.state.game_minutes=0
			if redeem:
				PawnReturnService.prepare(s._day.state,catalog); PawnReturnService.arrive(s._day.state)
				check(s.counter_command("redeem",PawnReturnService.current(s._day.state).id).ok,"redemption")
			else:
				PawnController.new().resolve_maturities(s._day.state,run_def.night_minutes,catalog,{ticket.ticket_id:"keep"})
				check(ticket.status=="defaulted" and v.item.ownership_state=="owned","default becomes own stock")
				var display:=CustomerVisit.new(); display.visit_id="display/pearl"; display.purpose="display_buyer"; display.item=v.item
				s._day.state.shop_growth.opportunities.append({"night":7,"offer_factor":90,"cap_factor":110,"status":"scheduled"})
				ShopGrowthService.activate(s._day.state,display)
				check(ShopGrowthService.opportunity(s._day.state).offer==roundi(actual*.9),"display fixed valuation")
			check(v.item.goods.pearl_value.actual==actual,"pawn lifecycle actual unchanged")
	var s:=pearl("mended","major"); var v:CustomerVisit=s._day.state.visits[0]; var cost:=v.trade.reserve_price
	check(s.counter_command("offer",v.visit_id,"",cost).ok,"cash purchase")
	for buyer_id in run_def.buyer_ids:
		var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
		if not s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): continue
		var quote:=s._commerce.quote(v.item,buyer)
		check(s.commerce_command("sell",v.item.instance_id,buyer_id).ok,"inventory sale")
		check(s._day.state.ledger_entries.back().realized_profit==quote-cost,"realized profit actual proceeds")
		break
	s=pearl("flawed","minor"); v=s._day.state.visits[0]; cost=v.trade.reserve_price
	check(s.counter_command("offer",v.visit_id,"",cost).ok,"purchase for batch")
	for buyer_id in run_def.buyer_ids:
		var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
		if not s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): continue
		var quote:=s._commerce.quote(v.item,buyer)
		check(s.sell_batch(buyer_id,[v.item.instance_id]).ok,"batch sale")
		check(s._day.state.ledger_entries.back().realized_profit==quote-cost,"batch same valuation")
		break
	s=pearl(); v=s._day.state.visits[0]; s._day.state.cash=1; var before:=s.read_state()
	var rejected:=s.counter_command("offer",v.visit_id,"",v.trade.asking_price)
	check(not rejected.ok and s._day.state.cash==1 and s._day.state.game_minutes==0 and v.trade.offers.is_empty(),"cannot buy without principal")

func old_saves() -> void:
	var s:=second_night(); var library:=SaveLibrary.new("res://.godot/qa/pearl-library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/pearl_market_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,38,catalog),"v38 library write")
	InvestigationSaveCodec.clear_cache(); var restored:=library.read_entry("manual/1")
	check(not restored.is_empty() and restored.catalog.content_version==38,"v38 library read")
	for manifest in ["named_wealthy","watch_patterns","watch_negotiation","watch_market","watch","tiered","wealthy"]:
		var old:=JsonContentProvider.new("res://data/"+manifest+"_manifest.json").load_catalog()
		var definition:RunDefinition=old.catalog.get_definition("runs",old.catalog.default_run_id)
		var store:=CountingStore.new(); store.origin={"seed":609,"run_token":"0123456789abcdef0123456789abcdef"}
		var previous:=RunSession.new(definition,old.catalog.content_version,store,old.catalog)
		driver.catalog=old.catalog; driver.drain(previous)
		library.register_catalog("res://data/"+manifest+"_manifest.json",old.catalog)
		check(library.write_entry("manual/2",previous._day.state,definition,old.catalog.content_version,old.catalog),"legacy disk write "+manifest)
		InvestigationSaveCodec.clear_cache(); restored=library.read_entry("manual/2")
		check(not restored.is_empty(),"legacy disk read "+manifest)
		if not restored.is_empty():
			check(library.adopt(restored,s),"adopt legacy")
			check(not PearlEconomy.enabled(s.definition) and not LuxuryCarry.enabled(s.definition),"legacy rules frozen")
			s.new_run(); check(s.content_version==38,"new game returns v38")
