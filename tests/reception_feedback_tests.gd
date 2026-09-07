extends SceneTree
var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var helper := BargainingTests.new()
	helper.setup(check)
	for mode in ["patience", "rounds", "timeout", "wait_timeout", "purchase", "pawn", "reject"]:
		var s := helper.session()
		check(s._save.save_state(s._day.state, s.definition, helper.catalog.content_version), "initial checkpoint")
		helper.open(s)
		var old := helper.active(s)
		var next: CustomerVisit = s._day.state.visits[1]
		# Controlled queue fixture; real counter commands perform every departure.
		next.status = "waiting"
		next.expires_at = 500
		match mode:
			"patience":
				old.customer_id = "customer_scholar"
				old.trade.patience = 2
				helper.action(s, "belittle")
			"rounds":
				old.trade.rounds_left = 1
				helper.action(s, "belittle")
			"timeout":
				s._day.state.game_minutes = old.expires_at - 5
				s.counter_command("belittle", old.visit_id)
			"wait_timeout":
				s._day.state.game_minutes = old.expires_at - 5
				s.execute("short_task")
			"purchase": helper.action(s, "offer", "", old.trade.asking_price)
			"pawn": helper.action(s, "pawn", "", 40)
			"reject": helper.action(s, "reject")
		check(helper.active(s) == next, "handoff " + mode)
		var previous_feedback := s.message
		check(not previous_feedback.is_empty(), "operation result preserved " + mode)
		var model := s.counter_model()
		for feature in ["dialogue", "appraisal", "trade"]:
			check(model[feature].visual.message.is_empty() and not model[feature].body.contains(previous_feedback), "no previous response in " + feature + mode)
		check(model.trade.asking_price == next.trade.asking_price, "new asking price independent")
		var before := s.read_state()
		s.counter_model(); s.changed.emit()
		check(s.read_state() == before, "rendering has no gameplay effects")
		s.counter_command("belittle", old.visit_id)
		check(s.counter_model().dialogue.visual.message.is_empty() and s.read_state() == before, "repeated old command cannot pollute new reception")
		helper.action(s, "belittle")
		check(s.counter_model().trade.visual.message == s.message and not s.message.is_empty(), "own feedback remains visible")
		s.counter_command("appraise", next.visit_id, "missing")
		check(s.counter_model().appraisal.visual.message == s.message, "own validation error remains visible")
		check(s.load_checkpoint().ok and s._message_visit_id.is_empty(), "load resets transient ownership")
		s.new_run()
		check(s._message_visit_id.is_empty(), "new run clears ownership")
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RECEPTION FEEDBACK TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
