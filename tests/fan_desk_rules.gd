extends "res://tests/shop_appraisal.gd"

func pair(kind: String, note := "same") -> String:
	return FanEvidence.payload(kind, Vector2(0.72, 0.32) if kind == "brush" else Vector2(0.74, 0.69), Vector2(0.38, 0.245) if kind == "brush" else Vector2(0.80, 0.355), note)

func run() -> void:
	if not setup(): quit(1); return
	var s := load_fan()
	var id := CustomerManager.new().active(s._day.state).item.instance_id
	for bad in ["", "{}", "[]", "null", '{"kind":"brush","reference":[720,320],"object":[800,355],"note":"same"}', '{"kind":"brush","reference":[-1,320],"object":[380,245],"note":"same"}', '{"kind":"brush","reference":[720.5,320],"object":[380,245],"note":"same"}', '{"kind":"brush","reference":[720,320],"object":[380,245],"note":"truth"}', '{"kind":"brush","reference":[true,320],"object":[380,245],"note":"same"}']:
		invalid_fan(s, "compare", id, bad)
	var start := s._day.state.game_minutes
	check(s.fan_command("compare", id, pair("brush", "different")).ok, "player can record a contrary opinion")
	check(s._day.state.game_minutes == start + 10, "one linked comparison costs ten")
	check(FanAppraisalService.record(s._day.state, id).pairs.brush.note == "different", "no automatic correction of subjective note")
	invalid_fan(s, "compare", id, pair("brush"))
	invalid_fan(s, "verdict", id, "sound")
	verify(s, "one linked pair")
	var manager := SaveManager.new("user://tests/fan_desk/auto.json")
	manager.catalog = catalog
	manager.library = SaveLibrary.new("user://tests/fan_desk/library.json")
	check(manager.save_state(s._day.state, run_def, 27), "save first pair to real library")
	s._save = manager
	var before := s.read_state()
	var bytes := FileAccess.get_file_as_bytes(manager.library.path)
	manager.library.fail_write = true
	check(not s.fan_command("compare", id, pair("inscription", "unsure")).ok, "save failure reported")
	check(s.read_state() == before and bytes == FileAccess.get_file_as_bytes(manager.library.path), "pair and elapsed time rollback together")
	manager.library.fail_write = false
	check(s.fan_command("compare", id, pair("inscription", "unsure")).ok, "retry second pair")
	check(s._day.state.game_minutes == start + 20, "no extra charge on retry")
	check(s.fan_command("verdict", id, "mended").ok, "independent final judgement")
	check(not CustomerManager.new().active(s._day.state).item.expert_reviewed, "paired notes never certify truth")
	verify(s, "both pairs and judgement")
	fixture(s, "desk-saved")
	var payload := SaveCodec.new().encode(s._day.state, 27)
	payload.shop_growth.appraisal.records[id].pairs.brush.reference[0] = 740
	check(SaveCodec.new().decode(payload, run_def, 27, catalog, true) == null, "reject forged circle coordinates")
	payload = SaveCodec.new().encode(s._day.state, 27)
	payload.shop_growth.appraisal.records[id].pairs.brush.note = "same"
	check(SaveCodec.new().decode(payload, run_def, 27, catalog, true) == null, "reject forged opinion")
	s = load_fan()
	var visit := CustomerManager.new().active(s._day.state)
	visit.expires_at = s._day.state.game_minutes + 10
	id = visit.item.instance_id
	check(s.fan_command("compare", id, pair("brush")).ok, "deadline still spends time")
	check(FanAppraisalService.record(s._day.state, id).is_empty(), "deadline retains no half-pair")
	s = load_fan(); visit = CustomerManager.new().active(s._day.state); id = visit.item.instance_id
	visit.customer_id = "ghost_closed_bundle"
	check(s.fan_command("compare", id, pair("brush")).ok and visit.status == "inspection_refused", "comparison obeys no-appraisal taboo")
	check(FanAppraisalService.record(s._day.state, id).is_empty(), "taboo leaves no note")
	s = load_fan(); id = CustomerManager.new().active(s._day.state).item.instance_id
	s._day.state.game_minutes = 530
	invalid_fan(s, "compare", id, pair("brush"))
	# Pre-redesign commands and their existing saves still replay unchanged.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/saved-claim.json"))
	check(SaveCodec.new().decode(old, run_def, 27, catalog, true) != null, "old text-appraisal save stays valid")
	print("FAN DESK RULES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
