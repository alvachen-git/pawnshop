extends "res://tests/run_living_mirror.gd"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.catalog = catalog; driver.check = check
	var seeds: Array[int] = []
	for seed_value in 512:
		var story := FamiliarStories.story_for({"familiar_plan": FamiliarStories.plan(run_def, catalog, seed_value)}, "seamstress")
		if story.get("first_night", 0) == 4 and story.get("follow_night", 0) == 6 and story.get("funds", 0) >= 30: seeds.append(seed_value)
	check(not seeds.is_empty(), "late funded seamstress seeds")
	for route in ["allow", "defer", "expire", "short", "transfer", "multiple"]:
		play_jiang(seeds[0], route)
		if failures > 0: break
	print("LIVING PAWN ROUTES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func play_jiang(seed_value: int, route: String) -> void:
	var s := session(seed_value)
	var swapped := false
	var seen_follow := false
	for n in range(1, 8):
		driver.drain(s)
		act(s, "open_shop"); driver.drain(s)
		var m := LivingMirror.held(s._day.state)
		if m != null and s._risk.covered(s._day.state, m.instance_id): check(s.risk_command("uncover", m.instance_id).ok, "uncover")
		for step in 200:
			if s._day.state.game_minutes >= 480 or s._day.state.phase != &"open" or failures > 0: break
			driver.drain(s)
			var back := PawnReturnService.current(s._day.state)
			if not back.is_empty(): check(s.counter_command(back.command, back.id).ok, "due return"); continue
			var v := CustomerManager.new().active(s._day.state)
			if v == null: act(s, "short_task"); continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if v.item.definition_id in ["intro_silver_hairpin", "item_weeping_mirror"] and row.get("familiar_id", "").is_empty():
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "acquire intro/mirror"); continue
			if v.customer_id == GhostGuests.SWAP:
				swapped = true
				var t := GhostGuests.target_ticket(s._day.state)
				if route != "multiple": check(t.person.id == "familiar/seamstress", "specifically target Jiang Suyun")
				check(s.inspect_customer(v.visit_id).ok, "swap scan")
				check(s.counter_command("swap_accept", v.visit_id).ok, "seamstress exchange")
				continue
			if row.get("familiar_id", "") == "seamstress":
				if row.familiar_stage == "first":
					check(s.counter_command("pawn", v.visit_id, "", 90 if route in ["short", "transfer"] else 25).ok, "Jiang loan")
				elif EarlyRedemption.is_visit(v):
					seen_follow = true
					check(s.inspect_customer(v.visit_id).ok, "early redemption is mirror eligible")
					check(s._day.state.soul_history.back().result == "living", "Jiang alive")
					if route == "expire":
						while s._day.state.game_minutes < v.expires_at - 10: act(s, "short_task")
						check(not s.counter_command("early_redeem", v.visit_id).ok, "incomplete early handover")
						check(s._day.state.person_deaths.is_empty(), "incomplete handover causes no death")
					else: check(s.counter_command("early_redeem" if route in ["allow", "multiple"] else "defer_redeem", v.visit_id).ok, "early choice")
				else: check(s.counter_command("reject", v.visit_id).ok, "short funds ordinary silk")
			elif route == "multiple" and row.get("seven_role", "") == "pawn": check(s.counter_command("pawn", v.visit_id, "", 40).ok, "second target")
			else: check(s.counter_command("reject", v.visit_id).ok, "ordinary rejection")
		if failures > 0: return
		m = LivingMirror.held(s._day.state)
		if m != null: check(s.risk_command("cover", m.instance_id).ok, "safe storage")
		act(s, "close_shop"); act(s, "wait_until_seal")
		for t in PawnController.new().maturities(s._day.state): check(s.choose_pawn_disposal(t.ticket_id, "transfer" if route == "transfer" else "keep").ok, "disposal")
		act(s, "resolve_night"); act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s); act(s, "finish_sleep"); act(s, "continue_run")
	check(swapped, "swap opportunity actually reached " + route)
	var ticket := EarlyRedemption.ticket_for(s._day.state)
	check(ticket != null, "Jiang contract retained")
	check(s._day.state.person_deaths.size() == (1 if route in ["allow", "multiple"] else 0), "death within seven only after delivered sixth " + route)
	if route in ["defer", "expire"]: check(ticket.closed_night == 7, "seventh delivery consequence pending eighth")
	if route in ["short", "transfer"]: check(ticket.status == ("defaulted" if route == "short" else "transferred"), "unredeemed substitute disposal")
	checkpoint(s, "jiang_" + route)
