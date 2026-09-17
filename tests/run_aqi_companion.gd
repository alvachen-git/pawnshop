extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/aqi_companion_manifest.json").load_catalog()
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
	for route in (["example"] if "fixtures-only" in OS.get_cmdline_user_args() else ["early", "example", "partial", "late", "ignore", "sold"]):
		journey(route)
		if failures > 0: break
	print("AQI COMPANION: %d passes, %d failures" % [passes, failures])
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
		if n == 7:
			check(not s.companion_model().visible and not s.event_model().pending_id.begins_with("aq_"), "no preparation spoiler")
			fixture(s, "pre-open-7")
		act(s, "open_shop")
		if n >= 7: opening_story(s, route)
		driver.drain(s)
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
				if n >= 8: daily(s, route)
				if not s.bell_model().enabled: break
				check(s.bell_command("wait").ok, "wait")
				continue
			if n >= 8 and s._day.state.game_minutes < 240:
				check(s.companion_model().visible == (route != "ignore" and not (route == "partial" and n == 8) and not (route == "early" and n == 8)), "companion while customer")
				if route == "example": fixture(s, "customer-" + str(n))
				var before := s.read_state()
				check(not s.event_command("aq_chat_%d" % n, "talk").ok and s.read_state() == before, "busy cannot chat")
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
		if n in [7, 10]: closing_story(s, route)
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

func opening_story(s: RunSession, route: String) -> void:
	var n := s._day.state.current_night_index
	if n == 7: check(s.event_model().pending_id == "aq_arrival" and s._day.state.game_minutes == 0, "opening first meeting")
	var visits := s._day.state.visits.size()
	story(s, route)
	check(s._day.state.game_minutes == 0 and visits == s._day.state.visits.size(), "story preserves opening time and visitors")
	if n == 7: check(not s.companion_model().visible and "aq_departed" in s._day.state.narrative_flags, "first visit leaves")

func closing_story(s: RunSession, route: String) -> void:
	check(s.event_model().pending_id == ("aq_ledger" if s._day.state.current_night_index == 7 else "aq_old_ticket"), "independent closing story")
	check(not s.execute("enter_room").ok, "closing cannot be skipped")
	story(s, route)
	if s._day.state.current_night_index == 10:
		check("陈阿福" in s.old_debt_model().text, "ticket in old affairs")
		check(("残笔" in s.old_debt_model().text) == (route != "ignore"), "unknown comparison stays unknown")

func story(s: RunSession, route: String) -> void:
	var cash := s._day.state.cash
	for step in 20:
		var m := s.event_model()
		if not m.pending_id.begins_with("aq_"): break
		fixture(s, route + "-" + m.pending_id)
		var c: String = m.buttons[0].detail
		if m.pending_id == "aq_arrival" and route in ["early", "partial"]: c = "name"
		if m.pending_id == "aq_name" and route == "partial": c = "decline"
		if m.pending_id == "aq_repaired":
			check(m.buttons.any(func(b: Dictionary) -> bool: return b.detail == "paper") == (route != "ignore"), "paper requires discovery")
		if m.pending_id.begins_with("aq_return_"):
			check(("自己拨" in m.text) == (route == "partial"), "second visit respects first outcome")
		if m.pending_id.begins_with("aq_stay_"):
			if route == "ignore" or (route == "partial" and s._day.state.current_night_index == 8): c = "later"
			elif route == "partial": c = "careful"
		if m.pending_id == "aq_drawer" and route == "ignore": c = "skip"
		if m.pending_id == "aq_old_ticket" and route == "ignore": c = "keep"
		check(s.event_command(m.pending_id, c).ok, "story choice " + m.pending_id)
		var count := s._day.state.event_history.size()
		check(not s.event_command(m.pending_id, c).ok and count == s._day.state.event_history.size(), "no duplicate " + m.pending_id)
		verify(s, m.pending_id)
	check(cash == s._day.state.cash, "story free")

func daily(s: RunSession, route: String) -> void:
	var m := s.companion_model()
	if not m.available: return
	var n := s._day.state.current_night_index
	if route == "example" and m.topics[0].chosen.is_empty(): fixture(s, "idle-" + str(n))
	for topic in m.topics:
		if topic.topic == "leave" or not topic.chosen.is_empty(): continue
		var before := s.read_state()
		var c: String = topic.buttons[0].detail
		if topic.id == "aq_paper_9" and route == "partial": c = "bird"
		check(s.event_command(topic.id, c).ok, "daily " + topic.id)
		check(s._day.state.pending_event_id.is_empty() and s._day.state.game_minutes == before.game_minutes and s._day.state.cash == before.cash, "nonblocking free daily")
		check(s._day.state.event_history.size() == before.event_history.size() + 1, "one daily history")
		before = s.read_state()
		check(not s.event_command(topic.id, c).ok and s.read_state() == before, "duplicate daily unchanged")
		check(s.companion_model().topics.any(func(t: Dictionary) -> bool: return t.id == topic.id and t.chosen == c and t.buttons.is_empty()), "reread chosen response")
		verify(s, topic.id)
	if route == "early" and n == 8:
		check(s.event_command("aq_leave_8", "leave").ok and not s.companion_model().visible, "dismiss today")
