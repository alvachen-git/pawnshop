extends "res://tests/run_first_debt.gd"

func load_stage(stage: String) -> RunSession:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v31/" + stage + ".json"))
	var codec := SaveCodec.new()
	var st := codec.decode(raw, run_def, 31, catalog, true)
	check(st != null, "restore " + stage + " " + codec.error_message)
	if st == null: return null
	var store := GhostReplayStore.new(); store.origin = raw.ghost_origin
	var s := RunSession.new(run_def, 31, store, catalog); s._day.state = st
	return s

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_dragon_search_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for spec in [["before-fd_search_motive", "event_command", ["fd_search_motive", "help"]], ["search-ready", "execute", ["prep_dragon_search"]], ["letter", "event_command", ["ds_search_message", "keep"]], ["invite-ready", "execute", ["prep_dragon_invite"]], ["lu", "event_command", ["fd_dragon_quote", "fair"]], ["quoted", "event_command", ["fd_dragon_deal", "buy"]]]:
		var s := load_stage(spec[0])
		if s == null: quit(1); return
		var lib := SaveLibrary.new("res://.godot/qa/v31/durable-" + spec[0] + ".json")
		lib.register_catalog("res://data/first_debt_dragon_search_manifest.json", catalog)
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/first_debt_dragon_search", s._day.state, run_def, 31, catalog), "initial write")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		lib.fail_write = true
		var r: ActionResult = s.callv(spec[1], spec[2])
		check(not r.ok and before == s.read_state() and bytes == FileAccess.get_file_as_bytes(lib.path), "rollback " + spec[0])
		lib.fail_write = false
		check(s.callv(spec[1], spec[2]).ok, "retry " + spec[0])
		var saved := lib.read_entry("auto/first_debt_dragon_search")
		check(not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state()), "disk exact " + spec[0])
		before = s.read_state()
		check(not s.callv(spec[1], spec[2]).ok and before == s.read_state(), "duplicate no state change " + spec[0])
		var f := FileAccess.open("res://.godot/qa/v31/committed-" + spec[0] + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 31)))
	# Unit-only boundary mutations; persistence tests above use full legal journals.
	for reputation in [-1, 0, 1]:
		for short in [true, false]:
			var s := load_stage("lu"); s._day.state.social.reputation = reputation
			var price := 200 if reputation < 0 else 150
			var key := "dear" if reputation < 0 else "fair"
			check(not s.event_command("fd_dragon_quote", "fair" if key == "dear" else "dear").ok, "cannot forge quote")
			check(s.event_command("fd_dragon_quote", key).ok and DragonSearch.price(s._day.state) == price, "rep quote %d" % reputation)
			s._day.state.social.reputation = -reputation - 1
			for i in 3: s.counter_model()
			check(DragonSearch.price(s._day.state) == price, "meeting quote locked after rep and refresh")
			s._day.state.cash = price - (1 if short else 0)
			var cash := s._day.state.cash; var minute := s._day.state.game_minutes
			var r := s.event_command("fd_dragon_deal", "buy")
			check(r.ok != short, "cash boundary %d" % cash)
			check(s._day.state.cash == (cash if short else 0), "cash exact")
			check(s._day.state.game_minutes == minute + (0 if short else 5), "five minutes only purchase")
			check((FirstDebt.owned(s._day.state, FirstDebt.DRAGON) != null) != short, "unique inventory")
	var s := load_stage("search-ready")
	check(s.execute("prep_visitors").ok and s.execute("prep_tea").ok, "other preparations")
	var before := s.read_state()
	check(not s.execute("prep_dragon_search").ok and s.read_state() == before, "shared limit two")
	var raw := SaveCodec.new().encode(load_stage("search-ready")._day.state, 31)
	for f in ["fd_search_message", "fd_dragon_bought"]:
		var bad := raw.duplicate(true); bad.narrative_flags.append(f)
		check(SaveCodec.new().decode(bad, run_def, 31, catalog, true) == null, "forged flag " + f)
	var bad := raw.duplicate(true); bad.action_journal.append({"method": "execute", "args": ["prep_dragon_invite", ""]})
	check(SaveCodec.new().decode(bad, run_def, 31, catalog, true) == null, "cannot forge premature appointment")
	print("DRAGON DURABILITY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
