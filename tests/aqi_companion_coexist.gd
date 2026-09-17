extends "res://tests/aqi_companion_durability.gd"

var pawned := false
var returned := false

func run() -> void:
	catalog = JsonContentProvider.new("res://data/aqi_companion_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	for seed_value in [7, 2025, 91]:
		var store := GhostReplayStore.new(); store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
		var s := RunSession.new(run_def, 25, store, catalog)
		for n in range(1, 11):
			driver.drain(s); act(s, "open_shop")
			if n >= 7: opening_story(s, "ignore" if seed_value == 91 else "example")
			driver.drain(s)
			for step in 200:
				if s._day.state.phase != &"open" or seed_value == 91: break
				driver.drain(s)
				var returning := PawnReturnService.current(s._day.state)
				if not returning.is_empty():
					if n >= 8:
						check(s.companion_model().visible and not s.companion_model().available, "companion quiet at redemption")
						fixture(s, "redemption")
						returned = true
					check(s.counter_command(returning.command, returning.id).ok, "redemption continues")
					continue
				var v := s._counter.customers.active(s._day.state)
				if v == null:
					if not s.bell_model().enabled: break
					check(s.bell_command("wait").ok, "normal bell")
					continue
				if n in [5, 6] and not pawned and s._counter.reason(s._day, "pawn", v.visit_id, "", v.trade.asking_price).is_empty() and (catalog.get_definition("pawn_terms", VarietyService.terms_for(v, catalog.get_definition("customers", v.customer_id))) as PawnTermsDefinition).return_mode == "redeem":
					var result := s.counter_command("pawn", v.visit_id, "", v.trade.asking_price)
					check(result.ok, "fifth night real pawn")
					if result.ok: pawned = true
				else:
					var rejected := s.counter_command("swap_reject" if v.customer_id == GhostGuests.SWAP else "reject", v.visit_id)
					check(rejected.ok, "refuse " + v.customer_id + ": " + rejected.message)
					if not rejected.ok: break
			if s._day.state.phase == &"open": act(s, "close_shop")
			check(not s.companion_model().visible, "close clears companion")
			if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
			act(s, "resolve_night")
			if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
			if n in [7, 10]: closing_story(s, "ignore" if seed_value == 91 else "example")
			act(s, "enter_room"); driver.drain(s)
			if n == 5 and seed_value != 91: check(s.observe_room("aq_paper").ok, "paper observation")
			act(s, "sleep"); driver.drain(s)
			if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
			act(s, "finish_sleep"); act(s, "continue_run")
		check(s._day.state.phase == &"run_ended" and s._day.state.current_night_index == 10, "seed ten nights " + str(seed_value))
		verify(s, "seed " + str(seed_value))
	check(pawned and returned, "real pawn and return coexist with Aqi")
	risk_order()
	ticket_risk_order()
	print("AQI V25 COEXIST: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func risk_order() -> void:
	var s := restored_stage("idle-8")
	var held := LivingMirror.held(s._day.state)
	check(held != null, "real held mirror for risk")
	if held == null: return
	if s._risk.covered(s._day.state, held.instance_id): check(s.risk_command("uncover", held.instance_id).ok, "uncover before closing")
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night")
	check(not s._day.state.risk_pending.is_empty(), "existing uncovered mirror crisis")
	check(s.event_model().pending_id.is_empty() and not s.companion_model().visible, "crisis hides companion")
	var result := s.risk_command("defy", s._day.state.risk_pending)
	check(result.ok, "existing shop risk consequence")
	if s._day.state.phase != &"dead":
		act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): check(s.risk_command("defy", s._day.state.risk_pending).ok, "sleep risk consequence")
	if s._day.state.phase != &"dead":
		act(s, "finish_sleep"); act(s, "continue_run"); driver.drain(s); act(s, "open_shop"); driver.drain(s)
		act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night")
		check(s.risk_command("defy", s._day.state.risk_pending).ok, "second real shop attack")
	check(s._day.state.phase == &"dead", "existing risk death still applies after meeting Aqi")
	check(not s.companion_model().visible and s.event_model().pending_id.is_empty(), "no post-death story")
	verify(s, "real risk death")

func ticket_risk_order() -> void:
	var s := restored_stage("customer-10")
	var held := LivingMirror.held(s._day.state)
	check(held != null, "tenth night held mirror")
	if held == null: return
	if s._risk.covered(s._day.state, held.instance_id): check(s.risk_command("uncover", held.instance_id).ok, "tenth uncover")
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night")
	check(not s._day.state.risk_pending.is_empty() and s._day.state.pending_event_id == "aq_old_ticket", "ticket queues behind crisis")
	check(s.event_model().pending_id.is_empty(), "ticket presentation waits for crisis")
	var before := s.read_state()
	check(not s.event_command("aq_old_ticket", "compare").ok and s.read_state() == before, "cannot skip crisis by choosing ticket")
	check(s.risk_command("retreat", s._day.state.risk_pending).ok and s.event_model().pending_id == "aq_old_ticket", "ticket appears after survival")
	verify(s, "ticket after crisis")
