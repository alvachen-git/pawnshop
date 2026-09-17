extends "res://tests/living_pawn_routes.gd"

var _seen: Dictionary = {}
var _audited_sessions: Array[RunSession] = []

func run() -> void:
	super.run()
	for kind in ["jiang_suyun", "ghost_swap_guest", "early_return", "due_return"]:
		check(_seen.has(kind), "real route reached " + kind)
	for s in _audited_sessions:
		s.changed.disconnect(_audit_portrait.bind(s))
	_audited_sessions.clear()
	print("SPECIAL PORTRAIT ROUTES: %d passes, %d failures; seen %s" % [passes, failures, str(_seen.keys())])
	quit(0 if failures == 0 else 1)

func session(seed_value := 42) -> RunSession:
	var s := super.session(seed_value)
	s.changed.connect(_audit_portrait.bind(s))
	_audited_sessions.append(s)
	return s

func _audit_portrait(s: RunSession) -> void:
	var model := s.counter_model()
	var visual: Dictionary = model.get("visual", {})
	if visual.is_empty(): return
	var expected: String = CounterVisualCatalog.FAMILIAR_PORTRAITS.get(visual.get("person_id", ""), CounterVisualCatalog.SPECIAL_CUSTOMERS.get(visual.get("customer_id", ""), ""))
	if expected.is_empty(): return
	var texture := CounterVisualCatalog.portrait(visual.portrait_asset, visual.get("customer_id", ""), visual.get("person_id", ""))
	check(texture != null and texture.resource_path.ends_with("/" + expected + ".png"), "live model selects approved identity")
	_seen[expected] = true
	var returning: bool = visual.get("pawn_return", false)
	var early := EarlyRedemption.is_visit(s._counter.customers.active(s._day.state))
	if returning or early:
		check(model.dialogue.get("preserve_ticket_body", false), "return preserves ticket body")
		check(model.dialogue.get("visual", {}).get("person_id", "") == visual.person_id, "return dialogue receives stable identity")
		check(model.dialogue.body.contains("当票"), "return retains ticket details")
		_seen["due_return" if returning else "early_return"] = true
