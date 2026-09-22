extends "res://tests/run_familiar_stories.gd"

const QA := "res://.godot/qa/pawn_chance/"
var states_written := 0
var issued := {}
var fixtures := {}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA))
	var loaded := JsonContentProvider.new("res://data/pawn_chance_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v20 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	configuration()
	distribution()
	for route in ["keep", "transfer", "higher", "pressure"]: play_ordinary(route)
	check(issued.has("keep") and issued.has("higher") and issued.keep == issued.higher, "different principals preserve redemption outcomes")
	check(issued.has("pressure") and issued.keep == issued.pressure, "inspection pressure and waiting preserve outcomes")
	check(fixtures.has("20") and fixtures.has("50"), "real low and middle probability UI checkpoints")
	var file := FileAccess.open(QA + "fixtures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(fixtures)); file.close()
	print("PAWN CHANCE TESTS: %d passes, %d failures; %d checkpoints" % [passes, failures, states_written])
	quit(0 if failures == 0 else 1)

func configuration() -> void:
	check(catalog.content_version == 20 and run_def.id == "pawn_chance_seven", "new content identity")
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/pawn_chance/customers.json")).records
	for dto in records:
		var expected := 50 if dto.id in ["customer_teahouse", "customer_house_agent"] else 20
		var customer := catalog.get_definition("customers", dto.id) as CustomerDefinition
		check(customer.pawn_redemption_chance == expected, "profession probability " + dto.id)
		for invalid in [-1, 0, 21, 100, 20.5, "20", true]:
			var bad: Dictionary = dto.duplicate(true); bad.pawn_redemption_chance = invalid
			check(not VarietySchema.validate("customers", bad, "test", dto.id).is_empty(), "reject invalid probability")
		var saved := customer._pawn_redemption_chance
		customer._pawn_redemption_chance = -1
		check(not VarietySchema.domain(catalog).is_empty(), "new run rejects missing probability")
		customer._pawn_redemption_chance = saved
	check((catalog.get_definition("customers", "customer_house_agent") as CustomerDefinition).transaction_modes == ["sell"], "house agent stays sell only")
	for chance in [20, 50, 80]:
		var hits := 0
		for roll in 100:
			if PawnRedemptionPolicy.succeeds(chance, roll): hits += 1
		check(hits == chance and PawnRedemptionPolicy.succeeds(chance, chance - 1) and not PawnRedemptionPolicy.succeeds(chance, chance), "exact probability boundary %d" % chance)
	var legacy := JsonContentProvider.new("res://data/market_familiar_manifest.json").load_catalog().catalog
	var old_run := legacy.get_definition("runs", legacy.default_run_id) as RunDefinition
	var old_customer := legacy.get_definition("customers", "customer_teahouse") as CustomerDefinition
	check(old_customer.pawn_redemption_chance == -1 and not PawnRedemptionPolicy.enabled(old_run), "v19 stays opt out")
	check(PawnRedemptionPolicy.terms_for(old_run, old_customer, 42, "visit", "sample_three_default") == "sample_three_default", "old terms retained")
	var old_session := RunSession.new(old_run, 19, SaveManager.new(QA + "old.json"), legacy)
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(old_session._day.state, 19), old_run, 19, legacy, true) != null, "v19 save remains readable")

func distribution() -> void:
	var stats := {}
	var backgrounds := {}
	for id in run_def.variety.customer_ids: stats[id] = {"visits": 0, "redeems": 0}
	for seed_value in 512:
		var state := RunState.create(run_def); state.run_seed = seed_value
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		check(rows == OpeningPreparation.plan(state, run_def, catalog), "stable plan")
		for row in rows:
			if row.get("seven_role", "") == "pawn":
				check(row.terms_id == PawnRedemptionPolicy.REDEEM and row.night == 3, "protected third night return")
				continue
			if row.has("familiar_id"):
				if row.familiar_id == "seamstress": check(row.terms_id == FamiliarStories.TERMS, "familiar funds unchanged")
				continue
			if row.context_id.is_empty(): continue
			var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
			check(row.terms_id == PawnRedemptionPolicy.terms_for(run_def, customer, seed_value, row.visit_id, ""), "ordinary plan uses independent outcome")
			stats[row.customer_id].visits += 1
			if row.terms_id == PawnRedemptionPolicy.REDEEM: stats[row.customer_id].redeems += 1
			if "pawn" in row.transaction_modes:
				var text := PawnRedemptionPolicy.background(run_def, customer, row)
				check(not text.is_empty() and not text.contains("%"), "background instead of percentage")
				if backgrounds.has(customer.id): check(backgrounds[customer.id] == text, "background does not reveal outcome")
				backgrounds[customer.id] = text
		state.current_night_index = 3
		for category in ["", "stationery", "jewelry"]:
			var extra := OpeningPreparation.make_row(state, run_def, catalog, "pawn_chance_seven/3/prep_" + category, 45, category)
			var customer := catalog.get_definition("customers", extra.customer_id) as CustomerDefinition
			check(extra.terms_id == PawnRedemptionPolicy.terms_for(run_def, customer, seed_value, extra.visit_id, ""), "attract and target share policy")
	var report := "# 职业赎回概率统计\n\n固定种子0–511；统计实际基础来访及熟客覆盖后的普通职业位置，排除剧情与熟客。包括只卖断的位置，用于核对其配置；不代表实际出票率。\n\n| 职业 | 配置 | 来访数 | 赎回结果数 | 比例 |\n|---|---:|---:|---:|---:|\n"
	for id in stats:
		var customer := catalog.get_definition("customers", id) as CustomerDefinition
		var rate: float = 100.0 * stats[id].redeems / stats[id].visits
		check(stats[id].visits > 500 and absf(rate - customer.pawn_redemption_chance) < 4.0, "empirical probability " + id)
		report += "| %s | %d%% | %d | %d | %.2f%% |\n" % [customer.terms.display_name, customer.pawn_redemption_chance, stats[id].visits, stats[id].redeems, rate]
	var future := catalog.get_definition("customers", "customer_teahouse") as CustomerDefinition
	future._pawn_redemption_chance = 80
	var hits := 0
	for seed_value in 8192:
		if PawnRedemptionPolicy.terms_for(run_def, future, seed_value, "future/wealthy", "") == PawnRedemptionPolicy.REDEEM: hits += 1
	future._pawn_redemption_chance = 50
	check(absf(100.0 * hits / 8192 - 80.0) < 2.0, "future eighty percent integration")
	report += "\n未来80%%档：独立测试种子0–8191，%d/8192，%.2f%%。20/50/80各档均已遍历全部100个随机值验证边界。\n" % [hits, 100.0 * hits / 8192]
	var file := FileAccess.open(QA + "distribution.md", FileAccess.WRITE); file.store_string(report); file.close()

func snapshot(s: RunSession, name: String) -> void:
	var data := SaveCodec.new().encode(s._day.state, 20)
	var codec := SaveCodec.new()
	check(codec.decode(JSON.parse_string(JSON.stringify(data)), run_def, 20, catalog, true) != null, "checkpoint " + name + ": " + codec.error_message)
	var file := FileAccess.open(QA + name + ".json", FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
	states_written += 1

func play_ordinary(route: String) -> void:
	run_def._randomize_seed = false; run_def._seed = 42
	var manager := SaveManager.new(QA + "runtime_" + route + ".json")
	manager.library = SaveLibrary.new(QA + "library_%s_%d.json" % [route, Time.get_ticks_usec()])
	var s := RunSession.new(run_def, 20, manager, catalog)
	s.new_run()
	var origins := {}
	var chosen := {}
	for night in range(1, 8):
		driver.drain(s)
		if night >= 2:
			if night == 3:
				check(s.execute("prep_attract").ok, "real extra arrival")
				check(s.execute("prep_target", "stationery").ok, "real targeted arrival")
			check(s.execute("prep_finish").ok, "finish preparation")
		snapshot(s, "%s_%d_pre" % [route, night])
		check(s.execute("open_shop").ok, "open")
		driver.drain(s)
		while not PawnReturnService.current(s._day.state).is_empty():
			var back := PawnReturnService.current(s._day.state)
			var ticket := s._commerce.pawns.find(s._day.state, back.ticket_id)
			var before := s._day.state.cash
			check(s.counter_command("redeem", back.id).ok, "probability winner returns")
			check(s._day.state.cash - before == ticket.principal + ceili(ticket.principal * 0.1), "principal plus fee")
			check(not s.counter_command("redeem", back.id).ok, "no duplicate redemption")
		for step in 180:
			if s._day.state.game_minutes >= 470 or failures > 0: break
			driver.drain(s)
			var v := s._counter.customers.active(s._day.state)
			if v == null: check(s.execute("short_task").ok, "wait"); continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			var ordinary: bool = not row.context_id.is_empty() and not row.has("familiar_id") and row.get("seven_role", "") != "pawn"
			if ordinary and "pawn" in row.transaction_modes:
				var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
				var key := str(customer.pawn_redemption_chance)
				if route == "keep" and not fixtures.has(key):
					fixtures[key] = {"file": "%s_%d_pre.json" % [route, night], "visit_id": v.visit_id}
				var kind := "late" if night >= 5 else v.pawn_terms_id
				if night >= 3 and not chosen.has(kind):
					var amount := maxi(1, roundi(v.trade.reserve_price * 0.5)) + (3 if route == "higher" else 0)
					var planned_terms := v.pawn_terms_id
					if route == "pressure" and kind == "late":
						check(s.counter_command("appraise", v.visit_id, "observe").ok, "inspect before loan")
						check(s.counter_command("appraise", v.visit_id, "inspect").ok, "find actual defect")
						var item := catalog.get_definition("items", v.item.definition_id) as ItemDefinition
						var clues := v.item.revealed_clue_ids.filter(func(id: String) -> bool: return item.find_clue(id).leverage > 0)
						check(not clues.is_empty(), "real pressure evidence")
						if not clues.is_empty(): check(s.counter_command("pressure", v.visit_id, clues[0]).ok, "pressure before loan")
						check(s.execute("short_task").ok and v.pawn_terms_id == planned_terms, "wait without reroll")
					var unchanged := s.read_state()
					check(not s.counter_command("pawn", v.visit_id, "", 0).ok and s.read_state() == unchanged, "invalid quote neither spends time nor rerolls")
					for view in 3: s.counter_model()
					check(v.pawn_terms_id == planned_terms, "viewing does not reroll")
					check(s.counter_command("pawn", v.visit_id, "", amount).ok, "issue ordinary pawn")
					check(v.status == "pawned", "loan accepted")
					chosen[kind] = true; origins[v.visit_id] = planned_terms
					var ticket: PawnTicket = s._day.state.pawn_tickets.back()
					check(ticket.terms_id == planned_terms and ticket.due_night == night + 3, "ticket retains outcome and maturity")
					continue
			check(s.counter_command("reject", v.visit_id).ok, "reject other visitors")
		check(s.execute("close_shop").ok and s.execute("wait_until_seal").ok, "seal")
		for ticket in s._commerce.pawns.maturities(s._day.state):
			check(s.choose_pawn_disposal(ticket.ticket_id, "transfer" if route == "transfer" else "keep").ok, "choose default disposal")
		if not s._commerce.pawns.maturities(s._day.state).is_empty():
			var before := s.read_state()
			s._save.library.fail_write = true
			check(not s.execute("resolve_night").ok and s.read_state() == before, "failed disk write rolls back default and money")
			s._save.library.fail_write = false
		check(s.execute("resolve_night").ok, "resolve " + s.message)
		for action in ["enter_room", "sleep", "finish_sleep"]:
			driver.drain(s); check(s.execute(action).ok, action)
		check(s.execute("continue_run").ok, "next night")
		snapshot(s, "%s_%d_done" % [route, night])
		if failures > 0: return
	check(chosen.has(PawnRedemptionPolicy.REDEEM) and chosen.has(PawnRedemptionPolicy.DEFAULT) and chosen.has("late"), "covers return default and pending")
	for ticket in s._day.state.pawn_tickets:
		var expected := "active" if ticket.due_night > 7 else "redeemed" if ticket.terms_id == PawnRedemptionPolicy.REDEEM else "transferred" if route == "transfer" else "defaulted"
		check(ticket.status == expected, "ordinary final ownership")
		if ticket.status == "transferred":
			var postings := s._day.state.ledger_entries.filter(func(e) -> bool: return e.transaction_id == "transfer/" + ticket.ticket_id)
			check(postings.size() == 1 and postings[0].amount == floori(ticket.principal * 0.8), "eighty percent transfer")
	issued[route] = origins
	check(s._day.state.phase == &"run_ended", "seven nights completed")
