extends SceneTree

var failures := 0
var assertions := 0
var helper := BargainingTests.new()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	helper.setup(check)
	for command in ["offer", "pawn"]:
		for remaining in [5, 1]:
			for accepted in [true, false]: boundary(command, remaining, accepted)
		for accepted in [true, false]:
			checkpoint(command, accepted, false)
			checkpoint(command, accepted, true)
	guards()
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("QUOTE DEADLINE TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func threshold(s: RunSession, v: CustomerVisit, command: String) -> int:
	if command == "offer": return v.trade.reserve_price
	var customer := helper.catalog.get_definition("customers", v.customer_id) as CustomerDefinition
	var terms := helper.catalog.get_definition("pawn_terms", VarietyService.terms_for(v, customer)) as PawnTermsDefinition
	return maxi(1, roundi(v.trade.reserve_price * terms.loan_ratio))

func boundary(command: String, remaining: int, accepted: bool) -> void:
	var s := helper.session()
	helper.open(s)
	var v := helper.active(s)
	var start := s._day.state.game_minutes
	v.expires_at = start + remaining
	v.voice.refused = "这个价钱不成。"
	v.voice.timed_out = "我得走了，改日再说。"
	v.trade.rounds_left = 1
	v.trade.patience = 1
	# Another waiting customer still expires, and a third takes the freed counter.
	var waiting := CustomerVisit.new()
	waiting.visit_id = "test/waiting"
	waiting.customer_id = v.customer_id
	waiting.item = v.item
	waiting.status = "waiting"
	waiting.expires_at = start + 5
	s._day.state.visits.append(waiting)
	var next := CustomerVisit.new()
	next.visit_id = "test/next"
	next.customer_id = v.customer_id
	next.item = v.item
	next.status = "waiting"
	next.expires_at = start + 60
	s._day.state.visits.append(next)
	var observer := CustomerDeparturePresenter.new()
	root.add_child(observer)
	var notices: Array = []
	observer.departed.connect(func(n: Dictionary) -> void: notices.append(n))
	observer.bind(s)
	var cash := s._day.state.cash
	var amount := threshold(s, v, command) - (0 if accepted else 1)
	var result := s.counter_command(command, v.visit_id, "", amount)
	check(result.ok and s._day.state.game_minutes == start + 5, "quote resolves once and costs five minutes")
	check(v.trade.offers == [amount], "quote is evaluated before expiry")
	check(waiting.status == "timed_out" and helper.active(s) == next, "other customers expire and next customer activates normally")
	check(v.status == (("bought" if command == "offer" else "pawned") if accepted else "timed_out"), "correct terminal outcome")
	check(s._day.state.cash == cash - (amount if accepted else 0), "one payment only for accepted quote")
	check(s._day.state.inventory_instances.size() == (1 if accepted else 0), "ownership only after acceptance")
	check(s._day.state.pawn_tickets.size() == (1 if accepted and command == "pawn" else 0), "pawn ticket only after acceptance")
	check(notices.size() == 1, "single grouped departure notice")
	if not accepted:
		check(result.message.find(v.voice.refused) < result.message.find(v.voice.timed_out), "refusal before original departure dialogue")
		check(notices[0].detail.contains(v.voice.refused + "\n等候期限已到") and notices[0].detail.contains(v.voice.timed_out), "departure presentation retains both replies")
	else:
		check(notices[0].item != helper.catalog.get_definition("items", v.item.definition_id).display_name and not notices[0].note.contains(v.voice.refused), "successful customer has no refusal notice")
	var before := s.read_state()
	check(not s.counter_command(command, v.visit_id, "", amount).ok and before == s.read_state(), "duplicate quote has no effect")
	s.changed.emit()
	check(notices.size() == 1, "refresh cannot repeat departure")
	observer.free()

func checkpoint(command: String, accepted: bool, legacy: bool) -> void:
	var s := helper.session()
	helper.open(s)
	var v := helper.active(s)
	helper.wait_to(s, v.expires_at - 5)
	s._counter.quote_before_timeout = not legacy
	var result := s.counter_command(command, v.visit_id, "", threshold(s, v, command) - (0 if accepted else 1))
	check(result.ok == not legacy, "record old or corrected quote outcome")
	helper.seal(s)
	helper.resume(s, "deadline quote %s accepted=%s legacy=%s" % [command, accepted, legacy])
	var fresh := RunSession.new(helper.run_def, helper.catalog.content_version, s._save, helper.catalog)
	check(fresh.load_checkpoint().ok and fresh.read_state() == s.read_state(), "fresh session restores deadline outcome")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s._save.path))
	if accepted and not legacy:
		for row in raw.visit_history:
			if row.visit_id == v.visit_id: row.minute += 5
		check(SaveCodec.new().decode(raw, helper.run_def, helper.catalog.content_version, helper.catalog) == null, "cannot forge a quote starting after expiry")

func guards() -> void:
	for kind in ["expired", "cash", "zero", "inspection", "seal"]:
		var s := helper.session()
		helper.open(s)
		var v := helper.active(s)
		var command := "offer"
		var detail := ""
		var amount := v.trade.reserve_price
		match kind:
			"expired": v.expires_at = s._day.state.game_minutes
			"cash": amount = s._day.state.cash + 1
			"zero": amount = 0
			"inspection":
				v.expires_at = s._day.state.game_minutes + 5
				command = "appraise"; detail = "observe"
			"seal":
				s._day.state.game_minutes = s.definition.night_minutes - 5
				v.expires_at = s.definition.night_minutes
		var before := s.read_state()
		check(not s.counter_command(command, v.visit_id, detail, amount).ok, "guard: " + kind)
		check(s._day.state.cash == before.cash and s._day.state.inventory_instances.is_empty(), "guard never acquires or pays: " + kind)
		if kind in ["expired", "cash", "zero"]: check(s.read_state() == before, "invalid start never spends time: " + kind)
		if kind == "inspection": check(v.item.revealed_clue_ids.is_empty() and v.status == "timed_out", "inspection retains original expiry rule")
		if kind == "seal": check(v.status == "shop_closed", "sealing priority retained")
