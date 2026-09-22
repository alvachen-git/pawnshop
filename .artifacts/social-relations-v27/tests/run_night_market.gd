extends "res://tests/run_mirror_chapter.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/night_market_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "night market content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "night_market")
	run_def._randomize_seed = false
	driver.check = check; driver.catalog = catalog
	if "process-read" in OS.get_cmdline_user_args():
		var files := DirAccess.get_files_at("res://.godot/night-process")
		check(files.size() >= 28, "cross-process stage snapshots exist")
		for filename in files:
			var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/night-process/" + filename))
			var codec := SaveCodec.new()
			var recovered := codec.decode(payload, run_def, 21, catalog, true)
			check(recovered != null, "cross process recovery " + filename + ": " + codec.error_message)
			if filename.ends_with("final.json") and payload.phase == "dead":
				var broken: Dictionary = payload.duplicate(true)
				broken.room_history.append(7)
				check(codec.decode(broken, run_def, 21, catalog, true) == null, "malformed terminal lifecycle rejected without crashing")
		print("NIGHT MARKET PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1); return
	var examples := {}
	for seed_value in (range(8) if "quick" in OS.get_cmdline_user_args() else range(512)):
		var state := RunState.create(run_def); state.run_seed = seed_value
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		check(rows.size() == 42 and rows == OpeningPreparation.plan(state, run_def, catalog), "stable 42 visits")
		var specials := rows.filter(func(r: Dictionary) -> bool: return r.has("night_policy"))
		check(specials.size() == 4, "four special opportunities")
		check(specials.filter(func(r: Dictionary) -> bool: return r.night_policy == "one_quote").size() == 2, "two one-quote sellers")
		for n in range(1, 8):
			var today := rows.filter(func(r: Dictionary) -> bool: return r.night == n)
			check(today.size() == 6 and today.filter(func(r: Dictionary) -> bool: return r.has("night_policy")).size() <= (0 if n == 1 else 1), "daily limit")
			for i in range(1, today.size()): check(today[i].arrival - today[i - 1].arrival >= 15, "15 minute spacing")
		for r in specials:
			check(r.arrival >= (180 if r.night_policy == "one_quote" else 360) and r.arrival < (360 if r.night_policy == "one_quote" else 521), "late seller band")
			if r.night_policy == "wet_cloth" and not examples.has(r.night_aftermath): examples[r.night_aftermath] = seed_value
		for n in [2, 3, 4, 5, 6, 7]:
			state.current_night_index = n
			state.preparation_history.clear()
			OpeningPreparation.perform(state, run_def, catalog, "target", "stationery")
			var revised := OpeningPreparation.plan(state, run_def, catalog)
			for r in specials:
				check(revised.any(func(t: Dictionary) -> bool: return t == r), "preparation protects night guests")
	print("NIGHT MARKET EXAMPLES: ", JSON.stringify(examples))
	for seed_value in examples.values():
		play_route(int(seed_value), "careful")
		play_route(int(seed_value), "ignore")
	play_route(42, "taboo")
	for seed_value in 64:
		var sample := RunState.create(run_def); sample.run_seed = seed_value
		if OpeningPreparation.plan(sample, run_def, catalog).any(func(r: Dictionary) -> bool: return r.get("night_policy") == "wet_cloth" and r.night == 3):
			play_route(seed_value, "taboo"); break
	edges()
	command_edges()
	print("NIGHT MARKET TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func play_route(seed_value: int, route: String) -> void:
	run_def._seed = seed_value
	var s := fresh("late_" + route)
	for n in range(1, 8):
		process_snapshot(s, seed_value, route, "pre_open")
		driver.open(s)
		for guard in 130:
			driver.drain(s)
			if s._day.state.phase != &"open" or s._day.state.game_minutes >= 530: break
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.night_policy == "wet_cloth":
					if route == "taboo" and "origin" not in v.asked_question_ids:
						s.counter_command("question", v.visit_id, "origin")
					else:
						var cash_before := s._day.state.cash
						var bought := s.counter_command("offer", v.visit_id, "", v.trade.asking_price)
						if bought.ok and v.status == "bought": check(s._day.state.cash < cash_before, "real acquisition debit")
						elif v.status == "active": s.counter_command("reject", v.visit_id)
				else: s.counter_command("reject", v.visit_id)
			elif route == "careful" and not NightMarketRisk.unresolved(s._day.state).is_empty() and s._day.state.game_minutes <= 520:
				var id: String = NightMarketRisk.unresolved(s._day.state)[0]
				check(s.execute("seal_cloth/" + id).ok, "treat actual exposure")
			else: s.execute("short_task")
		if s._day.state.phase == &"open": s.execute("close_shop")
		process_snapshot(s, seed_value, route, "closed")
		if s._day.state.phase == &"closed_processing": s.execute("wait_until_seal")
		process_snapshot(s, seed_value, route, "before_settle")

		if n >= 3 and not s._day.state.night_market_history.is_empty():
			var library := SaveLibrary.new("res://.godot/late-fault-%d.json" % Time.get_ticks_usec())
			check(library.write_entry("manual/1", s._day.state, run_def, 21, catalog), "manual save before settlement")
			var snapshot := s.read_state()
			s._save.library = library; library.fail_write = true
			check(not s.execute("resolve_night").ok and snapshot == s.read_state(), "failed checkpoint rolls back loss fees and lifecycle")
			library.fail_write = false; s._save.library = null
			check(not library.read_entry("manual/1").is_empty(), "failed write preserves existing slot")
		for command in ["resolve_night", "enter_room", "sleep", "finish_sleep"]:
			var result := s.execute(command)
			check(result.ok, "route %s seed%d night%d %s: %s" % [route, seed_value, n, command, result.message])
			if not result.ok: return
			driver.drain(s)
			var codec := SaveCodec.new()
			var data := codec.encode(s._day.state, 21)
			check(codec.decode(data, run_def, 21, catalog) != null, "restore stage: " + codec.error_message)
			process_snapshot(s, seed_value, route, command)
			if not s._day.state.night_market_history.is_empty():
				var tampered: Dictionary = data.duplicate(true)
				tampered.night_market_history[0].minute += 5
				check(codec.decode(tampered, run_def, 21, catalog) == null, "reject altered night action")
		if s._day.state.phase == &"dead": break
		var continued := s.execute("continue_run")
		check(continued.ok, "continue night route: " + continued.message)
		if not continued.ok: return
	check(s._day.state.phase in [&"run_ended", &"dead"], "route reaches actual ending")
	process_snapshot(s, seed_value, route, "final")
	var payload := SaveCodec.new().encode(s._day.state, 21)
	var file := FileAccess.open("res://.godot/night-route-save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload)); file.close()
	print("ROUTE ", route, " seed=", seed_value, " cash=", s._day.state.cash, " lamp=", NightMarketRisk.lamp_level(s._day.state), " phase=", s._day.state.phase)
	print("ASSETS ", route, " seed=", seed_value, " ", JSON.stringify(FinancialSummary.build(s._day.state)))

func process_snapshot(s: RunSession, seed_value: int, route: String, stage: String) -> void:
	if seed_value not in [0, 4]: return
	DirAccess.make_dir_recursive_absolute("res://.godot/night-process")
	var name := "%d-%s-%d-%s.json" % [seed_value, route, s._day.state.current_night_index, stage]
	var file := FileAccess.open("res://.godot/night-process/" + name, FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 21))); file.close()

func edges() -> void:
	run_def._seed = 42
	var state := RunState.create(run_def)
	state.current_night_index = 3
	state.phase = &"open"
	var row := {"visit_id": "edge", "night": 3, "night_policy": "wet_cloth", "night_aftermath": "haunt"}
	state.ordinary_selections.append(row)
	state.night_market_history.append({"visit_id": "edge", "night": 3, "minute": 400, "action": "taboo"})
	state.game_minutes = 520
	var day := DayController.new(run_def, state)
	check(NightMarketRisk.treat(day, "edge").ok and state.game_minutes == 540 and NightMarketRisk.lamp_level(state) == 0, "treatment finishes exactly 03:00")
	var count := state.action_count
	check(not NightMarketRisk.treat(day, "edge").ok and state.action_count == count, "duplicate cleanup no time")
	state.night_market_history.pop_back(); state.game_minutes = 525; state.phase = &"open"
	check(not NightMarketRisk.treat(day, "edge").ok and state.game_minutes == 525, "cleanup rejects insufficient time")
	state.room_history.append({"night": 3, "action": "finish_sleep"})
	check(NightMarketRisk.lamp_level(state) == 1, "first night no extra damage")
	for n in range(4, 8):
		state.current_night_index = n
		state.room_history.append({"night": n, "action": "finish_sleep"})
		check(NightMarketRisk.lamp_level(state) == n - 2, "one untreated step per night")

func guest_fixture(policy: String, effect := "") -> Dictionary:
	var state := RunState.create(run_def)
	state.run_seed = 0
	var rows := OpeningPreparation.plan(state, run_def, catalog)
	var row: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r.get("night_policy") == policy)[0]
	state.current_night_index = int(row.night)
	CustomerManager.new().prepare_night(state, run_def, catalog)
	var visit: CustomerVisit = state.visits.filter(func(v: CustomerVisit) -> bool: return v.visit_id == row.visit_id)[0]
	state.visits.assign([visit]); state.phase = &"open"; state.game_minutes = visit.arrival
	if not effect.is_empty():
		visit.night_aftermath = effect
		for choice in state.ordinary_selections:
			if choice.visit_id == visit.visit_id: choice.night_aftermath = effect
	CustomerManager.new().update(state)
	return {"state": state, "day": DayController.new(run_def, state), "visit": visit, "service": CounterService.new(catalog)}

func command_edges() -> void:
	var f := guest_fixture("one_quote")
	var v: CustomerVisit = f.visit
	var cash: int = f.state.cash
	for command in ["belittle", "pressure", "concession", "pawn"]:
		var minute: int = f.state.game_minutes
		check(not f.service.execute(f.day, command, v.visit_id, "", 10).ok and f.state.game_minutes == minute, "one quote rejects non-contract action")
	f.state.cash = 0
	check(not f.service.execute(f.day, "offer", v.visit_id, "", v.trade.asking_price).ok and v.trade.rounds_left == 1, "invalid cash doesn't consume only quote")
	f.state.cash = cash
	check(f.service.execute(f.day, "offer", v.visit_id, "", maxi(1, v.trade.reserve_price - 1)).ok and v.status == "rounds_exhausted", "failed sole price ends visit")
	var minute: int = f.state.game_minutes
	check(not f.service.execute(f.day, "offer", v.visit_id, "", 99).ok and f.state.game_minutes == minute, "repeat offer after leave has no effect")
	f = guest_fixture("wet_cloth", "item"); v = f.visit
	f.state.game_minutes = v.expires_at - 5
	check(not f.service.execute(f.day, "question", v.visit_id, "origin").ok and f.state.night_market_history.is_empty(), "taboo at leave deadline has no effect")
	f = guest_fixture("wet_cloth", "item"); v = f.visit
	check(f.service.execute(f.day, "question", v.visit_id, "origin").ok, "taboo succeeds before deadline")
	check(NightMarketRisk.lamp_level(f.state) == 1 and f.state.ledger_entries.is_empty(), "taboo adds haunt but no posting")
	minute = f.state.game_minutes
	check(not f.service.execute(f.day, "question", v.visit_id, "origin").ok and f.state.game_minutes == minute, "duplicate taboo no repeated time or haunt")
	check(f.service.execute(f.day, "offer", v.visit_id, "", v.trade.asking_price).ok, "buy risky item")
	var goods: ItemInstance = f.state.inventory_instances[0]
	check(NightMarketRisk.item_pending(f.state, v.visit_id) and NightMarketRisk.lamp_level(f.state) == 1, "item and personal risks coexist without double damage")
	var price: int = goods.acquisition_price
	cash = f.state.cash
	f.state.game_minutes = 540
	NightMarketRisk.settle(f.state)
	check(goods.ownership_state == "lost" and f.state.cash == cash and FinancialSummary.build(f.state).inventory_loss == price, "loss expensed without second cash debit")
	var postings: int = f.state.ledger_entries.size()
	NightMarketRisk.settle(f.state)
	check(f.state.ledger_entries.size() == postings, "loss cannot post twice")
	f = guest_fixture("wet_cloth", "haunt"); v = f.visit
	check(f.service.execute(f.day, "offer", v.visit_id, "", v.trade.asking_price).ok, "haunted purchase")
	goods = f.state.inventory_instances[0]
	goods.ownership_state = "sold"
	check(NightMarketRisk.lamp_level(f.state) == 1 and v.visit_id in NightMarketRisk.unresolved(f.state), "selling doesn't remove personal source")
	f.state.game_minutes = 500
	check(NightMarketRisk.treat(f.day, v.visit_id).ok and NightMarketRisk.lamp_level(f.state) == 0, "cloth can be treated after item sold")
	var sources := RunState.create(run_def)
	sources.current_night_index = 4
	sources.ordinary_selections.assign([{"visit_id": "a", "night_aftermath": "haunt"}, {"visit_id": "b", "night_aftermath": "haunt"}])
	sources.night_market_history.assign([{"visit_id": "a", "night": 3, "minute": 400, "action": "purchase"}, {"visit_id": "b", "night": 3, "minute": 420, "action": "purchase"}])
	sources.room_history.assign([{"night": 3, "action": "finish_sleep"}, {"night": 4, "action": "finish_sleep"}])
	check(NightMarketRisk.lamp_level(sources) == 2, "multiple sources worsen once per night")
	sources.night_market_history.append({"visit_id": "a", "night": 4, "minute": 500, "action": "seal_cloth"})
	check(NightMarketRisk.lamp_level(sources) == 2, "partial cleanup keeps remaining haunt")
	sources.night_market_history.append({"visit_id": "b", "night": 4, "minute": 520, "action": "seal_cloth"})
	check(NightMarketRisk.lamp_level(sources) == 0, "last source cleanup restores component")
