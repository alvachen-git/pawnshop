extends "res://tests/run_familiar_stories.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/familiar_early_manifest.json").load_catalog()
	check(loaded.is_success(), "content18")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "familiar_early")
	driver.check = check; driver.catalog = catalog
	var chosen := -1
	for seed_value in 512:
		var plan := FamiliarStories.plan(run_def, catalog, seed_value)
		check(plan == FamiliarStories.plan(run_def, catalog, seed_value), "stable plan")
		var story := FamiliarStories.story_for({"familiar_plan": plan}, "seamstress")
		if not story.is_empty() and story.funds == 30 and story.first_night <= 4: chosen = seed_value
	check(chosen >= 0, "funded sample exists")
	print("EARLY SEED: ", chosen)
	for route in ["allow", "defer", "miss", "deadline", "short"]:
		play(chosen, route)
		if failures > 0: break
	print("EARLY REDEMPTION: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func roundtrip(s: RunSession, label: String) -> void:
	var data := SaveCodec.new().encode(s._day.state, 18)
	var codec := SaveCodec.new()
	var restored := codec.decode(JSON.parse_string(JSON.stringify(data)), run_def, 18, catalog, true)
	check(restored != null, "restore " + label + ": " + codec.error_message)
	if restored != null: check(restored.to_read_model() == data_without_versions(data), "exact state")
	var dir := "res://.godot/qa/early"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(dir + "/%s_%d_%s.json" % [label.replace(" ", "_"), s._day.state.current_night_index, s._day.state.phase], FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()

func play(seed_value: int, route: String) -> void:
	run_def._randomize_seed = false; run_def._seed = seed_value
	var save := SaveManager.new("user://tests/early/%s.json" % route)
	var s := RunSession.new(run_def, 18, save, catalog)
	s.new_run()
	var follow_seen := false
	var receipts := []
	s.transaction_completed.connect(func(r: Dictionary) -> void: receipts.append(r))
	for n in range(1, 8):
		driver.drain(s)
		if n >= 2: check(s.execute("prep_finish").ok, "end preparation")
		roundtrip(s, route)
		check(s.execute("open_shop").ok, "open")
		driver.drain(s)
		while not PawnReturnService.current(s._day.state).is_empty():
			var back := PawnReturnService.current(s._day.state)
			check(s.counter_command("redeem", back.id).ok, "due redemption")
		for step in 180:
			driver.drain(s)
			if s._day.state.game_minutes >= 470 or s._day.state.phase != &"open" or failures > 0: break
			var v := s._counter.customers.active(s._day.state)
			if v == null: check(s.execute("short_task").ok, "wait"); continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if row.get("familiar_id") != "seamstress": check(s.counter_command("reject", v.visit_id).ok, "ordinary reject"); continue
			if row.familiar_stage == "first":
				check(s.counter_model().trade.body.contains(EarlyRedemption.AGREEMENT), "terms shown before loan")
				check(s.counter_command("pawn", v.visit_id, "", 90 if route == "short" else 25).ok, "original loan")
				check(receipts.back().detail.contains(EarlyRedemption.AGREEMENT), "ticket receipt terms")
				continue
			follow_seen = true
			if route == "short":
				check(not EarlyRedemption.is_visit(v) and v.item.definition_id == "item_silk_panel", "short funds still sell silk")
				check(not s.counter_command("early_redeem", v.visit_id).ok, "cannot redeem without funds")
				check(s.counter_command("reject", v.visit_id).ok, "reject silk"); continue
			check(EarlyRedemption.is_visit(v) and v.item.definition_id == "item_silver_hairpin", "money enough replaces silk")
			var snapshot := s.read_state()
			check(not s.counter_command("offer", v.visit_id, "", 100).ok and s.read_state() == snapshot, "no buying collateral again")
			check(not s.counter_command("belittle", v.visit_id).ok and s.read_state() == snapshot, "no bargaining on original ticket")
			if route == "miss": check(s.execute("close_shop").ok, "miss optional visit"); break
			if route == "deadline":
				while s._day.state.game_minutes < v.expires_at - 10: check(s.execute("short_task").ok, "approach deadline")
				check(not s.counter_command("early_redeem", v.visit_id).ok, "exact deadline has no effect")
			else:
				var before := s._day.state.cash
				var ticket := EarlyRedemption.ticket_for(s._day.state)
				var count := receipts.size()
				check(s.counter_command("early_redeem" if route == "allow" else "defer_redeem", v.visit_id).ok, route)
				check(s._day.state.cash == before + (ticket.redemption_amount if route == "allow" else 0), "money comes in once")
				check(receipts.size() == count + (1 if route == "allow" else 0), "only real redemption creates receipt")
				if route == "allow": check(receipts.back().item == "银簪" and receipts.back().kind == "redemption", "receipt links original collateral")
			var after := s.read_state()
			check(not s.counter_command("early_redeem", v.visit_id).ok and s.read_state() == after, "duplicate cannot redeem again")
		if failures > 0: return
		if s._day.state.phase == &"open": check(s.execute("close_shop").ok, "close")
		roundtrip(s, route)
		check(s.execute("wait_until_seal").ok, "seal")
		for ticket in s._commerce.pawns.maturities(s._day.state): check(s.choose_pawn_disposal(ticket.ticket_id, "keep").ok, "unredeemed disposal")
		check(s.execute("resolve_night").ok, "resolve")
		for action in ["enter_room", "sleep", "finish_sleep"]:
			driver.drain(s); check(s.execute(action).ok, action); roundtrip(s, route)
		check(s.execute("continue_run").ok, "continue")
	check(follow_seen, "candidate actually encountered")
	var ticket := EarlyRedemption.ticket_for(s._day.state)
	check(ticket != null and ticket.status == ("defaulted" if route == "short" else "redeemed"), "final contract result")
	if route == "allow":
		check(ticket.closed_night < ticket.due_night, "early closing date")
		check(not s._day.state.pawn_returns.any(func(r: Dictionary) -> bool: return r.ticket_id == ticket.ticket_id), "no duplicate due return")
	elif route != "short": check(ticket.closed_night == ticket.due_night, "defer or miss preserves due return")
	roundtrip(s, route)
