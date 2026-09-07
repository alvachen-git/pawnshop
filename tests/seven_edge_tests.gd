extends SceneTree

var failures := 0
var assertions := 0
var catalog: ContentCatalog
var run_def: RunDefinition
var driver := SevenTestDriver.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("FAIL " + label)
func session(seed_value := 42) -> RunSession:
	run_def._seed = seed_value
	return RunSession.new(run_def, 13, SaveManager.new("user://tests/seven_edges_%d.json" % seed_value), catalog)
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/seven_night_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "ordinary_seven")
	run_def._randomize_seed = false
	driver.check = check
	preparation()
	deadline()
	batch()
	future_ticket()
	print("SEVEN EDGE TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func preparation() -> void:
	var s := session()
	for n in 3: driver.open(s); driver.finish(s)
	var failing := M4Tests.ToggleSave.new(s._save.path)
	failing.catalog = catalog
	s._save = failing
	failing.fail = true
	var before := s.read_state()
	check(not s.execute("prep_contact").ok and s.read_state() == before, "failed preparation write rolls back contact and count")
	failing.fail = false
	driver.action(s, "prep_contact")
	check(not PreparationService.requirements_known(s._day.state), "contact does not disclose details")
	driver.action(s, "prep_visitors")
	var news := s.seven_notice()
	check(not news.contains("19:00–21:00") and not news.contains("替换笔尖"), "uninvestigated rumor not full answer")
	check(not s.counter_model().queue.contains("下一客"), "no unearned next arrival schedule")
	before = s.read_state()
	check(not s.execute("prep_investigate").ok and s.read_state() == before, "over two action no mutation")
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 13)
	check(codec.decode(data, run_def, 13, catalog) != null, "valid preparation decode")
	for kind in ["time", "id", "duplicate", "plan", "missing"]:
		var altered := data.duplicate(true)
		match kind:
			"time": altered.preparation_history[0].minute = 5
			"id": altered.preparation_history[1].visit_id = "invented"
			"duplicate": altered.preparation_history.append(altered.preparation_history[0])
			"plan": altered.seven_plan[0].context_id = "invented"
			"missing": altered.erase("seven_plan")
		check(codec.decode(altered, run_def, 13, catalog) == null, "reject tamper " + kind)
	failing.fail = true
	before = s.read_state()
	check(not s.execute("prep_finish").ok and s.read_state() == before, "failed finish preparation is reversible")
	failing.fail = false
	driver.action(s, "prep_finish")
	check(not s.execute("prep_finish").ok, "finish cannot repeat")
	driver.open(s); driver.finish(s)
	check(PreparationService.count(s._day.state) == 0, "daily points reset")
	driver.action(s, "prep_investigate")
	check(PreparationService.requirements_known(s._day.state), "investigation after contact")
	driver.open(s); driver.finish(s)
	driver.open(s); driver.finish(s)
	check(not s.execute("prep_contact").ok, "night seven no renewed appointment")
	check(s.seven_notice().contains("窗口已过"), "expired message remains readable")

func deadline() -> void:
	for thorough in [false, true]:
		var s := session(71)
		var target: Dictionary = s._day.state.seven_plan.filter(func(row: Dictionary) -> bool: return row.get("seven_role") == "urgent")[0]
		while s._day.state.current_night_index < target.night: driver.open(s); driver.finish(s)
		driver.open(s)
		for guard in 110:
			var v := s._counter.customers.active(s._day.state)
			if v != null and v.visit_id == target.visit_id: break
			if v != null: s.counter_command("reject", v.visit_id)
			else: driver.action(s, "short_task")
		var v := s._counter.customers.active(s._day.state)
		check(v != null and v.visit_id == target.visit_id, "reach urgent customer")
		if v == null: continue
		var item := catalog.get_definition("items", v.item.definition_id) as ItemDefinition
		var bounds := AppraisalSystem.new().valuation(v.item, item)
		var postings := s._day.state.ledger_entries.size()
		check(s.counter_command("belittle", v.visit_id).ok, "one deliberate belittle")
		var before := s.read_state()
		check(not s.counter_command("belittle", v.visit_id).ok and before == s.read_state(), "repeated belittle cannot consume time")
		check(AppraisalSystem.new().valuation(v.item, item) == bounds and s._day.state.ledger_entries.size() == postings, "belittle not appraisal or sale")
		if thorough:
			for a in item.appraisal_actions:
				if v.status == "active": s.counter_command("appraise", v.visit_id, a.id)
			if v.status == "active": s.counter_command("question", v.visit_id, "origin")
			check(not s.counter_command("offer", v.visit_id, "", 100).ok and s._day.state.inventory_instances.is_empty(), "full examination loses short window")
		else:
			check(s.counter_command("appraise", v.visit_id, item.appraisal_actions[0].id).ok, "focused check")
			check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok and s._day.state.inventory_instances.size() == 1, "focused check can trade")

func batch() -> void:
	var s := session(42)
	driver.open(s)
	for guard in 110:
		if s._day.state.inventory_instances.size() == 3: break
		var v := s._counter.customers.active(s._day.state)
		if v != null: s.counter_command("offer", v.visit_id, "", v.trade.asking_price)
		else: driver.action(s, "short_task")
	while s._counter.customers.active(s._day.state) != null: s.counter_command("reject", s._counter.customers.active(s._day.state).visit_id)
	var ids: Array = s._day.state.inventory_instances.map(func(i: ItemInstance) -> String: return i.instance_id)
	check(ids.size() == 3, "three real purchases")
	var before := s.read_state()
	check(not s.sell_batch("buyer_recycler", ids + [ids[0]]).ok and before == s.read_state(), "duplicate batch rejects before time or cash")
	check(s.sell_batch("buyer_recycler", ids).ok, "unlimited batch exceeds old cap")
	check(s._day.state.game_minutes == before.game_minutes + 20 and s._day.state.sale_batches.size() == 1, "single twenty minute trip")
	before = s.read_state()
	check(not s.sell_batch("buyer_recycler", ids).ok and before == s.read_state(), "sale cannot repeat")
	driver.finish(s, false)
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 13)
	check(codec.decode(data, run_def, 13, catalog) != null, "batch strict restore")
	data.sale_batches[0].market_id = "invented"
	check(codec.decode(data, run_def, 13, catalog) == null, "fixed appointment no fake market history")
	var buyer := catalog.get_definition("buyers", "buyer_collector") as BuyerDefinition
	s._day.state.phase = &"open"
	s._day.state.visits.clear()
	s._day.state.game_minutes = 220
	check(not s._commerce.trip_reason(s._day, buyer).is_empty(), "arrival exactly at window end rejected")
	s._day.state.game_minutes = 215
	check(s._commerce.trip_reason(s._day, buyer).is_empty(), "twenty minutes ending before deadline allowed")

func future_ticket() -> void:
	var s := session(42)
	for n in 6: driver.open(s); driver.finish(s)
	driver.open(s)
	for guard in 110:
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			if "pawn" in v.transaction_modes:
				check(s.counter_command("pawn", v.visit_id, "", 50).ok, "seventh night loan")
				break
			s.counter_command("reject", v.visit_id)
		else: driver.action(s, "short_task")
	driver.finish(s)
	check(s._day.state.pawn_tickets.size() == 1, "future ticket exists")
	if s._day.state.pawn_tickets.is_empty(): return
	var ticket := s._day.state.pawn_tickets[0]
	check(ticket.due_night == 10 and ticket.status == "active" and ticket.redemption_amount == 55, "night ten obligation not accelerated")
	check(s.load_checkpoint().ok and s._day.state.pawn_tickets[0].status == "active", "future collateral retained after final restore")
