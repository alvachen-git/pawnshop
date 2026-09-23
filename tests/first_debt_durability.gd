extends "res://tests/run_first_debt.gd"

func load_stage(stage: String) -> RunSession:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v28/" + stage + ".json"))
	var codec := SaveCodec.new()
	var st := codec.decode(raw, run_def, 28, catalog, true)
	check(st != null, "load " + stage + " " + codec.error_message)
	if st == null: return null
	var store := GhostReplayStore.new(); store.origin = raw.ghost_origin
	var s := RunSession.new(run_def, 28, store, catalog); s._day.state = st
	return s

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	for stage in ["before-fd_ticket", "before-fd_lu", "before-fd_chen_request", "before-fd_family", "before-fd_dragon", "before-fd_truth", "before-fd_settle"]:
		var s := load_stage(stage)
		if s == null: quit(1); return
		var id: String = stage.trim_prefix("before-")
		var choice: String = {"fd_ticket":"read", "fd_lu":"ask", "fd_chen_request":"ask", "fd_family":"read", "fd_dragon":"buy", "fd_truth":"tell", "fd_settle":"return"}[id]
		var lib := SaveLibrary.new("res://.godot/qa/v28/durable-" + id + ".json")
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/first_debt_open", s._day.state, run_def, 28, catalog), "initial write " + id)
		check(not lib.save_reason(s._day.state).is_empty(), "business manual saving stays blocked")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		lib.fail_write = true
		var r := submit(s, id, choice)
		check(not r.ok and "重试" in r.message and before == s.read_state(), "atomic rollback " + id)
		check(bytes == FileAccess.get_file_as_bytes(lib.path), "old disk intact " + id)
		lib.fail_write = false
		check(submit(s, id, choice).ok, "retry " + id)
		var saved := lib.read_entry("auto/first_debt_open")
		check(not saved.is_empty(), "disk readable " + id)
		if not saved.is_empty(): check(GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "disk exact " + id)
		before = s.read_state()
		check(not submit(s, id, choice).ok and before == s.read_state(), "duplicate prevented " + id)
		var f := FileAccess.open("res://.godot/qa/v28/committed-" + id + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 28)))
	var s := load_stage("before-fd_dragon")
	for amount in [179, 180]:
		s = load_stage("before-fd_dragon"); s._day.state.cash = amount
		var before := s.read_state()
		var r := s.event_command("fd_dragon", "buy")
		check(r.ok == (amount == 180), "dragon boundary%d" % amount)
		if amount == 179: check(before == s.read_state(), "179 no changes")
		else: check(s._day.state.cash == 0, "exact180")
	for amount in [299, 300]:
		s = load_stage("before-fd_settle"); s._day.state.cash = amount
		var before := s.read_state(); var r := s.event_command("fd_settle", "pay")
		check(r.ok == (amount == 300), "compensation boundary%d" % amount)
		if amount == 299: check(before == s.read_state(), "299 no changes")
		else: check(s._day.state.cash == 0 and FirstDebt.owned(s._day.state, FirstDebt.PHOENIX) != null, "payment keeps objects")
	s = load_stage("before-fd_ticket")
	var clean := SaveCodec.new().encode(s._day.state, 28)
	for flag in ["fd_family_read", "fd_clear", "fd_truth_told", "fd_dragon_bought"]:
		var fake := clean.duplicate(true); fake.narrative_flags.append(flag)
		check(SaveCodec.new().decode(fake, run_def, 28, catalog, true) == null, "forged flag " + flag)
	var bad := clean.duplicate(true); bad.cash += 300
	check(SaveCodec.new().decode(bad, run_def, 28, catalog, true) == null, "forged money")
	bad = clean.duplicate(true); bad.action_journal.append({"method":"event_command", "args":["fd_settle", "pay"]})
	check(SaveCodec.new().decode(bad, run_def, 28, catalog, true) == null, "invalid action rejected")
	s = load_stage("before-fd_settle")
	var unchanged_cash := s._day.state.cash
	check(s.event_command("fd_settle", "refuse").ok and s._day.state.cash == unchanged_cash and not FirstDebt.settled(s._day.state), "refusal stays unsettled without fine")
	check(s.event_command("fd_settle", "return").ok, "refusal can be remedied")
	for scenario in ["receipt", "purchase", "sale", "payment", "continue", "finish"]: durable_action(scenario)
	print("FIRST DEBT DURABILITY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func submit(s: RunSession, id: String, choice: String) -> ActionResult:
	return s.observe_document(id) if id in FirstDebt.DOCUMENTS else s.event_command(id, choice)

func durable_action(scenario: String) -> void:
	var stage: String = {"receipt":"seller", "purchase":"seller", "sale":"before-fd_settle", "payment":"pay-before-fd_settle", "continue":"summary18", "finish":"summary18"}[scenario]
	var s := load_stage(stage)
	if s == null: return
	var method := "event_command"
	var args: Array = ["fd_settle", "pay"]
	match scenario:
		"receipt": method = "observe_document"; args = ["fd_receipt"]
		"purchase": method = "counter_command"; args = ["offer", s._counter.customers.active(s._day.state).visit_id, "", 100]
		"sale": method = "sell_batch"; args = ["buyer_lu", [FirstDebt.owned(s._day.state, FirstDebt.PHOENIX).instance_id, FirstDebt.owned(s._day.state, FirstDebt.DRAGON).instance_id]]
		"continue": method = "execute"; args = ["continue_run"]
		"finish": method = "execute"; args = ["finish_trial"]
	var lib := SaveLibrary.new("res://.godot/qa/v28/durable-action-" + scenario + ".json")
	var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
	check(lib.write_entry("auto/first_debt_open", s._day.state, run_def, 28, catalog), "initial " + scenario)
	var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
	lib.fail_write = true
	var r: ActionResult = s.callv(method, args)
	check(not r.ok and before == s.read_state() and bytes == FileAccess.get_file_as_bytes(lib.path), "all-or-nothing " + scenario)
	lib.fail_write = false
	check(s.callv(method, args).ok, "retry " + scenario)
	var saved := lib.read_entry("auto/first_debt_open")
	check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "disk exact " + scenario)
	before = s.read_state()
	check(not s.callv(method, args).ok and s.read_state() == before, "repeat guarded " + scenario)
	var file := FileAccess.open("res://.godot/qa/v28/committed-action-" + scenario + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 28)))
