extends "res://tests/gramophone_appraisal.gd"

func run() -> void:
	if not setup():quit(1);return
	for channel in ["single","batch"]:
		var s:=gramophone("original","clear","steady");var v:CustomerVisit=s._day.state.visits[0]
		var o:=GramophoneEconomy.owner(s._day.state,v);o.belief={"identity":"imitation","sound":"rasping","motor":"wavering"};o.rate=60
		GramophoneEconomy.reprice_initial(s._day.state,v)
		var cost:=v.trade.reserve_price;var rep:int=s._day.state.social.reputation
		check(s.counter_command("offer",v.visit_id,"",cost).ok and v.item.ownership_state=="owned","purchase underestimated old porcelain")
		check(s._day.state.social.reputation==rep,"cheap acquisition no reputation penalty")
		var buyer_id:=""
		for key in run_def.buyer_ids:
			if s._commerce.sale_reason(s._day,v.item,catalog.get_definition("buyers",key)).is_empty():buyer_id=key;break
		check(not buyer_id.is_empty(),"available porcelain buyer")
		if buyer_id.is_empty():continue
		var quote:=s._commerce.quote(v.item,catalog.get_definition("buyers",buyer_id));var before:=s._day.state.cash
		var result:ActionResult=s.commerce_command("sell",v.item.instance_id,buyer_id) if channel=="single" else s.sell_batch(buyer_id,[v.item.instance_id])
		check(result.ok and v.item.ownership_state=="sold","single and batch sale")
		check(s._day.state.cash==before+quote and s._day.state.ledger_entries.back().realized_profit==quote-cost,"actual revenue and realized profit")
	for redeem in [false,true]:
		var s:=gramophone("rebuilt","rasping","wavering","minor","customer_wealthy_antique","pawn");var v:CustomerVisit=s._day.state.visits[0]
		v.pawn_terms_id="sample_three_redeem" if redeem else "sample_three_default"
		var fixed:=v.item.goods.duplicate(true)
		check(s.counter_command("pawn",v.visit_id,"",v.trade.reserve_price).ok,"real porcelain loan")
		var ticket:=s._day.state.pawn_tickets.back() as PawnTicket
		check(ticket.due_night==7 and ticket.redemption_amount==ticket.principal+ceili(ticket.principal*.1),"three nights and 10 percent")
		for key in run_def.buyer_ids:check(not s._commerce.item_reason(s._day,v.item,catalog.get_definition("buyers",key)).is_empty(),"pledged item cannot sell")
		s._day.state.current_night_index=7;s._day.state.game_minutes=0
		if redeem:
			PawnReturnService.prepare(s._day.state,catalog);PawnReturnService.arrive(s._day.state)
			var before:=s._day.state.cash;check(s.counter_command("redeem",PawnReturnService.current(s._day.state).id).ok,"redeem visit")
			check(ticket.status=="redeemed" and s._day.state.cash==before+ticket.redemption_amount,"redemption amount independent of diagnosis")
		else:
			PawnController.new().resolve_maturities(s._day.state,run_def.night_minutes,catalog,{ticket.ticket_id:"keep"})
			check(ticket.status=="defaulted" and v.item.ownership_state=="owned","default enters stock")
			var display:=CustomerVisit.new();display.visit_id="display/porcelain";display.customer_id="customer_hawker";display.purpose="display_buyer";display.item=v.item;display.status="active";display.expires_at=100
			s._day.state.visits.clear();s._day.state.visits.append(display);s._day.state.shop_growth.display_id=v.item.instance_id
			s._day.state.shop_growth.opportunities.append({"night":7,"offer_factor":90,"cap_factor":110,"status":"scheduled","item_id":v.item.instance_id,"visit_id":display.visit_id})
			ShopGrowthService.activate(s._day.state,display)
			var offer:int=ShopGrowthService.opportunity(s._day.state).offer
			check(offer==roundi(fixed.gramophone_value.actual*.9),"display uses actual value after default")
			check(s.counter_command("display_accept",display.visit_id).ok and v.item.ownership_state=="sold","display sale completes")
		check(v.item.goods==fixed,"redemption default and display preserve facts")
	var poor:=gramophone();var visitor:CustomerVisit=poor._day.state.visits[0];poor._day.state.cash=0;var snapshot:=poor.read_state()
	check(not poor.counter_command("offer",visitor.visit_id,"",visitor.trade.reserve_price).ok and snapshot==poor.read_state(),"insufficient cash atomic")
	print("GRAMOPHONE ECONOMY: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)
