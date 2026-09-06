extends SceneTree

var passes := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/four_night_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "four night catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	print("FOUR PLAN SEED42 ", JSON.stringify(VarietyService.plan(run_def, catalog, 42)))
	var positions := {}
	var sources := {}
	for seed_value in 512:
		var rows := VarietyService.plan(run_def, catalog, seed_value)
		check(rows.size() == 16 and rows == VarietyService.plan(run_def, catalog, seed_value), "16 stable visits seed %d" % seed_value)
		var roles := {}
		var nights := [0, 0, 0, 0]
		var names: Array = []
		for row in rows:
			var customer: CustomerDefinition = catalog.get_definition("customers", row.customer_id)
			var item: ItemDefinition = catalog.get_definition("items", row.item_id)
			check(row.item_id in customer.item_pool and item.item_type == "normal" and item.find_variant(row.variant_id) != null, "compatible ordinary variant")
			check(row.person.name not in names and row.person.portrait == customer.portrait_asset_id, "unique template-matched identity")
			names.append(row.person.name)
			nights[int(row.night) - 1] += 1
			if row.has("sample_role"):
				check(not roles.has(row.sample_role), "distinct guaranteed slot")
				roles[row.sample_role] = row
				positions[row.sample_role + "/" + row.visit_id] = true
		check(nights == [4, 4, 4, 4] and roles.size() == 6, "four per night six opportunities")
		check(roles.pawn.night == 1 and roles.pawn.terms_id == "sample_three_redeem" and roles.pawn.transaction_modes == ["pawn"], "pawn guarantee")
		check(roles.hold.night <= 2 and roles.urgent.wait_minutes == 30 and roles.urgent.situation == "urgent", "hold and urgency constraints")
		check(roles.invalid.item_id == "item_blue_bowl" and roles.invalid.variant_id == "sound", "invalid reason remains real evidence")
		var appointment := OrdinarySamplePlan.appointment(rows, catalog, seed_value)
		check(appointment.night > roles.hold.night and appointment.night <= 4 and appointment.capacity == 1, "future bounded buyer")
		sources[roles.source.source] = true
	check(sources.size() == 2 and positions.size() > 60, "both source branches and randomized seats")
	for route in ["pawn", "reject", "early", "hold", "sell", "future", "default", "bargain"]: play(route)
	integrated_rules()
	urgency()
	legacy()
	print("FOUR NIGHT TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func session(seed_value: int, path: String) -> RunSession:
	var s := RunSession.new(run_def, 11, SaveManager.new(path), catalog)
	s._day.state.run_seed = seed_value
	s._day.state.ordinary_selections.clear()
	s._day.state.scenario_selections.clear()
	s._counter.customers.prepare_night(s._day.state, run_def, catalog)
	return s

func command(s: RunSession, action: String) -> bool:
	var result := s.execute(action)
	check(result.ok, action + ": " + result.message)
	return result.ok

func restored(s: RunSession) -> bool:
	var before := s.read_state()
	var result := s.load_checkpoint()
	check(result.ok and s.read_state() == before, "checkpoint exact: " + result.message)
	return result.ok

func play(route: String) -> void:
	var seed_value := 42
	if route == "default":
		for candidate in 512:
			if VarietyService.plan(run_def, catalog, candidate).any(func(r: Dictionary) -> bool: return r.night == 1 and r.terms_id == "sample_three_default" and r.get("sample_role", "").is_empty() and "pawn" in (catalog.get_definition("customers", r.customer_id) as CustomerDefinition).transaction_modes):
				seed_value = candidate
				break
	var s := session(seed_value, "user://tests/four_" + route + ".json")
	var collateral := ""
	var held := ""
	for night in range(1, 5):
		if night > 1 and not restored(s): return
		if not command(s, "open_shop"): return
		var returning := PawnReturnService.current(s._day.state)
		if not returning.is_empty():
			check(night == 4 and route == "pawn", "only actual loan returns")
			check(returning.item_instance_id == collateral and s._day.state.visits[0].arrival == 10, "same item return shifts arrivals")
			check(not s.execute("close_shop").ok, "return priority blocks closing")
			check(s.counter_command("redeem", returning.id).ok, "original owner redemption")
			check(not s.counter_command("redeem", returning.id).ok, "redemption cannot repeat")
		if route == "early": command(s, "close_shop")
		else:
			var guard := 0
			while s._day.state.game_minutes < 500 and guard < 150:
				guard += 1
				var appointment := s._day.state.buyer_appointment
				if route == "hold" and not held.is_empty() and night == appointment.night and s._day.state.game_minutes >= 60:
					var item := InventoryManager.new().find(s._day.state, held)
					if item.ownership_state == "owned":
						var high := s._commerce.quote(item, catalog.get_definition("buyers", "buyer_appointment"))
						var low := s._commerce.quote(item, catalog.get_definition("buyers", "buyer_recycler"))
						check(high > low, "waiting yields actual higher receipt")
						check(s.commerce_command("sell", held, "buyer_appointment").ok, "appointment sale")
				var visit := s._counter.customers.active(s._day.state)
				if visit == null:
					if not command(s, "short_task"): return
					continue
				var row := VarietySaveCodec.selection(s._day.state, visit.visit_id)
				var role: String = row.get("sample_role", "")
				if route == "bargain":
					check(s.counter_command("belittle", visit.visit_id).ok, "v11 recorded personality action")
					var after := s.read_state()
					check(not s.counter_command("belittle", visit.visit_id).ok and after == s.read_state(), "repeated live belittle never advances")
					if visit.status == "active": check(s.counter_command("reject", visit.visit_id).ok, "leave after trial")
				elif (route == "future" and night == 4 and "pawn" in visit.transaction_modes and s._day.state.pawn_tickets.is_empty()) or (route == "default" and night == 1 and role.is_empty() and row.terms_id == "sample_three_default" and "pawn" in visit.transaction_modes and s._day.state.pawn_tickets.is_empty()):
					check(s.counter_command("pawn", visit.visit_id, "", 40).ok, "additional three-night contract")
				elif route == "pawn" and role == "pawn":
					check(not s.counter_command("offer", visit.visit_id, "", 100).ok, "pawn only guards purchase")
					var loan := maxi(30, roundi(visit.trade.reserve_price * 0.5))
					check(s.counter_command("pawn", visit.visit_id, "", loan).ok, "first night loan")
					if s._day.state.pawn_tickets.is_empty(): return
					var ticket := s._day.state.pawn_tickets[0]
					collateral = ticket.item_instance_id
					check(ticket.due_night == 4 and ticket.redemption_amount == loan + ceili(loan * 0.1), "three night fixed rounded fee")
					check(not s.commerce_command("sell", collateral, "buyer_recycler").ok, "collateral locked")
				elif route in ["hold", "sell"] and role == "hold":
					check(s.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "acquire hold opportunity")
					held = visit.item.instance_id
					if route == "sell": check(s.commerce_command("sell", held, "buyer_recycler").ok, "same night liquidation")
				else: check(s.counter_command("reject", visit.visit_id).ok, "optional opportunity rejected")
		if not command(s, "wait_until_seal"): return
		for ticket in s._commerce.pawns.maturities(s._day.state): check(s.choose_pawn_disposal(ticket.ticket_id, "keep").ok, "choose unredeemed collateral")
		if not command(s, "resolve_night"): return
		if not restored(s): return
		for action in ["enter_room", "sleep", "finish_sleep"]:
			if not command(s, action) or not restored(s): return
		if night in [2, 3] and route == "pawn": check(s._day.state.pawn_tickets[0].status == "active", "intermediate collateral persists")
		if not command(s, "continue_run"): return
	check(s.read_state().phase == "run_ended" and s._day.state.summaries.size() == 4, "fourth full night ends")
	check(s.definition.fee_policy.principal == 500 and s._day.state.fee_history.size() == 4, "debt retained four daily fees")
	if route in ["reject", "early"]: check(s._day.state.cash == 260 and s._day.state.pawn_returns.is_empty(), "no forced trade/return and cost40")
	if route == "future": check(s._day.state.pawn_tickets.size() == 1 and s._day.state.pawn_tickets[0].due_night == 7 and s._day.state.pawn_tickets[0].status == "active", "final summary retains future ticket")
	if route == "default": check(s._day.state.pawn_tickets.size() == 1 and s._day.state.pawn_tickets[0].status == "defaulted" and s._day.state.pawn_returns.is_empty(), "unredeemed three-night collateral retained at night4")
	var payload := SaveCodec.new().encode(s._day.state, 11)
	payload.buyer_appointment.night = 1
	check(SaveCodec.new().decode(payload, run_def, 11, catalog) == null, "tampered appointment refused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s._save.path))

func urgency() -> void:
	for exhaustive in [false, true]:
		var state := RunState.create(run_def)
		state.run_seed = 42
		var rows := VarietyService.plan(run_def, catalog, 42)
		var row: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r.get("sample_role") == "urgent")[0]
		state.current_night_index = row.night
		CustomerManager.new().prepare_night(state, run_def, catalog)
		state.phase = &"open"
		state.game_minutes = row.arrival
		state.visits = state.visits.filter(func(v: CustomerVisit) -> bool: return v.visit_id == row.visit_id)
		var service := CounterService.new(catalog)
		service.customers.update(state)
		var day := DayController.new(run_def, state)
		var visit := service.customers.active(state)
		check(service.execute(day, "appraise", visit.visit_id, "observe").ok, "urgent overview")
		check(service.execute(day, "appraise", visit.visit_id, "inspect").ok, "urgent focused inspection")
		if exhaustive:
			day.spend_action(10)
		var result := service.execute(day, "offer", visit.visit_id, "", visit.trade.reserve_price)
		check(result.ok != exhaustive and state.inventory_instances.size() == (0 if exhaustive else 1), "deadline effect excluded/focused trade succeeds")

func legacy() -> void:
	for manifest in ["res://data/legacy/content_v10.json", "res://data/legacy/content_v10_100_300.json"]:
		var old := JsonContentProvider.new(manifest).load_catalog()
		check(old.is_success(), "frozen v10 valid")
		if not old.is_success(): continue
		var definition: RunDefinition = old.catalog.get_definition("runs", old.catalog.default_run_id)
		var path := "user://tests/four_old_%d.json" % definition.initial_cash
		var source := RunSession.new(definition, 10, SaveManager.new(path), old.catalog)
		# The original event director handles the old opening events.
		while not source._day.state.pending_event_id.is_empty():
			var event: EventDefinition = old.catalog.get_definition("events", source._day.state.pending_event_id)
			source.event_command(event.id, event.choices[0].id)
		command(source, "open_shop")
		command(source, "close_shop")
		command(source, "wait_until_seal")
		command(source, "resolve_night")
		var saves := SaveManager.new(path)
		saves.catalog = catalog
		var restored_state := saves.load_state(run_def, 11)
		check(restored_state != null and saves.loaded_definition.initial_cash == definition.initial_cash, "old v10 exact economy recognized")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func integrated_rules() -> void:
	var helper := VarietyTests.new()
	helper._expect = check
	helper.catalog = catalog
	helper.run_def = run_def
	helper._content_matrix()
	helper._provenance_money()
	var terms: PawnTermsDefinition = catalog.get_definition("pawn_terms", "sample_three_redeem")
	for principal in [1, 9, 10, 11, 29, 30, 31, 99, 100, 101]:
		var object: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
		var fixture := helper.unit(object, object.find_variant("sound"))
		PawnController.new().issue(fixture.state, fixture.state.visits[0], terms, principal)
		check(fixture.state.pawn_tickets[0].redemption_amount == principal + int((principal + 9) / 10), "three-night fee integer rounding %d" % principal)
	var service := CounterService.new(catalog)
	var item: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
	for customer_id in run_def.variety.customer_ids:
		for situation in ["ordinary", "urgent"]:
			var day := helper.unit(item, item.find_variant("sound"), "none", customer_id)
			var visit := day.state.visits[0]
			visit.situation_id = situation
			var customer: CustomerDefinition = catalog.get_definition("customers", customer_id)
			var original := visit.trade.asking_price
			var reserve := visit.trade.reserve_price
			check(service.execute(day, "belittle", visit.visit_id).ok, "integrated personality action")
			var discount: int = customer.belittle[situation + "_discount"] if customer.belittle.reaction == "yielding" else 0
			check(visit.trade.asking_price == original - discount and visit.trade.reserve_price == reserve - discount, "all eight profiles preserve quote relationship")
			var before := day.state.to_read_model()
			check(not service.execute(day, "belittle", visit.visit_id).ok and day.state.to_read_model() == before, "shared one-use action")
			check(day.state.cash == 300 and day.state.ledger_entries.is_empty() and service.appraisal.valuation(visit.item, item) == Vector2i(item.unknown_min, item.unknown_max), "belittle never changes value or finances")
