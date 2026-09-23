extends "res://tests/reckoning_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog29")
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var s := load_stage("seller")
	var before := s.read_state()
	for id in ["fd_customer_ticket", "fd_protection", "fd_yin_link", "fd_yin_echo"]:
		check(not s.observe_document(id).ok and s.read_state() == before, "unavailable evidence " + id)
	for order in [["fd_ticket", "fd_receipt"], ["fd_receipt", "fd_ticket"]]:
		s = load_stage("seller")
		var minute: int = s.read_state().game_minutes
		for id in order: check(s.observe_document(id).ok, "document order " + id)
		check(s.read_state().game_minutes == minute and FirstDebt.owned(s._day.state, FirstDebt.PHOENIX) == null, "both reading orders free without purchase")
	s = load_stage("before-fd_customer_ticket")
	if FirstDebt.chen_delivered_today(s._day.state): resume_next_visit(s)
	check(not s.event_command("fd_truth", "tell").ok, "diary alone cannot confirm original")
	check(s.old_shop_model().documents.any(func(d: Dictionary) -> bool: return d.id == "fd_customer_ticket" and not d.read), "retained unread original available")
	before = s.read_state()
	for i in 5: s.old_shop_model(); s.counter_model()
	check(before == s.read_state(), "render does not observe")
	check(s.observe_document("fd_customer_ticket").ok, "read customer original")
	var result := s.event_command("fd_truth", "tell")
	check(result.ok and "营署" not in result.message, "unknown protection omitted")
	check(not s.event_command("fd_settle", "pay").ok, "cannot pay before agreement")
	check(s.observe_document("fd_protection").ok, "optional protection")
	check("营署" in FirstDebt.response(s._day.state, "fd_truth", "旧事"), "known protection can be discussed")
	before = s.read_state()
	check(s.event_command("fd_compensation", "offer").ok, "Chen agrees separately")
	check(s.read_state().cash == before.cash and s.read_state().game_minutes == before.game_minutes and not FirstDebt.settled(s._day.state), "offer does not pay or settle")
	run_def._initial_cash = 2000 # Dedicated funded branch fixture.
	for route in ["return", "pay"]:
		s = load_stage("funded-before-fd_settle")
		if route == "pay":
			check(FirstDebt.owned(s._day.state, FirstDebt.PHOENIX) != null and FirstDebt.owned(s._day.state, FirstDebt.DRAGON) != null, "cash route with both originals")
			check(s.event_command("fd_compensation", "offer").ok, "informed consent")
		# Both orders work: link before settlement, or investigate after settlement.
		if route == "return":
			atomic(s, "fd_spending", "funded-" + route)
			atomic(s, "fd_yin_link", "funded-" + route)
			check(not s.observe_document("fd_yin_echo").ok, "unsettled ledger unchanged")
		check(s.event_command("fd_settle", route).ok, "settle " + route)
		check(not FirstDebt.flag(s._day.state, "fd_protection_read"), "optional protection never gates resolution")
		if route == "pay":
			atomic(s, "fd_spending", "funded-" + route)
			atomic(s, "fd_yin_link", "funded-" + route)
		var doc: Dictionary = s.old_shop_model().documents.filter(func(d: Dictionary) -> bool: return d.id == "ledger")[0]
		check(not doc.read and doc.observe_id == "fd_yin_echo", "first revisit offers echo")
		atomic(s, "fd_yin_echo", "funded-" + route)
		doc = s.old_shop_model().documents.filter(func(d: Dictionary) -> bool: return d.id == "ledger")[0]
		check(doc.read and ("“清”" if route == "return" else "“和”") in doc.text, "correct ledger response " + route)
		check("阿七" not in doc.text and "女儿" not in doc.text, "identity remains unknown")
		before = s.read_state()
		check(not s.event_command("fd_settle", "return").ok and not s.event_command("fd_settle", "pay").ok and before == s.read_state(), "mutually exclusive resolution")
	run_def._initial_cash = 300
	s = load_stage("before-fd_truth")
	atomic(s, "fd_protection", "unsettled")
	print("RECKONING STORY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func atomic(s: RunSession, id: String, suffix: String) -> void:
	var lib := SaveLibrary.new("res://.godot/qa/v29/story-" + id + suffix + ".json")
	lib.register_catalog("res://data/first_debt_reckoning_manifest.json", catalog)
	var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
	check(lib.write_entry("auto/first_debt_reckoning", s._day.state, run_def, 29, catalog), "initial write " + id)
	var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
	lib.fail_write = true
	check(not s.observe_document(id).ok and before == s.read_state() and bytes == FileAccess.get_file_as_bytes(lib.path), "rollback " + id)
	lib.fail_write = false
	check(s.observe_document(id).ok, "retry " + id)
	var saved := lib.read_entry("auto/first_debt_reckoning")
	check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "replay disk " + id)
	before = s.read_state()
	check(not s.observe_document(id).ok and before == s.read_state(), "idempotent " + id)
	var file := FileAccess.open("res://.godot/qa/v29/committed-" + id + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))

func resume_next_visit(s: RunSession) -> void:
	act(s, "close_shop"); act(s, "wait_until_seal"); act(s, "resolve_night"); driver.drain(s)
	if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
	driver.drain(s); act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s)
	act(s, "finish_sleep"); act(s, "continue_run"); driver.drain(s); act(s, "open_shop"); driver.drain(s)
	for i in 20:
		var v := s._counter.customers.active(s._day.state)
		if v == null: break
		check(s.counter_command("reject", v.visit_id).ok, "finish customer before evidence conversation")
