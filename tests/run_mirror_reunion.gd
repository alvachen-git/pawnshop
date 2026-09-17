extends "res://tests/run_integrated_seven.gd"

var test_seed := 42
var reunion_manifest := "res://data/mirror_reunion_manifest.json"
var reunion_fixture_dir := "res://.godot/qa/v26/"

func run() -> void:
	var loaded := JsonContentProvider.new(reunion_manifest).load_catalog()
	check(loaded.is_success(), "v26 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false
	driver.check = check; driver.catalog = catalog
	if "entry-only" in OS.get_cmdline_user_args():
		entry_checks()
		print("REUNION ENTRY: %d passes, %d failures" % [passes, failures])
		quit(0 if failures == 0 else 1)
		return
	var seeds: Array[int] = []
	for value in 1000:
		if seeds.is_empty() and MirrorReunionService.roll(value) < 40: seeds.append(value)
		elif seeds.size() == 1 and MirrorReunionService.roll(value) >= 60: seeds.append(value); break
	for value in seeds:
		test_seed = value; run_def._seed = value
		journey("example")
		var ready := load_ready()
		fixture(ready, "ready-apology" if MirrorReunionService.roll(value) < 40 else "ready-angry")
	if "fixtures-only" not in OS.get_cmdline_user_args():
		journey("ignore")
		journey("late")
		journey("early")
	endings()
	entry_checks()
	if "fixtures-only" not in OS.get_cmdline_user_args(): continuation()
	print("MIRROR REUNION: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func fresh23() -> RunSession:
	var store := GhostReplayStore.new()
	store.origin = {"seed": test_seed, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, catalog.content_version, store, catalog)

func act(s: RunSession, command: String) -> void:
	var result := s.execute(command)
	check(result.ok, command + ": " + result.message)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, catalog.content_version)
	var restored := codec.decode(data, run_def, catalog.content_version, catalog, true)
	check(restored != null, "replay " + label + ": " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)
	var forged := data.duplicate(true); forged.cash += 30
	check(codec.decode(forged, run_def, catalog.content_version, catalog, true) == null, "cash forgery " + label)

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
	check(s._day.state.phase == &"run_ended" and s._day.state.current_night_index == 10, "ten night ending " + route)
	check(s._day.state.fee_history.size() == 10, "ten ordinary daily fees")
	if route == "late": check(not s._day.state.investigation.delivered and s._day.state.investigation.report_night == 11, "eleventh pending report")
	if route == "ignore": check(s._day.state.investigation.is_empty(), "optional investigation")
	verify(s, "ending " + route)
	if route == "example": fixture(s, "ending")

func fixture(s: RunSession, stage: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(reunion_fixture_dir))
	var file := FileAccess.open(reunion_fixture_dir + stage + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, catalog.content_version)))

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
	var forged := codec.encode(s._day.state, catalog.content_version)
	forged.narrative_flags.append("aq_forged")
	check(codec.decode(forged, run_def, catalog.content_version, catalog, true) == null, "reject unjournaled flag")

class FailingStore extends GhostReplayStore:
	var writes := 0
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		writes += 1
		error_message = "Injected write failure"
		return false

func load_ready(stage := "ready") -> RunSession:
	var s := fresh23()
	var codec := SaveCodec.new()
	s._day.state = codec.decode(JSON.parse_string(FileAccess.get_file_as_string(reunion_fixture_dir + stage + ".json")), run_def, catalog.content_version, catalog, true)
	check(s._day.state != null, "load fixture " + codec.error_message)
	return s

func end_act(s: RunSession, action: String) -> ActionResult:
	return s.mirror_resolution_command(action, s._counter.customers.active(s._day.state).visit_id)

func endings() -> void:
	check(MirrorReunionService.reaction("press", 59) == "apology" and MirrorReunionService.reaction("press", 60) == "angry", "press exact 60 boundary")
	check(MirrorReunionService.reaction("mediate", 39) == "apology" and MirrorReunionService.reaction("mediate", 40) == "evasive", "mediate exact 40 boundary")
	for approach in ["press", "mediate"]:
		var count := 0
		for value in 100:
			if MirrorReunionService.reaction(approach, value) == "apology": count += 1
		check(count == (60 if approach == "press" else 40), "all probability buckets")
	for ending in MirrorReunionService.ENDINGS:
		var s := load_ready("ready-apology" if ending == "acknowledged" else "ready-angry")
		var id: String = s._counter.customers.active(s._day.state).visit_id
		var mirror := LivingMirror.held(s._day.state)
		var start := s._day.state.game_minutes
		check(not end_act(s, ending).ok, "no premature ending")
		check(end_act(s, "start").ok, "start")
		var roll_value: int = s._day.state.mirror_resolution.roll
		check(end_act(s, "pause").ok and end_act(s, "start").ok, "pause and resume before reveal")
		check(roll_value == s._day.state.mirror_resolution.roll, "no reroll after resume")
		check(end_act(s, "reveal").ok, "reveal")
		check(not end_act(s, "reveal").ok, "no repeated reveal cost")
		check(not s.execute("wait_until_seal").ok, "other business blocked")
		check(end_act(s, "mediate" if ending == "disappointed" else "press").ok, "intervention")
		check(end_act(s, "pause").ok and end_act(s, "start").ok, "pause after fixed reaction")
		check(s._day.state.mirror_resolution.roll == roll_value and s._day.state.game_minutes == start + 10, "two paid stages")
		fixture(s, {"acknowledged": "apology", "released": "angry", "resentment": "angry", "disappointed": "evasive"}[ending])
		verify(s, "fixed reaction")
		var before := s.read_state()
		for key in ["roll", "husband", "step", "approach"]:
			var data := SaveCodec.new().encode(s._day.state, catalog.content_version)
			data.mirror_resolution[key] = 99 if key in ["roll", "step"] else "forged"
			check(SaveCodec.new().decode(data, run_def, catalog.content_version, catalog, true) == null, "reject " + key)
		for wrong in MirrorReunionService.ENDINGS:
			if wrong in ["released", "resentment"] and ending in ["released", "resentment"]: continue
			if wrong != ending: check(not end_act(s, wrong).ok and s.read_state() == before, "reject wrong branch")
		var old_store := s._save
		var failed := FailingStore.new()
		s._save = failed
		check(not end_act(s, ending).ok, "failed final save")
		check(failed.writes == 1 and s.read_state() == before, "full atomic rollback")
		s._save = old_store
		check(end_act(s, ending).ok, "complete " + ending)
		check(s._day.state.game_minutes == start + 15, "three stages exactly 15 minutes")
		check(s._day.state.special_resources.size() == (1 if ending == "resentment" else 0), "resource once")
		check(s._day.state.person_deaths.size() == (1 if ending == "resentment" else 0), "specific husband death only")
		check(s._day.state.death_archive.is_empty(), "no player death entry")
		check(s._risk.ghosts(s._day.state).any(func(item: ItemInstance) -> bool: return item.instance_id == mirror.instance_id) == (ending == "resentment"), "storage rule follows actual ending")
		check(not s.investigation_command("book").ok, "no new husband appointment")
		var terminal := s.read_state()
		check(not s.mirror_resolution_command(ending, id).ok and s.read_state() == terminal, "no duplicate final or rewards")
		verify(s, ending)
		for field in ["ending", "ability", "notification_delivered"]:
			var forged := SaveCodec.new().encode(s._day.state, catalog.content_version)
			forged.mirror_resolution[field] = false if field == "notification_delivered" else "forged"
			check(SaveCodec.new().decode(forged, run_def, catalog.content_version, catalog, true) == null, "reject forged " + field)
		for field in ["special_resources", "person_deaths"]:
			var forged := SaveCodec.new().encode(s._day.state, catalog.content_version)
			forged[field].append({"id": "forged"})
			check(SaveCodec.new().decode(forged, run_def, catalog.content_version, catalog, true) == null, "reject forged " + field)
		fixture(s, ending)
	# Reading all pre-ending presentation data cannot expose ability or reward.
	for action in ["reveal", "press", "mediate", "apology", "angry", "evasive"]:
		for page in MirrorReunionService.PAGES[action]:
			check(not page[1].contains("怨气") and not page[1].contains("能力") and not page[1].contains("铜胎"), "no early reward disclosure")
	var s := load_ready("ready-angry")
	var visit := s._counter.customers.active(s._day.state)
	visit.expires_at = s._day.state.game_minutes + 15
	var before := s.read_state()
	check(not end_act(s, "start").ok and s.read_state() == before, "insufficient husband time no cost")
	s = load_ready("ready-angry")
	s._day.state.game_minutes = s.definition.night_minutes - 15
	before = s.read_state()
	check(not end_act(s, "start").ok and s.read_state() == before, "seal time insufficient no cost")
	s = load_ready("ready-apology")
	check(end_act(s, "start").ok and end_act(s, "reveal").ok and end_act(s, "mediate").ok, "mediation can produce apology")
	check(s._day.state.mirror_resolution.husband == "apology", "second apology approach")

func entry_checks() -> void:
	for channel in ["counter", "risk"]:
		var s := load_ready("ready-apology")
		var id: String = s._counter.customers.active(s._day.state).visit_id
		var start := s._day.state.game_minutes
		var result := s.counter_command("ending_begin", id) if channel == "counter" else s.risk_command("ending_begin", id)
		check(result.ok and s._day.state.mirror_resolution.step == 1, "one entry reveals " + channel)
		check(s._day.state.game_minutes == start + 5 and s._day.state.mirror_resolution.history.size() == 1, "single first-stage charge")
		var before := s.read_state()
		check(not end_act(s, "begin").ok and s.read_state() == before, "repeat entry rejected without charge")
		verify(s, "atomic entry " + channel)
		check(end_act(s, "pause").ok, "pause after entry")
		var entry := MirrorReunionService.entry_button(s._day, catalog, id)
		check(entry.command == "ending_start" and entry.label == "继续镜前的话", "resume uses free continuation")
		check(end_act(s, "start").ok and s._day.state.game_minutes == start + 5, "resume does not repeat reveal")
		verify(s, "entry resumed " + channel)
	var s := load_ready("ready-apology")
	s._counter.customers.active(s._day.state).expires_at = s._day.state.game_minutes + 14
	var before := s.read_state()
	check(not end_act(s, "begin").ok and s.read_state() == before, "entry insufficient time does not initialize or charge")


func pass_night(s: RunSession) -> void:
	if s._day.state.phase == &"open": act(s, "close_shop")
	if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
	act(s, "resolve_night")
	if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "resolve retained taboo")
	if AqiCompanion.enabled(run_def): driver.drain(s)
	act(s, "enter_room"); driver.drain(s)
	act(s, "sleep"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "personal response")
	act(s, "finish_sleep"); act(s, "continue_run")

func continuation() -> void:
	# Resume on a genuinely new appointment without re-paying or resetting attitude.
	var s := load_ready("ready-early")
	check(s._day.state.current_night_index == 9, "confrontation allowed before tenth")
	check(end_act(s, "start").ok and end_act(s, "reveal").ok and end_act(s, "pause").ok, "early partial confrontation")
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
	check(end_act(s, "start").ok and end_act(s, "press").ok and end_act(s, "released").ok, "complete refused route after rebooking")
	check(s._day.state.game_minutes == start + 10, "only remaining two stages paid")
	verify(s, "resumed next night")
	for ending in MirrorReunionService.ENDINGS:
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
