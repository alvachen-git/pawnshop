extends "res://tests/lu_introduction.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/pawn_interest_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v45 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 45, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state, 45), run_def, 45, catalog, true)
	check(restored != null, "cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)

func fixture(s: RunSession, label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/pawn-v45")
	var file := FileAccess.open("res://.godot/qa/pawn-v45/" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 45)))

# Controlled boundary fixtures use the real quote service; journey fixtures below
# additionally prove the same rules under a complete saved command transcript.
func unit(fixed_firm := false, needs_money := true) -> RunSession:
	var s := fresh_growth()
	var state := s._day.state
	state.current_night_index = 3; state.phase = &"open"; state.pending_event_id = ""
	state.narrative_flags.append(PawnInterestPolicy.FLAG)
	state.cash = 10000; state.visits.clear(); state.pawn_returns.clear()
	var v := CustomerVisit.new()
	v.visit_id = "unit-pawn"; v.customer_id = "customer_wealthy_antique" if fixed_firm else "customer_wealthy_silk"
	v.person = {"id": "fixed/person", "name": "验收当户"}; v.status = "active"; v.arrival = 0; v.expires_at = 540
	v.pawn_terms_id = "sample_three_redeem"; v.transaction_modes = ["pawn"]
	v.item = ItemInstance.new(); v.item.instance_id = "item/" + v.visit_id; v.item.definition_id = "item_luxury_gold_watch"; v.item.selected_variant_id = "sound"
	v.trade.opening_price = 100; v.trade.asking_price = 100; v.trade.reserve_price = 90; v.trade.rounds_left = 20; v.trade.patience = 20
	WealthyCustomers.data(state).trades[v.visit_id] = {"reference": 100, "funding": 90, "watch_owner": {"urgent": needs_money}}
	state.visits.append(v)
	state.ordinary_selections.append({"visit_id": v.visit_id, "context_id": "unit", "night": 3})
	return s

func quote(s: RunSession, tier: String, amount := 100) -> ActionResult:
	return s._counter.execute(s._day, "pawn", "unit-pawn", tier, amount)

func boundaries() -> void:
	for principal in [1, 9, 10, 19, 20, 21, 99, 100, 101]:
		for tier in PawnInterestPolicy.RATES:
			check(PawnInterestPolicy.fee(principal, tier) == ceili(float(principal * int(PawnInterestPolicy.RATES[tier])) / 100.0), "fee rounding")
	for base in [20, 50, 80]:
		check(PawnInterestPolicy.chance(base, "low") == base + 10 and PawnInterestPolicy.chance(base, "high") == base - 10, "chance offsets")
		for roll in 100:
			var low := int(roll < PawnInterestPolicy.chance(base, "low"))
			var mid := int(roll < PawnInterestPolicy.chance(base, "medium"))
			var high := int(roll < PawnInterestPolicy.chance(base, "high"))
			check(low >= mid and mid >= high, "same roll monotonic")
	for rigid in [false, true]:
		for urgent in [false, true]:
			var s := unit(rigid, urgent); var v := s._day.state.visits[0]; var before := s.read_state()
			check(quote(s, "high").ok, "valid high quote handled")
			check(s._day.state.social.reputation == -2, "high reported immediately")
			var refused: bool = rigid or not urgent
			check((v.status == "active") == refused, "personality urgency matrix")
			if refused:
				check(s._day.state.cash == before.cash and s._day.state.pawn_tickets.is_empty(), "refusal no cash or ticket")
				check(s._day.state.game_minutes == 5 and v.trade.rounds_left == 19 and v.trade.asking_price == 100, "refusal time round and no principal discount")
				var patience := v.trade.patience
				check(quote(s, "high").ok and s._day.state.social.reputation == -2 and v.trade.patience < patience, "repeat no extra reputation")
				check(quote(s, "low").ok and s._day.state.pawn_tickets[0].redemption_amount == 105, "lower tier can close")
				check(s._day.state.social.reputation == -2, "no low reward after high")
			else:
				check(s._day.state.pawn_tickets[0].redemption_amount == 120, "high contract fixed")
	for tier in ["low", "medium", "high"]:
		var s := unit(false, true)
		check(quote(s, tier, 140).ok, "generous principal")
		var expected: int = {"low": 4, "medium": 2, "high": 0}[tier]
		check(s._day.state.social.reputation == expected, "principal and interest stack " + tier)
		check(s._day.state.pawn_tickets[0].interest_tier == tier, "ticket tier stored")
	var capped := unit(true, true)
	for n in 4:
		capped._day.state.visits[0].visit_id = "cap/" + str(n)
		PawnInterestPolicy.reputation(capped._day.state, capped._day.state.visits[0], "high", false)
	check(capped._day.state.social.reputation == -6, "negative nightly cap")
	var positive := unit(false, true)
	for n in 4:
		positive._day.state.visits[0].visit_id = "cap/" + str(n)
		PawnInterestPolicy.reputation(positive._day.state, positive._day.state.visits[0], "low", true)
	check(positive._day.state.social.reputation == 6, "positive nightly cap")
	for malformed in ["", "LOW", "20", "extreme"]:
		var s := unit(); var before := s.read_state()
		check(not quote(s, malformed).ok and s.read_state() == before, "invalid tier atomic")
	var invalid := unit(); invalid._day.state.cash = 0
	var before := invalid.read_state()
	check(not quote(invalid, "high").ok and invalid.read_state() == before, "unfunded high no penalty")
	for night in [1, 2]:
		var locked := unit(); locked._day.state.current_night_index = night
		before = locked.read_state()
		check(not quote(locked, "high").ok and locked.read_state() == before, "night lock at service")
	for seed_value in range(1, 13):
		var s := fresh_growth(seed_value)
		s._day.state.current_night_index = 2; s._day.state.social.reputation = 80
		var rows := OpeningPreparation.plan(s._day.state, run_def, catalog)
		check(rows.filter(func(row: Dictionary) -> bool: return row.night < 3).all(func(row: Dictionary) -> bool: return "pawn" not in row.transaction_modes), "ordinary and wealthy first two nights")
		var invited := OpeningPreparation.make_row(s._day.state, run_def, catalog, "invite", 75, "")
		check("pawn" not in invited.transaction_modes, "invited early visitors buyout only")

func journey() -> void:
	var s := fresh_growth(42)
	driver.drain(s); act(s, "open_shop"); driver.drain(s)
	fixture(s, "night-one")
	var v := s._counter.customers.active(s._day.state)
	check(s.counter_command("offer", v.visit_id, "", v.trade.reserve_price).ok, "opening purchase")
	driver.drain(s); finish_night(s)
	driver.drain(s)
	check(LuIntroduction.unlocked(s._day.state, run_def) and not PawnInterestPolicy.unlocked(s._day.state, run_def), "second night letters only")
	act(s, "open_shop"); finish_night(s)
	check(s._day.state.current_night_index == 3 and s._day.state.pending_event_id == PawnInterestPolicy.EVENTS[0], "third night tutorial arrives")
	fixture(s, "tutorial")
	for id in PawnInterestPolicy.EVENTS:
		var before := s.read_state()
		check(not s.execute("open_shop").ok and s.read_state() == before, "cannot skip teaching")
		(s._save as CountingStore).fail = true
		check(not s.counter_command("lu_intro", id, "continue").ok and s.read_state() == before, "teaching save rollback")
		(s._save as CountingStore).fail = false
		check(s.counter_command("lu_intro", id, "continue").ok, "teaching page")
		verify(s, id)
	check(PawnInterestPolicy.unlocked(s._day.state, run_def), "farewell unlock")
	check(s._day.state.game_minutes == 0 and PreparationService.count(s._day.state) == 0, "teaching free of time and AP")
	fixture(s, "unlocked")
	var library := SaveLibrary.new("user://tests/pawn-v45/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/pawn_interest_manifest.json", catalog)
	check(library.write_entry("manual/1", s._day.state, run_def, 45, catalog), "new version library save")
	var entry := library.read_entry("manual/1")
	check(not entry.is_empty() and entry.catalog.content_version == 45 and PawnInterestPolicy.FLAG in entry.state.narrative_flags, "new library restores v45 unlock")
	act(s, "open_shop"); driver.drain(s)
	var found := false
	for guard in 120:
		v = s._counter.customers.active(s._day.state)
		if v != null and "pawn" in v.transaction_modes and not EarlyRedemption.is_visit(v): found = true; break
		if v != null: check(s.counter_command("reject", v.visit_id).ok, "clear prior visitor")
		else: act(s, "short_task")
		driver.drain(s)
	check(found, "third night pawn customer preserved")
	if not found: return
	fixture(s, "pawn-visit")
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.counter_command("pawn", v.visit_id, "high", 100).ok and s.read_state() == before, "high quote save failure rolls back all")
	(s._save as CountingStore).fail = false
	var amount := s.counter_model().trade.pawn_asking as int
	check(s.counter_command("pawn", v.visit_id, "low", amount).ok, "real low contract")
	verify(s, "issued contract")
	fixture(s, "pawn-completed")
	var payload := SaveCodec.new().encode(s._day.state, 45)
	for kind in ["rate", "money", "reputation", "unlock"]:
		var altered := payload.duplicate(true)
		if kind == "rate": altered.pawn_tickets[0].interest_tier = "high"
		if kind == "money": altered.pawn_tickets[0].redemption_amount += 1
		if kind == "reputation": altered.social.reputation += 2
		if kind == "unlock": altered.narrative_flags.erase(PawnInterestPolicy.FLAG)
		InvestigationSaveCodec.clear_cache()
		check(SaveCodec.new().decode(altered, run_def, 45, catalog, true) == null, "tamper rejected " + kind)
	var ticket := s._day.state.pawn_tickets[0]
	var due := ticket.due_night
	while s._day.state.current_night_index < due:
		finish_night(s); driver.drain(s)
		act(s, "open_shop"); driver.drain(s)
		var returning := PawnReturnService.current(s._day.state)
		while not returning.is_empty():
			check(s.counter_command(returning.command, returning.id).ok, "settle actual return")
			returning = PawnReturnService.current(s._day.state)
	finish_night(s)
	check(ticket.status in ["redeemed", "defaulted"], "three night pawn closes")
	verify(s, "maturity")

func run() -> void:
	if not setup(): quit(1); return
	boundaries(); journey()
	print("PAWN INTEREST V45: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
