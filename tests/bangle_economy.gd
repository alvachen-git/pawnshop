extends "res://tests/bangle_appraisal.gd"
func run() -> void:
	if not setup(): quit(1); return
	pawns_and_sales()
	print("BANGLE ECONOMY: %d passes, %d failures" % [passes,failures]); quit(0 if failures==0 else 1)

func pawns_and_sales() -> void:
	for cid in WealthyCustomers.NAMES:
		for redeem in [false,true]:
			var s:=bangle("lower","altered","minor",false,cid,"pawn"); var v:CustomerVisit=s._day.state.visits[0]
			v.pawn_terms_id="sample_three_redeem" if redeem else "sample_three_default"
			var actual:int=v.item.goods.bangle_value.actual
			var n:=BangleNegotiation.data(s._day.state,v); n.personality="easy"; n.rolls.material=0
			check(bc(s,{"material":"plated"}).ok,"pawn claim")
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
			check(v.item.goods.bangle_value.actual==actual,"pawn lifecycle actual unchanged")
	var s:=bangle("lower","altered","major"); var v:CustomerVisit=s._day.state.visits[0]; var cost:=v.trade.reserve_price
	check(s.counter_command("offer",v.visit_id,"",cost).ok,"cash purchase")
	for buyer_id in run_def.buyer_ids:
		var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
		if not s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): continue
		var quote:=s._commerce.quote(v.item,buyer)
		check(s.commerce_command("sell",v.item.instance_id,buyer_id).ok,"inventory sale")
		check(s._day.state.ledger_entries.back().realized_profit==quote-cost,"realized profit actual proceeds")
		break
	s=bangle("plated","intact","minor"); v=s._day.state.visits[0]; cost=v.trade.reserve_price
	check(s.counter_command("offer",v.visit_id,"",cost).ok,"purchase for batch")
	for buyer_id in run_def.buyer_ids:
		var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
		if not s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): continue
		var quote:=s._commerce.quote(v.item,buyer)
		check(s.sell_batch(buyer_id,[v.item.instance_id]).ok,"batch sale")
		check(s._day.state.ledger_entries.back().realized_profit==quote-cost,"batch same valuation")
		break
	s=bangle(); v=s._day.state.visits[0]; s._day.state.cash=1; var before:=s.read_state()
	var rejected:=s.counter_command("offer",v.visit_id,"",v.trade.asking_price)
	check(not rejected.ok and s._day.state.cash==1 and s._day.state.game_minutes==0 and v.trade.offers.is_empty(),"cannot buy without principal")
