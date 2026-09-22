extends "res://tests/fan_desk_rules.gd"

func fill(s: RunSession, id: String, brush := "same", inscription := "same") -> void:
	check(s.fan_command("draft", id, pair("brush", brush)).ok, "draft brush")
	check(s.fan_command("draft", id, pair("inscription", inscription)).ok, "draft inscription")

func run() -> void:
	if not setup(): quit(1); return
	var s := load_fan()
	var visit := CustomerManager.new().active(s._day.state)
	var id := visit.item.instance_id
	var start := s._day.state.game_minutes
	var before := s.read_state()
	for bad in ["", "{}", "[]", '{"kind":"brush","reference":[720,320],"object":[800,355],"note":"same"}', '{"kind":"brush","reference":[720,320],"object":[380,245],"note":"truth"}']:
		invalid_fan(s, "draft", id, bad)
	invalid_fan(s, "clear_draft", id, "all")
	invalid_fan(s, "commit", id, "sound")
	fill(s, id)
	check(s._day.state.game_minutes == start and visit.item.goods.get("fan_claim", "").is_empty(), "drafts do not charge or affect item price")
	var after := s.read_state()
	before.erase("shop_growth"); before.erase("action_journal")
	after.erase("shop_growth"); after.erase("action_journal")
	check(before == after, "draft changes no action count, market, visit, event or risk state")
	invalid_fan(s, "draft", id, pair("brush"))
	invalid_fan(s, "clear_draft", id, "invalid")
	check(s.fan_command("draft", id, pair("brush", "different")).ok, "reselect opinion")
	var shifted := FanEvidence.payload("brush", Vector2(.73,.32), Vector2(.39,.245), "different")
	check(s.fan_command("draft", id, shifted).ok, "reselect circles")
	check(FanAppraisalService.notes(s._day.state, id).brush.reference == [730,320], "new circles retained")
	check(s.fan_command("clear_draft", id, "brush").ok, "clear one")
	check(not FanAppraisalService.notes(s._day.state,id).has("brush") and FanAppraisalService.notes(s._day.state,id).has("inscription"), "single clear preserves other note")
	invalid_fan(s, "commit", id, "sound")
	check(s.fan_command("clear_draft", id, "all").ok, "clear all")
	invalid_fan(s, "clear_draft", id, "all")
	fill(s,id,"different","unsure")
	check(s._day.state.game_minutes == start, "all corrections remain free")
	fixture(s, "draft-uncommitted")
	for brush in FanEvidence.NOTES:
		for inscription in FanEvidence.NOTES:
			var pairs := {"brush":{"note":brush},"inscription":{"note":inscription}}
			var expected := "暂难定论" if brush == "unsure" or inscription == "unsure" else ("倾向真迹" if brush == "same" and inscription == "same" else ("倾向假画" if brush == "different" and inscription == "different" else ("疑为假画" if brush == "same" else "疑为临摹画，需再斟酌")))
			check(FanAppraisalService.tentative(pairs) == expected, "subjective summary " + brush + "/" + inscription)
	var manager := SaveManager.new("user://tests/fan_draft/auto.json")
	manager.catalog = catalog
	manager.library = SaveLibrary.new("user://tests/fan_draft/library.json")
	check(manager.save_state(s._day.state,run_def,27), "save real draft library")
	s._save = manager
	for command in ["draft", "clear_draft", "commit"]:
		before = s.read_state()
		var bytes := FileAccess.get_file_as_bytes(manager.library.path)
		manager.library.fail_write = true
		var detail := pair("brush", "same") if command == "draft" else ("all" if command == "clear_draft" else "sound")
		check(not s.fan_command(command,id,detail).ok, "disk failure returned " + command)
		check(before == s.read_state() and bytes == FileAccess.get_file_as_bytes(manager.library.path), "complete memory and disk rollback " + command)
		manager.library.fail_write = false
	check(s.fan_command("commit",id,"sound").ok, "may judge true despite contrary and unsure notes")
	check(s._day.state.game_minutes == start + 10 and FanAppraisalService.record(s._day.state,id).verdict == "sound", "only final commit charges ten")
	check(not FanAppraisalService.record(s._day.state,id).has("draft_pairs") and not CustomerManager.new().active(s._day.state).item.expert_reviewed, "formal evidence preserved without expert certification")
	fixture(s,"draft-committed")
	var writes_before := FileAccess.get_file_as_bytes(manager.library.path)
	before = s.read_state()
	for command in ["commit", "clear_draft", "draft"]:
		check(not s.fan_command(command,id,"sound" if command == "commit" else ("all" if command == "clear_draft" else pair("brush"))).ok, "formal record locks " + command)
	check(before == s.read_state() and writes_before == FileAccess.get_file_as_bytes(manager.library.path), "locked edits exact no-op")
	for field in ["note","reference"]:
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/draft-uncommitted.json"))
		payload.shop_growth.appraisal.records[id].draft_pairs.brush[field] = "same" if field == "note" else [740,320]
		check(SaveCodec.new().decode(payload,run_def,27,catalog,true) == null,"reject tampered draft " + field)
	legacy_checks()
	boundary_checks()
	owned_and_schedule_checks()
	print("FAN DRAFT RULES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func legacy_checks() -> void:
	for count in [1,2]:
		var s := load_fan()
		var id := CustomerManager.new().active(s._day.state).item.instance_id
		check(s.fan_command("compare",id,pair("brush")).ok,"legacy paid first check")
		if count == 2: check(s.fan_command("inscription",id).ok,"legacy paid second check without circles")
		verify(s,"legacy paid checks")
		var start := s._day.state.game_minutes
		check(FanAppraisalService.commit_minutes(s._day.state,id) == 0,"legacy time credited")
		check(s.fan_command("clear_draft",id,"all").ok,"clear legacy circles")
		check(FanAppraisalService.notes(s._day.state,id).is_empty(),"no legacy circles resurrected")
		verify(s,"legacy explicit empty draft")
		fill(s,id)
		check(s.fan_command("commit",id,"mended").ok and s._day.state.game_minutes == start,"legacy finish costs zero without refund")
		verify(s,"legacy converted and committed")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/saved-claim.json"))
	check(SaveCodec.new().decode(old,run_def,27,catalog,true) != null,"old final claim still replays")

func boundary_checks() -> void:
	for remaining in [9,10,11]:
		var s := load_fan()
		var visit := CustomerManager.new().active(s._day.state)
		var id := visit.item.instance_id
		fill(s,id)
		visit.expires_at = s._day.state.game_minutes + remaining
		if remaining <= 10: invalid_fan(s,"commit",id,"sound")
		else: check(s.fan_command("commit",id,"sound").ok,"finish strictly before deadline")
	for clock in [529,530,531]:
		var s := load_fan()
		var visit := CustomerManager.new().active(s._day.state)
		var id := visit.item.instance_id
		fill(s,id)
		visit.expires_at = 600
		s._day.state.game_minutes = clock
		if clock >= 530: invalid_fan(s,"commit",id,"sound")
		else: check(s.fan_command("commit",id,"sound").ok,"finish before three")
	var s := load_fan()
	var visit := CustomerManager.new().active(s._day.state)
	var id := visit.item.instance_id
	fill(s,id)
	visit.customer_id = "ghost_closed_bundle"
	var start := s._day.state.game_minutes
	check(s.fan_command("commit",id,"sound").ok and visit.status == "inspection_refused", "taboo refuses actual inspection")
	check(s._day.state.game_minutes == start + 10 and FanAppraisalService.record(s._day.state,id).verdict == "" and visit.item.goods.get("fan_claim","").is_empty(), "taboo spends inspection time without claim")
	s = load_fan(); visit = CustomerManager.new().active(s._day.state); id = visit.item.instance_id
	fill(s,id)
	s._day.state.pending_event_id = "pending"
	invalid_fan(s,"commit",id,"sound")
	invalid_fan(s,"draft",id,pair("brush","different"))
	s._day.state.pending_event_id = ""
	for key in ["tools", "knowledge"]:
		FanAppraisalService.data(s._day.state)[key] = false
		invalid_fan(s,"commit",id,"sound")
		FanAppraisalService.data(s._day.state)[key] = true
	visit.status = "rejected"
	invalid_fan(s,"commit",id,"sound")
	invalid_fan(s,"clear_draft",id,"all")

func owned_and_schedule_checks() -> void:
	var s := load_fan()
	var visit := CustomerManager.new().active(s._day.state)
	var id := visit.item.instance_id
	fill(s,id)
	check(s.counter_command("offer",visit.visit_id,"",visit.trade.asking_price).ok,"purchase with unfinished draft")
	check(visit.item.ownership_state == "owned" and FanAppraisalService.notes(s._day.state,id).size() == 2,"draft follows item into inventory")
	verify(s,"owned draft")
	s._day.state.risk_pending = id
	invalid_fan(s,"commit",id,"sound")
	s._day.state.risk_pending = ""
	var other: CustomerVisit = null
	for candidate in s._day.state.visits:
		if candidate != visit and candidate.status == "scheduled": other = candidate; break
	check(other != null,"scheduled guest available for clock check")
	if other != null:
		other.arrival = s._day.state.game_minutes + 1
		other.expires_at = s._day.state.game_minutes + 5
	check(s.fan_command("commit",id,"sound").ok,"commit owned item")
	if other != null: check(other.status == "timed_out","other guest expires normally during commit")
	# Keep the replay and expert path natural, separate from synthetic visit deadlines.
	s = load_fan(); visit = CustomerManager.new().active(s._day.state); id = visit.item.instance_id
	fill(s,id)
	check(s.fan_command("commit",id,"sound").ok,"new final claim")
	check(s.counter_command("offer",visit.visit_id,"",visit.trade.asking_price).ok,"buy new appraised fan")
	check(s.commerce_command("expert_fan",id).ok,"expert validates new workflow")
	check(FanAppraisalService.data(s._day.state).standing == 1,"new judgement earns reputation only through expert")
	verify(s,"new workflow expert review")
	s = load_fan(); visit = CustomerManager.new().active(s._day.state); id = visit.item.instance_id
	fill(s,id)
	check(s.counter_command("offer",visit.visit_id,"",visit.trade.asking_price).ok,"buy before lost ownership boundary")
	for ownership in ["pawned","sold"]:
		visit.item.ownership_state = ownership
		invalid_fan(s,"commit",id,"sound")
		invalid_fan(s,"draft",id,pair("brush","different"))
