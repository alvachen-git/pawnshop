extends "res://tests/run_mirror_reunion.gd"
var pawned := false
var redeemed := false
func run() -> void:
	reunion_manifest = "res://data/first_debt_reckoning_manifest.json"
	reunion_fixture_dir = "res://.godot/qa/v29-coexist/"
	catalog = JsonContentProvider.new(reunion_manifest).load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._initial_cash = 1000 # Funded coexistence fixture, not shipped opening funds.
	driver.check = check; driver.catalog = catalog
	journey("example")
	risk_after_case()
	check(pawned and redeemed, "actual pledge and original owner's redemption executed")
	print("FIRST DEBT COEXIST: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func aqi_story(s: RunSession, _route: String) -> void:
	check(s.event_model().pending_id == "aq_ledger" and "aq_met" in s._day.state.narrative_flags, "daytime Aqi precedes ledger")
	driver.drain(s)

func journey(route: String) -> void:
	var s := fresh23()
	for n in range(1, 14):
		driver.drain(s)
		act(s, "open_shop"); driver.drain(s)
		var opening_return := PawnReturnService.current(s._day.state)
		if not opening_return.is_empty():
			check(s.counter_command(opening_return.command, opening_return.id).ok, "opening redemption precedes investigation")
			redeemed = true
		if n >= 7:
			for id in ["wm_ticket", "wm_life", "wm_identity", "wm_concealed", "wm_motive", "wm_choice"]:
				if id in s._day.state.narrative_flags or s._day.state.event_history.any(func(r: Dictionary) -> bool: return r.event_id == id): continue
				check(s.study_command(id, ("seek" if route == "sold" else "seal") if id == "wm_choice" else "read").ok, "late real investigation " + id)
		var commission_night := 9
		if n == commission_night and route != "ignore":
			if route == "example": fixture(s, "commission")
			var cash := s._day.state.cash; var minute := s._day.state.game_minutes
			check(s.investigation_command("commission").ok, "commission " + route)
			check(s._day.state.cash == cash - 30 and s._day.state.game_minutes == minute + 10, "exact cost")
			check(not s.investigation_command("commission").ok, "no double commission")
			check(not s.investigation_command("read_report").ok, "no early report")
			verify(s, "commission " + route)
		if n == commission_night + 1 and route != "ignore":
			if route == "example": fixture(s, "report")
			check(s._day.state.investigation.delivered and not s._day.state.investigation.read, "delivered but sealed")
			check(s.investigation_command("read_report").ok, "read letter")
			check(s.investigation_command("book").ok, "book next night")
			check(not s.investigation_command("book").ok, "no duplicate appointment")
		for step in 200:
			if s._day.state.phase != &"open": break
			driver.drain(s)
			var returning := PawnReturnService.current(s._day.state)
			if not returning.is_empty():
				check(not s.companion_model().available, "Aqi quiet during redemption")
				check(s.counter_command(returning.command, returning.id).ok, "redemption coexists")
				redeemed = true
				continue
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				if n == 11 and FirstDebt.flag(s._day.state, "fd_receipt_read") and FirstDebt.last(s._day.state, "fd_lu").is_empty():
					for pair in [["fd_ticket", "read"], ["fd_lu", "ask"], ["fd_chen_request", "ask"]]: check(s.event_command(pair[0], pair[1]).ok, "coexist contact " + pair[0])
				if n == 12 and not FirstDebt.flag(s._day.state, "fd_family_read"):
					for pair in [["fd_family", "read"], ["fd_customer_ticket", "read"], ["fd_dragon", "buy"]]: check(s.event_command(pair[0], pair[1]).ok, "coexist delivery/investigation " + pair[0])
				if n == 13 and not FirstDebt.settled(s._day.state):
					for pair in [["fd_truth", "tell"], ["fd_settle", "return"]]: check(s.event_command(pair[0], pair[1]).ok, "coexist resolution " + pair[0])
				if not s.bell_model().enabled: break
				check(s.bell_command("wait").ok, "wait")
				continue
			var held := LivingMirror.held(s._day.state)
			if held != null:
				if s._risk.covered(s._day.state, held.instance_id): s.risk_command("uncover", held.instance_id)
				if v.expires_at <= s._day.state.game_minutes + 10: s.counter_command("swap_reject" if v.customer_id == GhostGuests.SWAP else "reject", v.visit_id); continue
				var scanned := s.inspect_customer(v.visit_id)
				check(scanned.ok, "life scan " + str(n) + " " + v.visit_id + ": " + scanned.message)
				check(s._day.state.soul_history.back().result == ("ghost" if v.night_policy == "wet_cloth" or v.customer_id in [GhostGuests.CLOSED, GhostGuests.SWAP] else "living"), "per visit life")
			if v.purpose == "husband_meeting":
				if route == "example": fixture(s, "meeting")
				check(v.item == null and v.person.id == InvestigationService.PERSON, "same person no watch")
				s.counter_model()
				check(not s.counter_command("offer", v.visit_id, "", 1).ok, "meeting cannot trade")
				check(not s.counter_command("meeting_question", v.visit_id, "contact").ok, "evidence order")
				for q in InvestigationService.QUESTIONS:
					check(s.counter_command("meeting_question", v.visit_id, q).ok, "question " + q)
					check(not s.counter_command("meeting_question", v.visit_id, q).ok, "no repeated answer")
					if route == "partial": break
				if route != "partial": fixture(s, "ready" if route == "example" else "ready-" + route)
				check(s.counter_command("meeting_end", v.visit_id).ok, "end meeting")
				if route == "partial":
					check(s.investigation_command("book").ok, "rebook partial")
					check(InvestigationService.appointment(s._day.state).night == 11, "next appointment remains pending")
				else: check(s.investigation_command("put_away").ok, "chapter attitude")
			elif v.customer_id == "fd_seller":
				check(s.observe_document("fd_receipt").ok and s.observe_document("fd_mark").ok, "ordinary seller with mirror held")
				check(s.counter_command("offer", v.visit_id, "", 100).ok, "unique acquisition coexists")
			elif n in [5, 6] and not pawned and s._counter.reason(s._day, "pawn", v.visit_id, "", v.trade.asking_price).is_empty() and (catalog.get_definition("pawn_terms", VarietyService.terms_for(v, catalog.get_definition("customers", v.customer_id))) as PawnTermsDefinition).return_mode == "redeem":
				check(s.counter_command("pawn", v.visit_id, "", v.trade.asking_price).ok, "live pawn coexist")
				pawned = true
			elif v.item.definition_id in ["intro_silver_hairpin", "item_weeping_mirror"]:
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "story purchase")
				driver.drain(s)
				if v.item.definition_id == "item_weeping_mirror": check(s.study_command("wm_notes", "read").ok, "mirror note")
			else:
				var result := s.counter_command("swap_reject" if v.customer_id == GhostGuests.SWAP else "reject", v.visit_id)
				check(result.ok or v.status == "timed_out", "ordinary or night guest refused " + route + " " + v.visit_id + ": " + result.message)
			if route == "sold" and n == 3 and s._day.state.game_minutes >= 360 and s._day.state.game_minutes < 450 and LivingMirror.held(s._day.state) != null:
				check(s.sell_batch("buyer_mirror", [LivingMirror.held(s._day.state).instance_id]).ok, "sold mirror route")
		var held := LivingMirror.held(s._day.state)
		if held != null and not s._risk.covered(s._day.state, held.instance_id): check(s.risk_command("cover", held.instance_id).ok, "cover")
		if s._day.state.phase == &"open": act(s, "close_shop")
		if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
		act(s, "resolve_night")
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		if n == 7: aqi_story(s, route)
		if AqiCompanion.enabled(run_def): driver.drain(s)
		act(s, "enter_room"); driver.drain(s)
		if n in [2, 5] and route != "ignore":
			fixture(s, "aq-room-" + str(n))
			var id := "aq_coat" if n == 2 else "aq_paper"
			check(s.observe_room(id).ok, "first observation " + id)
			var count := s._day.state.event_history.size()
			check(s.observe_room(id).ok and s._day.state.event_history.size() == count, "free repeat observation")
			verify(s, id)
		if n == 1: check(not s.observe_room("aq_coat").ok, "no early clue")
		act(s, "sleep"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		act(s, "finish_sleep"); act(s, "continue_run")
		if n == 7: check(s._day.state.current_night_index == 8, "seventh is not ending")
	check(s._day.state.phase == &"pre_open" and s._day.state.current_night_index == 14, "continues after thirteenth " + route)
	check(s._day.state.fee_history.size() == 13, "thirteen ordinary daily fees")
	if route == "late": check(not s._day.state.investigation.delivered and s._day.state.investigation.report_night == 11, "eleventh pending report")
	if route == "ignore": check(s._day.state.investigation.is_empty(), "optional investigation")
	verify(s, "ending " + route)
	if route == "example": fixture(s, "ending")

	check(FirstDebt.flag(s._day.state, "fd_clear"), "gold returned while mirror and husband investigation coexist")

func risk_after_case() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(reunion_fixture_dir + "ending.json"))
	var state := SaveCodec.new().decode(raw, run_def, 29, catalog, true)
	check(state != null, "restore closed case and real mirror")
	if state == null: return
	var s := fresh23(); s._day.state = state
	var held := LivingMirror.held(state)
	check(held != null, "case return does not consume mirror")
	if held == null: return
	for cycle in 3:
		if s._day.state.phase == &"dead": break
		driver.drain(s); act(s, "open_shop"); driver.drain(s)
		if s._risk.covered(s._day.state, held.instance_id): check(s.risk_command("uncover", held.instance_id).ok, "uncover actual mirror")
		act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night")
		check(not s._day.state.risk_pending.is_empty(), "closing crisis remains after case")
		check(not s.event_command("fd_chen_request", "ask").ok, "case action cannot bypass crisis")
		check(s.risk_command("defy", s._day.state.risk_pending).ok, "existing consequence")
		if s._day.state.phase == &"dead": break
		act(s, "enter_room"); driver.drain(s); act(s, "sleep")
		if not s._day.state.risk_pending.is_empty(): check(s.risk_command("defy", s._day.state.risk_pending).ok, "sleep consequence")
		if s._day.state.phase == &"dead": break
		driver.drain(s); act(s, "finish_sleep"); act(s, "continue_run")
	check(s._day.state.phase == &"dead", "case completion does not prevent death")
	check(not s.companion_model().visible and not s.can_execute("finish_trial"), "death hides companion and blocks trial escape")
	verify(s, "death after closed first debt")
