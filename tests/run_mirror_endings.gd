extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/mirror_ending_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v25 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	for seed_value in 64:
		var state := RunState.create(run_def); state.run_seed = seed_value
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		check(rows.size() == 60, "ten nights six seats")
		check(rows.filter(func(row: Dictionary) -> bool: return not row.get("night_policy", "").is_empty()).size() == 4, "four original night guests")
		check(rows.any(func(row: Dictionary) -> bool: return row.customer_id == GhostGuests.CLOSED and row.night == 4), "fourth night authored ghost protected")
	for route in ([] if "endings-only" in OS.get_cmdline_user_args() else ["example"] if "fixtures-only" in OS.get_cmdline_user_args() else ["early", "example", "partial", "late", "ignore", "sold"]):
		journey(route)
		if failures > 0: break
	endings()
	if "fixtures-only" not in OS.get_cmdline_user_args(): continuation()
	print("MIRROR ENDINGS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func fresh23() -> RunSession:
	var store := GhostReplayStore.new()
	store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 25, store, catalog)

func act(s: RunSession, command: String) -> void:
	var result := s.execute(command)
	check(result.ok, command + ": " + result.message)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 25)
	var restored := codec.decode(data, run_def, 25, catalog, true)
	check(restored != null, "replay " + label + ": " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)
	var forged := data.duplicate(true); forged.cash += 30
	check(codec.decode(forged, run_def, 25, catalog, true) == null, "cash forgery " + label)

func journey(route: String) -> void:
	var s := fresh23()
	for n in range(1, 11):
		driver.drain(s)
		act(s, "open_shop"); driver.drain(s)
		if n >= 7:
			for id in ["wm_ticket", "wm_life", "wm_identity", "wm_concealed", "wm_motive", "wm_choice"]:
				if id in s._day.state.narrative_flags or s._day.state.event_history.any(func(r: Dictionary) -> bool: return r.event_id == id): continue
				check(s.study_command(id, ("seek" if route == "sold" else "seal") if id == "wm_choice" else "read").ok, "late real investigation " + id)
		var commission_night := 8 if route in ["example", "partial"] else 10 if route == "late" else 7
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
			if not returning.is_empty(): s.counter_command(returning.command, returning.id); continue
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				if not s.bell_model().enabled: break
				check(s.bell_command("wait").ok, "wait")
				continue
			var held := LivingMirror.held(s._day.state)
			if held != null:
				if s._risk.covered(s._day.state, held.instance_id): s.risk_command("uncover", held.instance_id)
				if v.expires_at <= s._day.state.game_minutes + 10: s.counter_command("reject", v.visit_id); continue
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
			elif v.item.definition_id in ["intro_silver_hairpin", "item_weeping_mirror"]:
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "story purchase")
				driver.drain(s)
				if v.item.definition_id == "item_weeping_mirror": check(s.study_command("wm_notes", "read").ok, "mirror note")
			else:
				var result := s.counter_command("reject", v.visit_id)
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
	check(s._day.state.phase == &"run_ended" and s._day.state.current_night_index == 10, "ten night ending " + route)
	check(s._day.state.fee_history.size() == 10, "ten ordinary daily fees")
	if route == "late": check(not s._day.state.investigation.delivered and s._day.state.investigation.report_night == 11, "eleventh pending report")
	if route == "ignore": check(s._day.state.investigation.is_empty(), "optional investigation")
	verify(s, "ending " + route)
	if route == "example": fixture(s, "ending")

func fixture(s: RunSession, stage: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/v25"))
	var file := FileAccess.open("res://.godot/qa/v25/" + stage + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 25)))

func aqi_story(s: RunSession, route: String) -> void:
	check(s._day.state.pending_event_id == "aq_arrival", "seventh night arrival " + route)
	check(not s.execute("enter_room").ok, "no upstairs shortcut")
	var cash := s._day.state.cash
	var inventory := s._day.state.inventory_instances.size()
	for step in 15:
		var model := s.event_model()
		if model.pending_id.is_empty(): break
		fixture(s, "aq-" + route + "-" + model.pending_id)
		var choice: String = model.buttons[0].detail
		if model.pending_id == "aq_arrival" and route in ["early", "partial"]: choice = "name"
		if model.pending_id == "aq_name" and route == "partial": choice = "decline"
		if model.pending_id == "aq_repaired":
			check(model.buttons.any(func(b: Dictionary) -> bool: return b.detail == "paper") == (route != "ignore"), "paper choice based on discovery")
			if route == "example": choice = "paper"
		check(s.event_command(model.pending_id, choice).ok, "Aqi choice " + model.pending_id)
		var count := s._day.state.event_history.size()
		check(not s.event_command(model.pending_id, choice).ok and s._day.state.event_history.size() == count, "duplicate story intent ignored")
		verify(s, "Aqi " + route + " " + model.pending_id)
	check(s._day.state.pending_event_id.is_empty(), "Aqi finishes")
	check(s._day.state.cash == cash and s._day.state.inventory_instances.size() == inventory, "story changes no cash or inventory")
	check("aq_met" in s._day.state.narrative_flags, "met flag")
	check(("aq_helped" in s._day.state.narrative_flags) == (route != "partial"), "help versus decline")
	var codec := SaveCodec.new()
	var forged := codec.encode(s._day.state, 25)
	forged.narrative_flags.append("aq_forged")
	check(codec.decode(forged, run_def, 25, catalog, true) == null, "reject unjournaled flag")

class FailingStore extends GhostReplayStore:
	var writes := 0
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		writes += 1
		error_message = "Injected write failure"
		return false

func load_ready(stage := "ready") -> RunSession:
	var s := fresh23()
	var codec := SaveCodec.new()
	s._day.state = codec.decode(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v25/" + stage + ".json")), run_def, 25, catalog, true)
	check(s._day.state != null, "load fixture " + codec.error_message)
	return s

func end_act(s: RunSession, action: String) -> ActionResult:
	return s.mirror_resolution_command(action, s._counter.customers.active(s._day.state).visit_id)

func endings() -> void:
	for ending in MirrorEndingService.ENDINGS:
		var s := load_ready()
		var visit := s._counter.customers.active(s._day.state)
		var mirror := LivingMirror.held(s._day.state)
		var minute := s._day.state.game_minutes
		check(not end_act(s, "evidence").ok, "no skipped opening")
		check(end_act(s, "start").ok, "start confrontation")
		check(not s.execute("wait_5").ok and not s.counter_command("meeting_end", visit.visit_id).ok and not s.inspect_customer(visit.visit_id).ok, "active dialogue blocks unrelated actions")
		check(s.risk_model().requires_response, "active reminder model")
		check(end_act(s, "gentle" if ending == "acknowledged" else "force").ok, "attitude determined")
		fixture(s, "willing" if ending == "acknowledged" else "refused")
		check(not end_act(s, "force" if ending == "acknowledged" else "gentle").ok, "cannot reroll attitude")
		check(end_act(s, "pause").ok and not s.risk_model().requires_response, "explicit pause clears reminder")
		verify(s, "paused")
		check(end_act(s, "start").ok, "resume")
		check(end_act(s, "evidence").ok, "wife hears facts")
		var before := s.read_state()
		for wrong in MirrorEndingService.ENDINGS:
			if wrong == ending or (ending != "acknowledged" and wrong != "acknowledged"): continue
			check(not end_act(s, wrong).ok and s.read_state() == before, "branch cannot be forged")
		var fail := FailingStore.new()
		s._save = fail
		check(not end_act(s, ending).ok and s.read_state() == before and fail.writes == 1, "terminal write failure rolls everything back")
		s._save = GhostReplayStore.new()
		check(end_act(s, ending).ok, "ending " + ending)
		check(s._day.state.game_minutes == minute + 15, "three paid stages only")
		check(s._day.state.mirror_resolution.ending == ending, "correct ending")
		before = s.read_state()
		check(not s.mirror_resolution_command(ending, visit.visit_id).ok and s.read_state() == before, "no duplicate ending")
		check(not s.investigation_command("book").ok, "no appointment after ending")
		check(s._day.state.special_resources.size() == (1 if ending == "resentment" else 0), "resource exactly once")
		check(s._day.state.person_deaths.size() == (1 if ending == "resentment" else 0), "only revenge kills")
		check(s._day.state.death_archive.is_empty(), "NPC absent from player death archive")
		check(s._risk.ghosts(s._day.state).any(func(item: ItemInstance) -> bool: return item.instance_id == mirror.instance_id) == (ending == "resentment"), "storage rules follow ending")
		if ending == "resentment":
			check(s._day.state.visits.filter(func(v: CustomerVisit) -> bool: return v.visit_id == visit.visit_id)[0].status == "mirror_revenge", "dead husband left counter")
			check(s._day.state.person_deaths[0].source == "mirror_revenge", "death source explicit")
			check(GhostGuests.notice(s._day.state, catalog).is_empty(), "no next-day swap notice for revenge")
		else:
			check(not s.inspect_customer(visit.visit_id).ok and not s.risk_command("cover", mirror.instance_id).ok, "ordinary mirror powers disabled")
			check(s._counter.customers.active(s._day.state).visit_id == visit.visit_id, "husband alive after release")
		check(not s.seven_notice().contains("等待尚未了结"), "summary honors resolution")
		verify(s, ending)
		fixture(s, ending)
		var data := SaveCodec.new().encode(s._day.state, 25)
		for key in ["mirror_resolution", "special_resources", "person_deaths"]:
			var forged := data.duplicate(true)
			if key == "mirror_resolution": forged[key].husband = "willing" if ending != "acknowledged" else "refused"
			else: forged[key].append({"forged": true})
			check(SaveCodec.new().decode(forged, run_def, 25, catalog, true) == null, "reject forged " + key)
		for key in ["step", "ending", "mirror_id", "night", "minute", "ability"]:
			var forged := data.duplicate(true)
			forged.mirror_resolution[key] = 999 if key in ["step", "night", "minute"] else "forged"
			check(SaveCodec.new().decode(forged, run_def, 25, catalog, true) == null, "reject forged resolution " + key)
	# Domain preconditions: no time, no mirror, unresolved pursuit, wrong visitor.
	for mode in ["time", "closing", "sold", "pursuit", "identity", "materials"]:
		var s := load_ready()
		var v := s._counter.customers.active(s._day.state)
		match mode:
			"time": v.expires_at = s._day.state.game_minutes + 14
			"closing": s._day.state.game_minutes = 530; v.expires_at = 600
			"sold": LivingMirror.held(s._day.state).ownership_state = "sold"
			"pursuit": s._day.state.mirror_history.append({"action": "pursue", "night": s._day.state.current_night_index})
			"identity": v.person.id = "ordinary/hawker"
			"materials": s._day.state.investigation.read = false
		var before := s.read_state()
		check(not end_act(s, "start").ok and s.read_state() == before, "precondition no mutation " + mode)
	var s := load_ready()
	check(end_act(s, "start").ok and end_act(s, "force").ok and end_act(s, "pause").ok, "pause after refusal")
	var v := s._counter.customers.active(s._day.state)
	check(s.counter_command("meeting_end", v.visit_id).ok and s.investigation_command("book").ok, "rebook after all prior questions")
	check(InvestigationService.appointment(s._day.state).night == 11 and s._day.state.mirror_resolution.husband == "refused", "eleventh pending no attitude reset")
	verify(s, "rebook eleven")

func pass_night(s: RunSession) -> void:
	if s._day.state.phase == &"open": act(s, "close_shop")
	if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
	act(s, "resolve_night")
	if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "resolve retained taboo")
	act(s, "enter_room"); driver.drain(s)
	act(s, "sleep"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "personal response")
	act(s, "finish_sleep"); act(s, "continue_run")

func continuation() -> void:
	# Resume on a genuinely new appointment without re-paying or resetting attitude.
	var s := load_ready("ready-early")
	check(s._day.state.current_night_index == 9, "confrontation allowed before tenth")
	check(end_act(s, "start").ok and end_act(s, "force").ok and end_act(s, "pause").ok, "early partial confrontation")
	var old_id := s._counter.customers.active(s._day.state).visit_id
	check(s.counter_command("meeting_end", old_id).ok and s.investigation_command("book").ok, "next night resumed appointment")
	var mirror_id := LivingMirror.held(s._day.state).instance_id
	check(s.risk_command("cover", mirror_id).ok, "cover paused mirror")
	pass_night(s)
	act(s, "open_shop"); driver.drain(s)
	for i in 100:
		var v := s._counter.customers.active(s._day.state)
		if v != null and v.purpose == "husband_meeting": break
		if v == null: s.bell_command("wait")
		else: s.counter_command("reject", v.visit_id)
	var v := s._counter.customers.active(s._day.state)
	check(v != null and v.purpose == "husband_meeting" and v.visit_id != old_id and v.person.id == InvestigationService.PERSON, "fixed person independent resumed visit")
	var start := s._day.state.game_minutes
	check(end_act(s, "start").ok and end_act(s, "evidence").ok and end_act(s, "released").ok, "complete refused route after rebooking")
	check(s._day.state.game_minutes == start + 10, "only remaining two stages paid")
	verify(s, "resumed next night")
	for ending in MirrorEndingService.ENDINGS:
		s = load_ready(ending)
		mirror_id = LivingMirror.held(s._day.state).instance_id
		# Advance ordinary arrivals through actual commands to the existing buyer window.
		for i in 100:
			v = s._counter.customers.active(s._day.state)
			if v != null:
				if ending == "resentment":
					if s._risk.covered(s._day.state, mirror_id): s.risk_command("uncover", mirror_id)
					check(s.inspect_customer(v.visit_id).ok, "resentful mirror still scans normally")
				check(s.counter_command("meeting_end" if v.purpose == "husband_meeting" else "reject", v.visit_id).ok, "business resumes after ending")
			elif s._day.state.game_minutes >= 360: break
			else: check(s.bell_command("wait").ok, "reach buyer after ending")
		var resources := s._day.state.special_resources.duplicate(true)
		var damage := s._day.state.personal_damage
		check(s.sell_batch("buyer_mirror" if ending == "resentment" else "buyer_recycler", [mirror_id]).ok, "mirror can be sold " + ending)
		check(s._day.state.special_resources == resources and s._day.state.personal_damage == damage, "sale keeps resource and injuries")
		check(LivingMirror.held(s._day.state) == null, "mirror handed over")
		pass_night(s)
		check(s._day.state.phase == &"run_ended" and s._day.state.current_night_index == 10, "ending preserves ten night cap")
		verify(s, "sold and completed " + ending)
	# Retained taboo still produces its own crisis, not the ending page.
	s = load_ready("resentment")
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night")
	check(not s._day.state.risk_pending.is_empty() and s.risk_model().body.contains("别应声"), "resentment future crisis retains warning")
	verify(s, "resentment uncovered crisis")
