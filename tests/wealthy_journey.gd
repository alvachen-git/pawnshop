extends "res://tests/wealthy_customers.gd"

var met := 0
var appraised := 0
var funded := 0
var reclaimed := 0

func run() -> void:
	if not setup(): quit(1); return
	for seed_value in [222,444,609,834,1074]:
		journey(seed_value)
		if appraised > 0 and funded > 0 and reclaimed > 0: break
	check(met > 0,"naturally earned reputation brings wealthy customers")
	check(appraised > 0,"natural facility and knowledge lead to appraisal")
	check(funded > 0,"natural wealthy loan")
	check(reclaimed > 0,"natural wealthy redemption")
	print("WEALTHY JOURNEY: met=%d appraised=%d funded=%d redeemed=%d; %d passes, %d failures" % [met,appraised,funded,reclaimed,passes,failures])
	quit(0 if failures == 0 else 1)

func liquidate(s: RunSession) -> void:
	if s._day.state.phase != &"open" or ShopGrowthService.blocked(s._day): return
	for stock in s._day.state.inventory_instances.duplicate():
		if stock.ownership_state != "owned": continue
		var best := ""; var price := 0
		for id in run_def.buyer_ids:
			var buyer := catalog.get_definition("buyers",id) as BuyerDefinition
			if s._commerce.sale_reason(s._day,stock,buyer).is_empty() and s._commerce.quote(stock,buyer) > price:
				best = id; price = s._commerce.quote(stock,buyer)
		if not best.is_empty() and (price > stock.acquisition_price or s._day.state.cash < 20):
			check(s.commerce_command("sell",stock.instance_id,best).ok,"sell acquired stock through existing buyer")
			driver.drain(s)
			if s._day.state.phase != &"open" or ShopGrowthService.blocked(s._day): return

func journey(seed_value: int) -> void:
	var s := fresh_growth(seed_value)
	var captured := false
	for night in range(1,11):
		driver.drain(s); settle_social(s)
		if night >= 2:
			if not s._day.state.shop_growth.bench and s._day.state.cash >= 40: check(s.growth_command("build","bench").ok,"natural level one")
			elif int(s._day.state.shop_growth.appraisal.bench_due) == 0 and s._day.state.cash >= 80: check(s.growth_command("bench_two").ok,"natural level two commission")
			var topics: Array = []
			for visitor in s._day.state.visits:
				if WealthyCustomers.is_customer(visitor.customer_id): topics.append(LuxuryAppraisalService.info(s._day.state,visitor.item).topic)
			topics.append_array(["luxury_metal","luxury_watch","luxury_jade","luxury_textile","luxury_painting","luxury_porcelain"])
			for topic in topics:
				if ShopKnowledgeService.reason(s._day,topic).is_empty(): check(s.growth_command("learn_knowledge",topic).ok,"natural knowledge " + topic)
			if night == 2 and PreparationService.count(s._day.state) < 2 and s._day.state.cash >= 100: s.execute("prep_advertise")
		act(s,"open_shop"); driver.drain(s)
		for step in 160:
			if s._day.state.phase != &"open": break
			driver.drain(s)
			var returning := PawnReturnService.current(s._day.state)
			if not returning.is_empty():
				var wealthy := WealthyCustomers.is_customer(returning.customer_id)
				check(s.counter_command("redeem",returning.id).ok,"natural redemption")
				if wealthy: reclaimed += 1; verify(s,"wealthy redeemed")
				continue
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				liquidate(s)
				if s._day.state.phase == &"open": s.bell_command("wait")
				continue
			if WealthyCustomers.is_customer(v.customer_id):
				met += 1
				var book := LuxuryAppraisalService.info(s._day.state,v.item)
				if LuxuryAppraisalService.reason(s._day,"luxury_check",v.item.instance_id,"0").is_empty() and ShopKnowledgeService.mastered(s._day.state,book.topic) and s._day.state.game_minutes + 35 < v.expires_at:
					if not captured: fixture(s,"ready"); captured = true
					var before := s.read_state()
					(s._save as CountingStore).fail = true
					check(not s.fan_command("luxury_check",v.item.instance_id,"0").ok and before == s.read_state(),"inspection rollback preserves cash time and evidence")
					(s._save as CountingStore).fail = false
					v = s._counter.customers.active(s._day.state)
					for index in 2:
						check(s.fan_command("luxury_check",v.item.instance_id,str(index)).ok,"natural physical inspection")
						check(s.fan_command("luxury_match",v.item.instance_id,"%d/%s" % [index,LuxuryAppraisalService.expected_matches(v.item)[index]]).ok,"natural comparison")
					check(s.fan_command("luxury_identity",v.item.instance_id,book.identity[v.item.selected_variant_id]).ok,"natural identity draft")
					check(s.fan_command("luxury_condition",v.item.instance_id,book.condition[v.item.selected_variant_id]).ok,"natural condition draft")
					check(s.fan_command("luxury_commit",v.item.instance_id).ok,"natural appraisal commit")
					appraised += 1
					check(s.counter_command("luxury_pressure",v.visit_id).ok,"natural evidence negotiation")
					fixture(s,"appraised")
				var amount := v.trade.reserve_price
				if amount <= s._day.state.cash - 20:
					var pawn := "pawn" in v.transaction_modes
					check(s.counter_command("pawn" if pawn else "offer",v.visit_id,"",amount).ok,"natural wealthy acquisition")
					if pawn: funded += 1
					verify(s,"wealthy acquired")
				else: check(s.counter_command("reject",v.visit_id).ok,"decline unaffordable wealthy offer")
			else:
				var customer := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
				if customer.guest_rule == "swap":
					check(s.counter_command("swap_reject",v.visit_id).ok,"decline ghost exchange")
					continue
				var item := catalog.get_definition("items",v.item.definition_id) as ItemDefinition
				var safe := item.item_type == "normal" and v.purpose.is_empty() and "sell" in v.transaction_modes and v.night_policy.is_empty() and item.id != GoodsExpertise.FAN
				if safe and item.id != "intro_silver_hairpin":
					for inspection in item.appraisal_actions:
						if s._day.state.game_minutes + 20 >= v.expires_at: break
						if s._counter.reason(s._day,"appraise",v.visit_id,inspection.id).is_empty(): s.counter_command("appraise",v.visit_id,inspection.id)
					for clue_id in v.item.revealed_clue_ids:
						if v.trade.rounds_left <= 1: break
						if item.find_clue(clue_id).leverage > 0 and s._counter.reason(s._day,"pressure",v.visit_id,clue_id).is_empty(): s.counter_command("pressure",v.visit_id,clue_id)
					if v.status != "active": continue
				var amount := maxi(v.trade.reserve_price,ceili(ReputationService.basis(s._day.state,v)*(1.2 if s._day.state.social.reputation < 5 else .85)))
				if v.item.definition_id == "intro_silver_hairpin": safe = true; amount = v.trade.reserve_price
				var reserve_cash := 160 if night == 1 else 110 if night == 2 else 40
				if safe and amount <= s._day.state.cash-reserve_cash: check(s.counter_command("offer",v.visit_id,"",amount).ok,"real reputation-building purchase")
				else: check(s.counter_command("reject",v.visit_id).ok,"decline ordinary goods")
			driver.drain(s)
			liquidate(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		finish_night(s)
		if s._day.state.phase in [&"dead",&"bankrupt"]: break
	verify(s,"full run seed %d" % seed_value)
	print("JOURNEY seed=%d cash=%d reputation=%d phase=%s met=%d appraised=%d funded=%d redeemed=%d" % [seed_value,s._day.state.cash,s._day.state.social.reputation,s._day.state.phase,met,appraised,funded,reclaimed])

func finish_night(s: RunSession) -> void:
	driver.drain(s)
	if s._day.state.phase == &"open": act(s,"close_shop")
	if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
	for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id,"keep")
	act(s,"resolve_night"); driver.drain(s)
	if s._day.state.phase in [&"dead",&"bankrupt"]: return
	act(s,"enter_room"); driver.drain(s)
	act(s,"sleep"); driver.drain(s)
	act(s,"finish_sleep")
	if s._day.state.phase == &"day_summary": act(s,"continue_run")
