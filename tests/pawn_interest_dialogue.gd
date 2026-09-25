extends "res://tests/pawn_interest_contracts.gd"

func run() -> void:
	if not setup(): quit(1); return
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/pawn-v45/pawn-visit.json"))
	var s := restore_payload(payload)
	var v := s._counter.customers.active(s._day.state)
	var cue := PawnInterestPolicy.cue(s._day.state, v)
	var model := s.counter_model()
	check(not model.trade.visual.pawn_terms.contains(cue) and model.trade.visual.pawn_background.is_empty(), "no unsolicited trade cue")
	check(not JSON.stringify(model.dialogue.visual.speech).contains(cue), "not known before asking")
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.counter_command("question", v.visit_id, "circumstance").ok and s.read_state() == before, "question save rollback")
	(s._save as CountingStore).fail = false
	check(s.counter_command("question", v.visit_id, "circumstance").ok, "existing timing question")
	check(s._day.state.game_minutes == before.game_minutes + 5 and s._day.state.social == before.social and s._day.state.cash == before.cash, "ordinary question cost only")
	verify(s, "asked timing question")
	s = restore_payload(SaveCodec.new().encode(s._day.state, 45))
	model = s.counter_model()
	check(model.dialogue.visual.speech.any(func(row: Dictionary) -> bool: return row.answer == cue), "answer restored from same attitude source")
	check(not model.trade.visual.pawn_terms.contains(cue) and model.trade.visual.pawn_background.is_empty(), "trade remains contract-only after asking")
	before = s.read_state()
	check(not s.counter_command("question", v.visit_id, "circumstance").ok and s.read_state() == before, "cannot charge for repeat question")
	for rigid in [false, true]:
		for urgent in [false, true]:
			var wealthy := unit(rigid, urgent)
			var customer := wealthy._day.state.visits[0]
			var result := wealthy._counter.execute(wealthy._day, "question", customer.visit_id, "circumstance")
			check(result.ok and result.message == PawnInterestPolicy.cue(wealthy._day.state, customer), "rich visitor timing answer uses real personality and urgency")
			check(customer.asked_question_ids == ["circumstance"] and wealthy._day.state.game_minutes == 5, "rich question recorded once")
	print("PAWN TIMING DIALOGUE: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
