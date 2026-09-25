extends "res://tests/pawn_interest.gd"

func restore_payload(payload: Dictionary) -> RunSession:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(payload, run_def, 45, catalog, true)
	check(restored != null, "cold contract history " + codec.error_message)
	var s := fresh_growth()
	if restored != null: s._day.state = restored
	return s

func saved_quotes() -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/pawn-v45/pawn-visit.json"))
	for tier in ["low", "medium", "high"]:
		var s := restore_payload(payload)
		var v := s._counter.customers.active(s._day.state)
		var asking: int = s.counter_model().trade.pawn_asking
		var before := s.read_state()
		(s._save as CountingStore).fail = true
		check(not s.counter_command("pawn", v.visit_id, tier, asking).ok and s.read_state() == before, "rollback completed or refused " + tier)
		(s._save as CountingStore).fail = false
		check(s.counter_command("pawn", v.visit_id, tier, asking).ok, "formal quote " + tier)
		s = restore_payload(SaveCodec.new().encode(s._day.state, 45))
		if tier == "high":
			v = s._counter.customers.active(s._day.state)
			check(v != null and PawnInterestPolicy.high_recorded(s._day.state, v.visit_id), "saved first high refusal")
			var rep: int = s._day.state.social.reputation
			check(s.counter_command("pawn", v.visit_id, "high", asking).ok and s._day.state.social.reputation == rep, "reload high does not double penalize")
			check(s.counter_command("pawn", v.visit_id, "low", asking).ok, "reload high then low")
			check(not s._day.state.social.trades.any(func(row: Dictionary) -> bool: return row.mode == "pawn_interest" and row.outcome == "low_completed"), "history suppresses low reward")
			verify(s, "high then low")
		else:
			var ticket := s._day.state.pawn_tickets[0]
			var customer := catalog.get_definition("customers", ticket.customer_id) as CustomerDefinition
			check(ticket.terms_id == PawnInterestPolicy.terms_id(s._day.state, v, customer, tier), "same saved redemption roll " + tier)
		var corrupt := SaveCodec.new().encode(s._day.state, 45)
		corrupt.pawn_tickets[0].terms_id = "sample_three_default" if corrupt.pawn_tickets[0].terms_id == "sample_three_redeem" else "sample_three_redeem"
		InvestigationSaveCodec.clear_cache()
		check(SaveCodec.new().decode(corrupt, run_def, 45, catalog, true) == null, "forged redemption result rejected")
	check(PawnInterestPolicy.chance(0, "high") == 0 and PawnInterestPolicy.chance(100, "low") == 100, "probability bounds")

func seamstress_journey(tier: String, fund_silk: bool, transfer := false) -> void:
	var chosen := -1
	for seed_value in range(1, 129):
		var story := FamiliarStories.story_for({"familiar_plan": FamiliarStories.plan(run_def, catalog, seed_value)}, "seamstress")
		if not story.is_empty() and story.funds == 30 and story.first_night == 3:
			chosen = seed_value; break
	check(chosen >= 0, "Jiang seed with 30 funds and third night arrival")
	if chosen < 0: return
	var s := fresh_growth(chosen)
	var early_seen := false
	var loan_seen := false
	for night in range(1, 7):
		driver.drain(s); act(s, "open_shop"); driver.drain(s)
		var returning := PawnReturnService.current(s._day.state)
		while not returning.is_empty():
			var cash := s._day.state.cash
			var ticket := EarlyRedemption.ticket_for(s._day.state)
			check(s.counter_command(returning.command, returning.id).ok, "Jiang due return")
			check(s._day.state.cash == cash + ticket.redemption_amount, "actual due funds")
			returning = PawnReturnService.current(s._day.state)
		for guard in 120:
			if s._day.state.game_minutes >= 470: break
			driver.drain(s)
			var v := s._counter.customers.active(s._day.state)
			if v == null: act(s, "short_task"); continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if row.get("familiar_id") != "seamstress":
				var visitor := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
				var rejection := s.counter_command("swap_reject" if visitor.guest_rule == "swap" else "reject", v.visit_id)
				check(rejection.ok, "clear visitor %s night%d: %s" % [tier, night, rejection.message])
				if not rejection.ok: return
				continue
			if row.familiar_stage == "first":
				check(not PawnInterestPolicy.refuses_high(s._day.state, v), "Jiang flexible and urgent")
				check(s.counter_command("pawn", v.visit_id, tier, 27).ok, "Jiang loan " + tier)
				var ticket := EarlyRedemption.ticket_for(s._day.state)
				check(ticket != null and ticket.terms_id == FamiliarStories.TERMS and ticket.interest_tier == tier, "funded contract unaffected by chance")
				verify(s, "Jiang ticket " + tier)
				loan_seen = true
			elif EarlyRedemption.is_visit(v):
				early_seen = true
				var ticket := EarlyRedemption.ticket_for(s._day.state)
				var before := s.read_state()
				(s._save as CountingStore).fail = true
				check(not s.counter_command("early_redeem", v.visit_id).ok and s.read_state() == before, "early redemption save failure rolls back")
				(s._save as CountingStore).fail = false
				check(s.counter_command("early_redeem", v.visit_id).ok and s._day.state.cash == before.cash + ticket.redemption_amount, "full early payment " + tier)
				ticket = EarlyRedemption.ticket_for(s._day.state)
				check(ticket.closed_night < ticket.due_night, "actually early")
				verify(s, "Jiang early " + tier)
			else:
				check(tier == "high" and v.item.definition_id == "item_silk_panel", "33 owed exceeds 30 so she sells silk")
				check(s.counter_command("offer" if fund_silk else "reject", v.visit_id, "", v.trade.asking_price if fund_silk else 0).ok, "silk funding choice")
		if transfer and night == 6:
			act(s, "close_shop"); act(s, "wait_until_seal")
			var due := EarlyRedemption.ticket_for(s._day.state)
			check(s.choose_pawn_disposal(due.ticket_id, "transfer").ok, "natural transfer selected")
			act(s, "resolve_night")
		else: finish_night(s)
		if failures > 0: return
	var ticket := EarlyRedemption.ticket_for(s._day.state)
	check(loan_seen and early_seen == (tier != "high"), "funds determine early route")
	check(ticket.status == ("transferred" if transfer else "redeemed" if tier != "high" or fund_silk else "defaulted"), "Jiang final actual funding " + tier + str(fund_silk) + " " + ticket.status)
	verify(s, "Jiang closure " + tier + str(fund_silk))

func disposals() -> void:
	for tier in ["low", "medium", "high"]:
		for route in ["keep", "transfer", "redeem"]:
			var s := unit(false, true)
			check(quote(s, tier).ok, "disposal contract")
			var ticket := s._day.state.pawn_tickets[0]
			# Isolate the two possible return outcomes, leaving the issued rate and
			# redemption total unchanged. Saved natural routes are checked above.
			ticket.terms_id = PawnRedemptionPolicy.REDEEM if route == "redeem" else PawnRedemptionPolicy.DEFAULT
			s._day.state.current_night_index = ticket.due_night
			var cash := s._day.state.cash
			var controller := PawnController.new()
			if route == "redeem":
				PawnReturnService.prepare(s._day.state, catalog); PawnReturnService.arrive(s._day.state)
				check(controller.execute(s._day, ticket, catalog.get_definition("pawn_terms", ticket.terms_id), "redeem").ok, "ordinary due return")
				check(s._day.state.cash == cash + ticket.redemption_amount, "ordinary full issued amount")
			else:
				s._day.state.phase = &"night_resolution"
				var choices := {ticket.ticket_id: route}
				check(controller.disposal_reason(s._day.state, catalog, choices).is_empty(), "valid disposal")
				controller.resolve_maturities(s._day.state, 540, catalog, choices)
				check(s._day.state.cash == cash + (80 if route == "transfer" else 0), "transfer uses principal only")
				check(ticket.status == ("transferred" if route == "transfer" else "defaulted"), "closed disposal")
			check(ticket.interest_tier == tier and ticket.redemption_amount == 100 + PawnInterestPolicy.fee(100, tier), "issued contract stays fixed")

func run() -> void:
	if not setup(): quit(1); return
	saved_quotes(); disposals()
	for tier in ["low", "medium", "high"]: seamstress_journey(tier, false)
	seamstress_journey("high", true)
	seamstress_journey("high", false, true)
	print("PAWN CONTRACTS V45: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
