extends "res://tests/shop_growth.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/social_relations_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "social catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, SocialRules.VERSION, store, catalog)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 27)
	var restored := codec.decode(data, run_def, 27, catalog, true)
	check(restored != null, "replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)

func fixture(_s: RunSession, _label: String) -> void: pass

func run() -> void:
	if not setup(): quit(1); return
	price_boundaries()
	military_boundaries()
	failed_quote_then_leave()
	legacy_unchanged()
	print("SOCIAL RELATIONS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func price_boundaries() -> void:
	check(ReputationService.delta(120, 100, "bought") == 2, "120 inclusive")
	check(ReputationService.delta(119, 100, "bought") == 0, "119 neutral")
	check(ReputationService.delta(80, 100, "bought") == -2, "80 inclusive")
	check(ReputationService.delta(81, 100, "bought") == 0, "81 neutral")
	check(ReputationService.delta(60, 100, "rounds_exhausted") == -1, "60 failed")
	check(ReputationService.delta(61, 100, "patience_exhausted") == 0, "61 failed neutral")
	check(ReputationService.delta(60, 100, "rejected") == -1, "ending after a rejected extreme quote")
	for outcome in ["timed_out", "shop_closed", "inspection_refused"]:
		check(ReputationService.delta(1, 100, outcome) == 0, "no punishment " + outcome)
	for pair in [[-100,-2],[-50,-2],[-49,-1],[-20,-1],[-19,0],[19,0],[20,1],[49,1],[50,2],[100,2]]:
		check(ReputationService.adjustment(pair[0]) == pair[1], "traffic boundary")
	var s := second_night()
	act(s, "open_shop"); driver.drain(s)
	var v: CustomerVisit
	for candidate in s._day.state.visits:
		if ReputationService.eligible(s._day.state, candidate): v = candidate; break
	check(v != null, "ordinary visit exists")
	if v == null: return
	v.trade.opening_price = 100; v.trade.asking_price = 100; v.trade.reserve_price = 60
	v.trade.social_offer_mode = "offer"
	var clue := ClueDefinition.new("test_flaw", "裂纹", 20, 80, 20, "damaged")
	var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
	TradeController.new().pressure(v.trade, customer, clue)
	check(ReputationService.basis(s._day.state, v) == 80, "accepted flaw adjusts baseline")
	v.trade.asking_price = 30
	check(ReputationService.basis(s._day.state, v) == 80, "ordinary concession cannot shift baseline")
	v.trade.offers.assign([96]); v.trade.social_last_was_quote = true
	var n: int = s._day.state.social.trades.size()
	ReputationService.finish(s._day.state, v, "bought")
	ReputationService.finish(s._day.state, v, "bought")
	check(s._day.state.social.trades.size() == n + 1 and s._day.state.social.reputation == 2, "settlement once")
	v.trade.social_offer_mode = "pawn"
	var terms := catalog.get_definition("pawn_terms", VarietyService.terms_for(v, customer)) as PawnTermsDefinition
	check(ReputationService.basis(s._day.state, v) == maxi(1, roundi(80 * terms.loan_ratio)), "pawn baseline")
	for positive in [true, false]:
		for i in 8:
			v.visit_id = "cap/%s/%d" % [positive, i]
			s._day.state.ordinary_selections.append({"visit_id": v.visit_id, "context_id": "ordinary"})
			v.trade.social_offer_mode = "offer"; v.trade.offers.assign([96 if positive else 50])
			ReputationService.finish(s._day.state, v, "bought")
	check(s._day.state.social.reputation == 0, "independent positive and negative six-point caps")
	SocialRules.change(s._day.state, "military", -1000, "test")
	check(s._day.state.social.military == -100 and s._day.state.social.reputation == 0, "clamp and independence")
	SocialRules.change(s._day.state, "military", 1000, "test")
	check(s._day.state.social.military == 100, "positive clamp")

func military_boundaries() -> void:
	for pair in [[-100,35,45],[-80,35,45],[-79,20,35],[-50,20,35],[-49,0,35],[-20,0,35],[-19,0,0],[19,0,0],[20,0,0],[50,0,0],[80,0,0]]:
		var b := MilitaryService.band(pair[0])
		check(b.closure == pair[1] and b.fee == pair[2], "military band " + str(pair[0]))
	check(MilitaryService.band(20).supply == 25 and MilitaryService.band(50).supply == 40 and MilitaryService.band(80).supply == 55, "supply probabilities")
	check(MilitaryService.quiet(2,4,2) and not MilitaryService.quiet(2,5,2), "two complete quiet nights")
	check(MilitaryService.quiet(2,6,4) and not MilitaryService.quiet(2,7,4), "four complete quiet nights")
	var s := second_night()
	SocialRules.change(s._day.state, "military", -80, "test")
	SocialRules.night(s._day.state).military_checked = false
	MilitaryService.dawn(s._day.state, run_def)
	check(s._day.state.social.pending.kind == "fee", "first bad encounter is fee even deeply hostile")
	check(not s.can_execute("open_shop"), "unresolved military notice blocks opening")
	check(s.social_command("refuse").ok, "fee refusal")
	check(s._day.state.social.military == -88 and s._day.state.social.fee_seen and s._day.state.social.threatened, "fee refusal records threat")
	check(s._day.state.social.pending.is_empty(), "refusal never immediate closure")

func legacy_unchanged() -> void:
	var loaded := JsonContentProvider.new("res://data/shop_growth_manifest.json").load_catalog()
	var old := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
	var store := CountingStore.new(); store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
	var s := RunSession.new(old, 25, store, loaded.catalog)
	check(not s._day.state.social_enabled and not s.read_state().has("social"), "v25 has no injected social fields")
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(s._day.state,25),old,25,loaded.catalog,true) != null, "v25 exact replay")

func failed_quote_then_leave() -> void:
	var s := second_night()
	act(s, "open_shop"); driver.drain(s)
	if s._counter.customers.active(s._day.state) == null: s.bell_command("wait"); driver.drain(s)
	var v := s._counter.customers.active(s._day.state)
	for step in 6:
		if v == null: break
		var person := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
		if ReputationService.eligible(s._day.state,v) and v.trade.patience > person.terms.failed_quote_cost: break
		s.counter_command("reject",v.visit_id); driver.drain(s)
		if s._counter.customers.active(s._day.state) == null: s.bell_command("wait"); driver.drain(s)
		v = s._counter.customers.active(s._day.state)
	check(v != null and ReputationService.eligible(s._day.state,v), "ordinary negotiation for failure test")
	if v == null: return
	var before: int = s._day.state.social.reputation
	check(not s.counter_command("offer",v.visit_id,"",s._day.state.cash+1000).ok, "unaffordable high quote never pays")
	check(s._day.state.social.reputation == before, "unpaid high quote gains nothing")
	v = s._counter.customers.active(s._day.state)
	var command := "offer" if "sell" in v.transaction_modes else "pawn"
	check(s.counter_command(command,v.visit_id,"",1).ok, "extreme offer is a valid negotiation action")
	check(s._day.state.social.reputation == before and s._counter.customers.active(s._day.state) == v, "failed quote does not settle mid-negotiation")
	check(s.counter_command("reject",v.visit_id).ok, "end negotiation after refused offer")
	check(s._day.state.social.reputation == before - 1, "last extreme refused quote settles once on leaving")
	check(not s.counter_command("reject",v.visit_id).ok and s._day.state.social.reputation == before - 1, "repeat leave cannot charge twice")
	verify(s,"extreme quote followed by leaving")
