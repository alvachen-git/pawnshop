extends "res://tests/run_investigation.gd"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/mirror_investigation_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false
	driver.check = check; driver.catalog = catalog
	var verified := false
	for seed_value in 24:
		var store := GhostReplayStore.new(); store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
		var s := RunSession.new(run_def, 23, store, catalog)
		var exchanged := false
		for n in range(1, 11):
			driver.drain(s); act(s, "open_shop"); driver.drain(s)
			if n == 8 and exchanged:
				var target := GhostGuests.target_ticket(s._day.state)
				if target.status == "redeemed":
					check(target.closed_night == 7 and s._day.state.person_deaths.size() == 1, "seventh delivery eighth death")
					var death: Dictionary = s._day.state.person_deaths[0]
					check(death.person_id == target.person.id, "specific pawn owner death")
					var before := s.read_state(); s.seven_notice(); s.event_model()
					check(before == s.read_state(), "reading death notice is neutral")
					verify(s, "cross seventh pawn death")
					verified = true
			for step in 150:
				var returning := PawnReturnService.current(s._day.state)
				if not returning.is_empty():
					check(s.counter_command(returning.command, returning.id).ok, "actual return")
					continue
				var v := s._counter.customers.active(s._day.state)
				if v == null:
					if not s.bell_model().enabled: break
					s.bell_command("wait"); driver.drain(s); continue
				if v.customer_id == GhostGuests.SWAP:
					check(s.counter_command("swap_accept", v.visit_id).ok, "swap completed")
					exchanged = true
				elif n == 4 and s._day.state.pawn_tickets.is_empty() and v.night_policy.is_empty() and "pawn" in v.transaction_modes and not EarlyRedemption.is_visit(v):
					var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
					var terms := catalog.get_definition("pawn_terms", VarietyService.terms_for(v, customer)) as PawnTermsDefinition
					if terms != null and terms.term_nights == 3:
						var price := maxi(1, ceili(v.trade.asking_price * terms.loan_ratio))
						var result := s.counter_command("pawn", v.visit_id, "", price)
						if not result.ok and v.status == "active": s.counter_command("reject", v.visit_id)
					else: s.counter_command("reject", v.visit_id)
				else: s.counter_command("reject", v.visit_id)
				driver.drain(s)
			if s._day.state.phase == &"open": act(s, "close_shop")
			if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
			for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id, "keep")
			act(s, "resolve_night"); act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s); act(s, "finish_sleep"); act(s, "continue_run")
		if verified:
			verify(s, "ten nights pawn aftermath")
			break
	check(verified, "actual seeded cross seventh swap route covered")
	var followed := false
	for seed_value in 128:
		var plan := FamiliarStories.plan(run_def, catalog, seed_value)
		for story in plan.stories:
			if story.follow_night <= 7: continue
			var state := RunState.create(run_def); state.run_seed = seed_value
			state.visit_history.append({"visit_id": story.first.visit_id, "night": story.first_night, "outcome": "rejected"})
			var rows := OpeningPreparation.plan(state, run_def, catalog)
			check(rows.any(func(row: Dictionary) -> bool: return row.visit_id == story.follow.visit_id and row.get("familiar_reserved", false)), "post seventh familiar slot reserved")
			followed = true
	check(followed, "future familiar cases covered")
	print("INVESTIGATION BUSINESS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
