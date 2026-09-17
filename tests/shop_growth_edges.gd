extends "res://tests/shop_growth.gd"

func run() -> void:
	if not setup(): quit(1); return
	var chosen := 0
	while VarietyService.rng(chosen, "growth/2/chance").randi_range(0, 99) >= 40: chosen += 1
	# Full public transactions: failed persistence rolls back every alias and notification.
	for mode in ["display", "withdraw", "explore", "accept", "counter"]:
		var s := buyer_session(chosen) if mode in ["accept", "counter", "withdraw"] else second_night(chosen)
		if mode == "display": s.growth_command("build", "display")
		if mode == "explore": act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
		var before := s.read_state()
		var before_visits := visits_data(s)
		var notifications: Array = []
		s.transaction_completed.connect(func(row: Dictionary) -> void: notifications.append(row))
		s._save.fail = true
		var result: ActionResult
		match mode:
			"display": result = s.growth_command("display", s._day.state.inventory_instances[0].instance_id)
			"withdraw": result = s.growth_command("withdraw")
			"explore": result = s.growth_command("explore", "0")
			"accept": result = s.counter_command("display_accept", s._counter.customers.active(s._day.state).visit_id)
			"counter": result = s.counter_command("display_counter", s._counter.customers.active(s._day.state).visit_id, "", ShopGrowthService.opportunity(s._day.state).cap + 1)
		check(not result.ok and result.message.contains("恢复原状"), "rollback reports " + mode)
		check(s.read_state() == before and visits_data(s) == before_visits, "rollback cash, items, quote, queue, clock, journal " + mode)
		check(notifications.is_empty(), "no false receipt " + mode)
		if mode in ["accept", "counter", "withdraw"]:
			check(s._counter.customers.active(s._day.state).item == s._day.state.inventory_instances[0], "snapshot preserves stock alias " + mode)
		verify(s, "rolled back " + mode)
	# Concrete queue conflicts without substituting any base seat.
	var s := buyer_session(chosen)
	var v := s._counter.customers.active(s._day.state)
	var waiting := CustomerVisit.new(); waiting.visit_id = "test/husband"; waiting.customer_id = "mirror_husband"; waiting.purpose = "husband_meeting"; waiting.person = {"id": "mirror/husband"}; waiting.arrival = s._day.state.game_minutes; waiting.expires_at = s._day.state.game_minutes + 5; waiting.status = "waiting"
	s._day.state.visits.append(waiting)
	check(s.counter_command("display_accept", v.visit_id).ok, "buyer and husband queue")
	check(waiting.status == "timed_out", "other waiting clocks advance during sale")
	s = buyer_session(chosen); v = s._counter.customers.active(s._day.state)
	for kind in ["event", "risk", "return"]:
		var before := s.read_state()
		if kind == "event": s._day.state.pending_event_id = "forced"
		elif kind == "risk": s._day.state.risk_pending = v.item.instance_id
		else:
			s._day.state.pawn_returns.append({"id": "test/return", "night": 2, "status": "waiting", "ticket_id": "test/ticket", "arrival": 0})
		var reason := ShopGrowthService.trade_reason(s._day, "display_accept", v.visit_id)
		check(not reason.is_empty(), "forced priority " + kind)
		s._day.state.pending_event_id = ""; s._day.state.risk_pending = ""; s._day.state.pawn_returns.clear()
		check(s.read_state() == before, "no trade when blocked " + kind)
	# Existing sale channel cancels the locked target without substituting a new item.
	s = second_night(chosen); s.growth_command("build", "display")
	var item := s._day.state.inventory_instances[0]
	s.growth_command("display", item.instance_id); act(s, "open_shop"); driver.drain(s)
	for loop in 20:
		v = s._counter.customers.active(s._day.state)
		if v == null: break
		s.counter_command("reject", v.visit_id); driver.drain(s)
	check(s.sell_batch("buyer_recycler", [item.instance_id]).ok, "sell displayed stock by old channel")
	check(s._day.state.shop_growth.display_id.is_empty() and ShopGrowthService.opportunity(s._day.state).status == "display_cancelled", "other sale cancels chance")
	check(s._day.state.sale_records.size() == 1, "other sale single ownership transfer")
	verify(s, "other-channel sale")
	# Unreviewed fan uses the established base; verified provenance uses the common 15% rule.
	s = buyer_session(chosen); v = s._counter.customers.active(s._day.state)
	var row := ShopGrowthService.opportunity(s._day.state)
	v.item.definition_id = GoodsExpertise.FAN
	var fan := catalog.get_definition("items", GoodsExpertise.FAN) as ItemDefinition
	v.item.selected_variant_id = fan.possible_variants[0].id; v.item.expert_reviewed = false; v.item.provenance = {"status": "verified"}
	row.erase("offer"); ShopGrowthService.activate(s._day.state, v)
	var base := maxi(1, roundi(20 * int(row.offer_factor) / 100.0))
	check(row.offer == base + floori(base * 0.15), "fan 20 base with 15 percent known source")
	var frozen: int = row.offer
	v.item.expert_reviewed = true; v.item.provenance.status = "unchecked"
	ShopGrowthService.activate(s._day.state, v)
	check(row.offer == frozen, "price never changes after actual reception")
	# Default chance: exactly reproducible with independent arrival/offer/cap keys.
	var arrived := 0; var times := {}; var offers := {}; var caps := {}
	for seed_value in 1000:
		if VarietyService.rng(seed_value, "growth/2/chance").randi_range(0, 99) < 40: arrived += 1
		times[VarietyService.pick([60, 120, 180], seed_value, "growth/2/arrival")] = true
		offers[VarietyService.pick([90, 100, 110], seed_value, "growth/2/offer")] = true
		caps[VarietyService.pick([110, 120, 130], seed_value, "growth/2/cap")] = true
	check(arrived >= 340 and arrived <= 460 and times.size() == 3 and offers.size() == 3 and caps.size() == 3, "seeded distribution supports all proposed values")
	# A whole ten-night run may ignore the cabinet or stop at either partial stage.
	for progress in [0, 1, 2]:
		s = fresh_growth()
		for n in range(1, 11):
			driver.drain(s); act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
			if n == 2:
				for stage in progress: check(s.growth_command("explore", str(stage)).ok, "optional exploration " + str(stage))
			finish_night(s)
		check(s._day.state.phase == &"run_ended" and s._day.state.shop_growth.exploration.size() == progress, "ten night keeps actual unresolved stage " + str(progress))
		verify(s, "unresolved ten night " + str(progress))
	# The upgraded table does not defeat an inspection ban or a customer's deadline.
	s = second_night(); s.growth_command("build", "bench"); act(s, "open_shop"); driver.drain(s)
	if s._counter.customers.active(s._day.state) == null: s.bell_command("wait"); driver.drain(s)
	v = s._counter.customers.active(s._day.state)
	var ordinary: ItemDefinition
	for candidate in catalog.get_all("items"):
		if candidate.item_type == "normal" and candidate.appraisal_actions.any(func(a: AppraisalActionDefinition) -> bool: return a.minutes == 10): ordinary = candidate; break
	v.item.definition_id = ordinary.id; v.item.selected_variant_id = ordinary.possible_variants[0].id; v.scenario_id = ""; v.item.completed_action_ids.clear(); v.item.revealed_clue_ids.clear()
	for clue in ordinary.clues: v.item.revealed_clue_ids.append(clue.id)
	var tool_action: AppraisalActionDefinition
	for a in ordinary.appraisal_actions:
		if a.minutes == 10: tool_action = a; break
	var before_visit := RunSnapshot.copy(s._day.state)
	v.customer_id = GhostGuests.CLOSED
	var minutes := s._day.state.game_minutes
	check(s.counter_command("appraise", v.visit_id, tool_action.id).ok and v.status == "inspection_refused" and v.item.completed_action_ids.is_empty(), "inspection taboo retained")
	check(s._day.state.game_minutes == minutes + 5, "forbidden check still spends effective time")
	s._day.state = RunSnapshot.copy(before_visit); v = s._counter.customers.active(s._day.state)
	v.expires_at = s._day.state.game_minutes + 5
	check(not s.counter_command("appraise", v.visit_id, tool_action.id).ok and v.status == "timed_out" and v.item.completed_action_ids.is_empty(), "inspection at deadline gives no evidence")
	s._day.state = RunSnapshot.copy(before_visit); v = s._counter.customers.active(s._day.state)
	s._day.state.game_minutes = 535; v.expires_at = 600
	check(not s.counter_command("appraise", v.visit_id, tool_action.id).ok and s._day.state.game_minutes == 540, "03 seal still interrupts ordinary checking")
	print("SHOP GROWTH EDGES: %d passes, %d failures; 1000 seeded chances: %d arrivals" % [passes, failures, arrived])
	quit(0 if failures == 0 else 1)

func visits_data(s: RunSession) -> Array:
	return s._day.state.visits.map(func(v: CustomerVisit) -> Array: return [v.visit_id, v.status, v.arrival, v.expires_at, v.item.to_data() if v.item != null else null])
