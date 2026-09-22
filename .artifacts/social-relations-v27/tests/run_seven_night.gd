extends SceneTree

var passes := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error("FAIL " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/seven_night_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "seven catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "ordinary_seven")
	run_def._randomize_seed = false
	var schedules := {}
	var contexts := {}
	for seed_value in 512:
		var rows := VarietyService.plan(run_def, catalog, seed_value)
		check(rows.size() == 42 and rows == VarietyService.plan(run_def, catalog, seed_value), "42 stable visits")
		var roles := {}
		var names: Array = []
		for i in rows.size():
			var row: Dictionary = rows[i]
			var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
			var item := catalog.get_definition("items", row.item_id) as ItemDefinition
			check(row.night == int(i / 6) + 1 and item.item_type == "normal" and row.item_id in customer.item_pool and item.find_variant(row.variant_id) != null, "compatible six per night i=%d row=%s" % [i, JSON.stringify(row)])
			var limits: Array = [[0, 120], [120, 300], [300, 450]][(i % 6) / 2]
			check(row.arrival >= limits[0] and row.arrival <= limits[1] and row.arrival % 5 == 0, "arrival bands")
			if i % 6 != 0: check(row.arrival - rows[i-1].arrival >= 15, "15 minute spacing")
			if i > 0: check(row.customer_id != rows[i-1].customer_id and row.item_id != rows[i-1].item_id, "no adjacent repeat")
			check(not rows.slice(maxi(0, i-6), i).any(func(old: Dictionary) -> bool: return old.customer_id == row.customer_id and old.item_id == row.item_id and old.context_id == row.context_id), "six seat context diversity")
			check(row.person.name not in names, "unique people")
			names.append(row.person.name)
			if row.night < 3: check(row.transaction_modes == ["sell"], "pawn opens night three")
			if row.has("seven_role"): roles[row.seven_role] = row
			contexts[row.context_id] = true
		check(roles.size() == 7 and roles.pawn.night == 3 and roles.pawn.terms_id == "sample_three_redeem", "guaranteed opportunities")
		check(roles.urgent.wait_minutes == 30 and roles.urgent.situation == "urgent", "urgent contract")
		check(roles.pen4.night == 4 and roles.pen5.night == 5 and roles.pen4.variant_id != roles.pen5.variant_id, "two pen opportunities")
		check(rows[0].arrival == 0, "tutorial first visitor")
		schedules[JSON.stringify(rows.map(func(row: Dictionary) -> int: return row.arrival))] = true
	check(schedules.size() > 500 and contexts.size() == 16, "random schedules and all contexts")
	for route in ["early", "reject", "hold", "sell", "informed"]: play(route)
	print("SEVEN NIGHT TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func session(path: String) -> RunSession:
	run_def._seed = 42
	return RunSession.new(run_def, 13, SaveManager.new(path), catalog)

func command(s: RunSession, action: String) -> bool:
	var result := s.execute(action)
	check(result.ok, action + ": " + result.message)
	return result.ok

func play(route: String) -> void:
	var s := session("user://tests/seven_" + route + ".json")
	for night in range(1, 8):
		if night >= 4:
			check(not s.execute("open_shop").ok, "finish preparation first")
			if route in ["hold", "sell", "informed"] and night == 4:
				command(s, "prep_investigate")
				command(s, "prep_contact")
				check(not s.execute("prep_visitors").ok and s._day.state.game_minutes == 0, "two free preparation slots")
			else:
				command(s, "prep_visitors")
				var before := s.read_state()
				check(not s.execute("prep_visitors").ok and s.read_state() == before, "intel cannot reroll")
			var before := s.read_state()
			check(s.load_checkpoint().ok and s.read_state() == before, "preparation checkpoint exact")
			command(s, "prep_finish")
		command(s, "open_shop")
		var returning := PawnReturnService.current(s._day.state)
		if not returning.is_empty():
			check(night == 6, "third night loan returns sixth")
			check(s.counter_command("redeem", returning.id).ok, "original owner redemption")
		if route != "early":
			var guard := 0
			while s._day.state.game_minutes < 480 and guard < 140:
				guard += 1
				var active := s._counter.customers.active(s._day.state)
				if active != null:
					var row := VarietySaveCodec.selection(s._day.state, active.visit_id)
					var role: String = row.get("seven_role", "")
					if role == "pawn" and route == "hold":
						check(s.counter_command("pawn", active.visit_id, "", 40).ok, "three night pawn")
					elif role in ["pen4", "pen5"] and route in ["hold", "sell", "informed"]:
						if route == "informed":
							check(s.counter_command("appraise", active.visit_id, "observe").ok, "pen form")
							check(s.counter_command("appraise", active.visit_id, "inspect").ok, "inspect writing condition")
							if "condition_replacement_nib" in active.item.revealed_clue_ids: check(s.counter_command("pressure", active.visit_id, "condition_replacement_nib").ok, "replacement discount has evidence")
							var pen := catalog.get_definition("items", active.item.definition_id) as ItemDefinition
							var known := AppraisalSystem.new().valuation(active.item, pen)
							check(s.counter_command("offer", active.visit_id, "", int((known.x + known.y) / 2)).ok, "quote from known evidence")
						else: check(s.counter_command("offer", active.visit_id, "", active.trade.asking_price).ok, "acquire pen")
					else: check(s.counter_command("reject", active.visit_id).ok, "reject ordinary customer")
				else:
					var buyer: String = PreparationService.BUYER if route in ["hold", "informed"] else "buyer_recycler"
					var stock := s._day.state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.ownership_state == "owned")
					if route in ["hold", "sell", "informed"] and not stock.is_empty() and s._commerce.trip_reason(s._day, catalog.get_definition("buyers", buyer)).is_empty():
						check(s.sell_batch(buyer, stock.map(func(item: ItemInstance) -> String: return item.instance_id)).ok, "batch sale")
					else: command(s, "short_task")
		command(s, "close_shop")
		command(s, "wait_until_seal")
		for action in ["resolve_night", "enter_room", "sleep", "finish_sleep"]:
			if not command(s, action): return
			var before := s.read_state()
			var loaded := s.load_checkpoint()
			check(loaded.ok and before == s.read_state(), "checkpoint " + action + ": " + loaded.message)
			if not loaded.ok: return
		command(s, "continue_run")
	check(s._day.state.phase == &"run_ended" and s._day.state.summaries.size() == 7, "seven night completion")
	check(s._day.state.fee_history.size() == 7, "seven daily fees")
	var revenue := 0
	var cost := 0
	for sale in s._day.state.sale_records: revenue += sale.price; cost += sale.cost_basis
	print("SEVEN ROUTE ", route, " cash=", s._day.state.cash, " sales=", revenue, " cost=", cost, " margin=", revenue - cost)
	if route == "informed": check(s._day.state.sale_records.size() == 2 and revenue > cost, "visible evidence makes waiting profitable")
	if route == "hold": check(s._day.state.sale_records.size() == 2 and s._day.state.pawn_tickets[0].status == "redeemed", "held goods and owner return")
