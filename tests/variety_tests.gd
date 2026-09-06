class_name VarietyTests
extends RoomTests

var seeds: Dictionary = {}
var batch_results: Array = []

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://data/legacy/content_v10.json").load_catalog()
	_expect.call(loaded.is_success(), "v10 production catalog")
	for issue in loaded.issues: print(issue.format_message())
	if not loaded.is_success(): return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_random_contract()
	_content_matrix()
	_watchmaker()
	_provenance_money()
	_checkpoint_sources()
	_pawn_identity()
	_old_content()
	_batch()
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func seeded(seed_value: int) -> RunSession:
	var s := session()
	s._day.state.run_seed = seed_value
	s._day.state.ordinary_selections.clear()
	s._day.state.scenario_selections.clear()
	s._counter.customers.prepare_night(s._day.state, run_def, catalog)
	return s

func _random_contract() -> void:
	var variants := {}
	var sources := {}
	var customers := {}
	var same_template := false
	var same_item := false
	for seed_value in 512:
		var plan := VarietyService.plan(run_def, catalog, seed_value)
		_expect.call(plan == VarietyService.plan(run_def, catalog, seed_value), "stable independent streams %d" % seed_value)
		_expect.call(plan.size() == 12, "four slots each night")
		var names: Array = []
		var prior := {}
		for row in plan:
			var customer: CustomerDefinition = catalog.get_definition("customers", row.customer_id)
			_expect.call(row.person.name not in names and row.person.id == "person/" + row.visit_id and row.person.portrait == customer.portrait_asset_id, "distinct name and identity")
			names.append(row.person.name)
			_expect.call(row.item_id in customer.item_pool, "compatible item")
			if row.visit_id.ends_with("n3_visit1"):
				_expect.call(row.item_id == "item_weeping_mirror" and row.variant_id == "weeping", "fixed ghost")
			elif row.visit_id.ends_with("n3_visit4"):
				_expect.call(row.item_id == "item_pocket_watch" and row.variant_id == "flawed", "mirror-linked flawed watch")
			else:
				customers[row.customer_id] = true
				variants[row.item_id + "/" + row.variant_id] = true
				sources[row.item_id + "/" + row.source] = true
				if not prior.is_empty():
					same_template = same_template or prior.customer_id == row.customer_id
					same_item = same_item or prior.item_id == row.item_id
				prior = row
		var first: Dictionary = plan[0]
		for key in [first.customer_id, first.item_id + "/" + first.source, "term/" + first.terms_id]:
			if not seeds.has(key): seeds[key] = seed_value
	_expect.call(customers.size() == 8 and variants.size() == 24 and sources.size() == 24, "all templates, variants and sources represented")
	_expect.call(same_template and same_item, "repeats allowed")
	var s := seeded(42)
	open(s)
	var before := s.read_state()
	for index in 10: s.counter_model(); s.risk_model(); s.event_model()
	_expect.call(before == s.read_state(), "panels never reroll")
	var original := s._day.state.ordinary_selections.duplicate(true)
	action(s, "appraise", "observe")
	action(s, "question", "origin")
	_expect.call(original == s._day.state.ordinary_selections, "appraisal and questions never reroll")
	for id in ["seamstress", "watchmaker", "teahouse", "bookkeeper"]:
		_expect.call(CounterVisualCatalog.portrait("asset.customer_" + id) != null, "portrait " + id)

# A bounded unit fixture covers every content branch without changing production RNG.
func unit(item: ItemDefinition, variant: ItemVariantDefinition, source := "none", customer_id := "customer_teahouse") -> DayController:
	var state := RunState.create(run_def)
	state.phase = &"open"
	var visit := CustomerVisit.new()
	visit.visit_id = "unit/visit"
	visit.customer_id = customer_id
	visit.person = {"id": "unit/person", "name": "测试当户", "portrait": ""}
	var customer: CustomerDefinition = catalog.get_definition("customers", customer_id)
	visit.voice = customer.persona
	visit.voice["source_claim"] = item.provenance.claim
	visit.item = ItemInstance.new()
	visit.item.instance_id = "item/unit/visit"
	visit.item.definition_id = item.id
	visit.item.selected_variant_id = variant.id
	visit.item.provenance = {"truth": source, "status": "unchecked", "evidence": [], "investigated": false}
	visit.expires_at = customer.terms.wait_minutes
	visit.trade.patience = customer.patience
	visit.trade.rounds_left = customer.max_quote_rounds
	visit.trade.opening_price = maxi(1, roundi(item.base_value * customer.terms.ask_multiplier))
	visit.trade.asking_price = visit.trade.opening_price
	visit.trade.reserve_price = maxi(1, roundi(visit.trade.opening_price * customer.terms.reserve_ratio))
	visit.scenario_id = TradeScenarioService.for_item(run_def, item.id).id
	visit.situation_id = "ordinary"
	visit.reaction_id = "admit"
	state.visits.append(visit)
	CustomerManager.new().update(state)
	return DayController.new(run_def, state)

func _content_matrix() -> void:
	var service := CounterService.new(catalog)
	var legacy := JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog().catalog
	for item: ItemDefinition in catalog.get_all("items"):
		if item.item_type != "normal": continue
		var old: ItemDefinition = legacy.get_definition("items", item.id)
		_expect.call(item.possible_variants.size() == 3 and item.appraisal_actions.size() == 3, "three variants / observation and two checks " + item.id)
		for v: ItemVariantDefinition in old.possible_variants:
			_expect.call(item.find_variant(v.id).true_value == v.true_value, "stable existing value")
		for clue: ClueDefinition in old.clues:
			_expect.call(item.find_clue(clue.id).leverage == clue.leverage, "stable existing discount")
		for variant: ItemVariantDefinition in item.possible_variants:
			for truth in ["none", "authentic", "mismatch"]:
				for reverse in [false, true]:
					var day := unit(item, variant, truth)
					var visit: CustomerVisit = day.state.visits[0]
					_expect.call(not service.execute(day, "verify_source", visit.visit_id).ok, "origin question required")
					var actions := item.appraisal_actions.duplicate()
					if reverse: actions = [actions[0], actions[2], actions[1]]
					var bounds := service.appraisal.valuation(visit.item, item)
					for step: AppraisalActionDefinition in actions:
						_expect.call(step.minutes in [5, 10] and service.execute(day, "appraise", visit.visit_id, step.id).ok, "dedicated check " + item.id + "/" + variant.id)
						var next := service.appraisal.valuation(visit.item, item)
						_expect.call(next.x <= variant.true_value and next.y >= variant.true_value and next.x >= bounds.x and next.y <= bounds.y, "honest narrowing")
						bounds = next
					var clues := visit.item.revealed_clue_ids.duplicate()
					_expect.call(service.execute(day, "question", visit.visit_id, "condition").ok and clues == visit.item.revealed_clue_ids, "testimony is not evidence")
					var scenario := TradeScenarioService.for_item(run_def, item.id)
					var answers := {}
					for reaction in ["admit", "explain", "evade"]:
						visit.reaction_id = reaction
						answers[scenario.find_question("condition").answer(visit)] = true
					_expect.call(answers.size() == 3, "condition testimony has three responses")
					visit.reaction_id = "admit"
					for q in scenario.questions:
						if q.pressure_clue.is_empty() or q.pressure_clue not in clues: continue
						var used := TradeScenarioService.used(visit, scenario, q.pressure_clue)
						var price := visit.trade.asking_price
						_expect.call(service.execute(day, "question", visit.visit_id, q.id).ok, "evidence challenge")
						_expect.call(visit.trade.asking_price == price if used else visit.trade.asking_price < price, "discount applied once")
						var before := day.state.to_read_model()
						_expect.call(not service.execute(day, "pressure", visit.visit_id, q.pressure_clue).ok and before == day.state.to_read_model(), "question / pressure discount group")
					_expect.call(service.execute(day, "question", visit.visit_id, "origin").ok, "item origin claim")
					_expect.call(service.execute(day, "verify_source", visit.visit_id).ok and visit.item.provenance.status == ProvenanceService.outcome(truth), "source truth fixed")
					var before := day.state.to_read_model()
					_expect.call(not service.execute(day, "verify_source", visit.visit_id).ok and before == day.state.to_read_model(), "counter source cannot repeat")

func _watchmaker() -> void:
	for command in ["offer", "pressure", "evidence"]:
		var s := seeded(seeds.customer_watchmaker)
		open(s)
		var visit := active(s)
		_expect.call(visit.trade.patience == 1 and visit.trade.rounds_left == 3, "watchmaker 1 patience / 3 rounds")
		if command == "offer": action(s, "offer", "", 1)
		elif command == "pressure":
			action(s, "appraise", "observe")
			action(s, "pressure", visit.item.revealed_clue_ids[0])
		else:
			var item: ItemDefinition = catalog.get_definition("items", visit.item.definition_id)
			var flawed: ItemVariantDefinition = item.possible_variants[1]
			var day := unit(item, flawed, "none", "customer_watchmaker")
			visit = day.state.visits[0]
			var service := CounterService.new(catalog)
			for step in item.appraisal_actions: service.execute(day, "appraise", visit.visit_id, step.id)
			for clue in visit.item.revealed_clue_ids:
				if item.find_clue(clue).leverage > 0:
					_expect.call(service.execute(day, "pressure", visit.visit_id, clue).ok and visit.trade.patience == 1 and visit.status == "active", "valid evidence preserves patience")
					break
			continue
		_expect.call(visit.status == "patience_exhausted", "watchmaker leaves after one failed offer / wrong pressure")

func _provenance_money() -> void:
	var service := CommerceService.new(catalog)
	for item: ItemDefinition in catalog.get_all("items"):
		if item.item_type != "normal": continue
		for truth in ["none", "authentic", "mismatch"]:
			var day := unit(item, item.possible_variants[0], truth)
			var visit: CustomerVisit = day.state.visits[0]
			var obj := visit.item
			var base_cost := 15
			InventoryManager.new().acquire(day.state, obj, visit.visit_id, base_cost)
			CustomerManager.new().finish(day.state, visit, "bought")
			var before := day.state.cash
			_expect.call(service.execute(day, "inquire", obj.instance_id, "").ok, "stock source inquiry")
			_expect.call(day.state.cash == before - 2 and day.state.game_minutes == 10 and obj.acquisition_price == base_cost, "2 silver / 10 minutes / unchanged cost")
			var after := day.state.to_read_model()
			_expect.call(not service.execute(day, "inquire", obj.instance_id, "").ok and after == day.state.to_read_model(), "no repeat charge")
			for buyer: BuyerDefinition in catalog.get_all("buyers"):
				var base := maxi(1, roundi(item.possible_variants[0].true_value * buyer.value_multiplier))
				var premium := floori(base * 0.15) if truth == "authentic" and buyer.id in ["buyer_collector", "buyer_introduced", "buyer_appointment"] else 0
				_expect.call(service.quote(obj, buyer) == base + premium, "buyer-specific premium and floor")
			var summary := FinancialSummary.build(day.state)
			_expect.call(summary.operating_profit == -2 and summary.realized_profit == 0 and summary.inventory_cost == base_cost, "investigation is expense only")
	var item: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
	for mode in ["cash", "time", "pledged", "sold", "verified", "mismatch"]:
		var day := unit(item, item.possible_variants[0])
		var obj: ItemInstance = day.state.visits[0].item
		InventoryManager.new().acquire(day.state, obj, "unit/visit", 15)
		match mode:
			"cash": day.state.cash = 1
			"time": day.state.game_minutes = run_def.night_minutes - 5
			"pledged", "sold": obj.ownership_state = mode
			_: obj.provenance.status = mode
		var before := day.state.to_read_model()
		_expect.call(not service.execute(day, "inquire", obj.instance_id, "").ok and before == day.state.to_read_model(), "inquiry guard " + mode)

func finish(s: RunSession) -> bool:
	events(s)
	if not s.execute("wait_until_seal").ok: return false
	for row in s.pawn_disposal_model(): s.choose_pawn_disposal(row.id, "keep")
	var result := s.execute("resolve_night")
	_expect.call(result.ok, "v10 checkpoint: " + result.message)
	return result.ok

func _checkpoint_sources() -> void:
	for truth in ["none", "authentic", "mismatch"]:
		for counter in [false, true]:
			var s := seeded(seeds["item_blue_bowl/" + truth])
			open(s)
			var visit := active(s)
			if counter:
				action(s, "question", "origin")
				action(s, "verify_source")
			action(s, "offer", "", visit.trade.reserve_price)
			var obj: ItemInstance = s._day.state.inventory_instances[0]
			var expense := 0
			if not counter or truth == "none":
				_expect.call(s.commerce_command("inquire", obj.instance_id).ok, "production paid inquiry")
				expense = 2
			var price := s._commerce.quote(obj, catalog.get_definition("buyers", "buyer_recycler"))
			_expect.call(s.commerce_command("sell", obj.instance_id, "buyer_recycler").ok, "production sale")
			if not finish(s): continue
			resume(s, "source " + truth)
			var summary: Dictionary = s.read_state().summaries.back()
			_expect.call(summary.provenance_expense == expense and summary.realized_profit == price - obj.acquisition_price and summary.operating_profit == summary.realized_profit - expense - run_def.fee_policy.interest - run_def.fee_policy.overhead, "fees and sale gross margin separate")
			var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
			for change in ["truth", "name", "source", "fee", "history", "shape"]:
				var corrupt: Dictionary = payload.duplicate(true)
				match change:
					"truth": corrupt.ordinary_selections[0].source = "tampered"
					"name": corrupt.ordinary_selections[0].person.name = "冒名"
					"source": corrupt.inventory_instances[0].provenance.status = "unchecked"
					"fee": corrupt.summaries[0].provenance_expense += 2
					"history": corrupt.provenance_history.append(corrupt.provenance_history[0])
					"shape": corrupt.scenario_history = [3]
				_expect.call(SaveCodec.new().decode(corrupt, run_def, catalog.content_version, catalog) == null, "reject corrupt source save " + change)

func _pawn_identity() -> void:
	for term in ["short_redeem", "short_default"]:
		var s := seeded(seeds["term/" + term])
		open(s)
		var visit := active(s)
		var person := visit.person.duplicate(true)
		var terms: PawnTermsDefinition = catalog.get_definition("pawn_terms", term)
		var principal := maxi(1, roundi(visit.trade.reserve_price * terms.loan_ratio))
		action(s, "pawn", "", principal)
		var ticket: PawnTicket = s._day.state.pawn_tickets[0]
		_expect.call(ticket.person == person and ticket.item_instance_id == visit.item.instance_id, "pawn identity snapshot")
		_expect.call(not s.commerce_command("inquire", ticket.item_instance_id).ok, "pledged inquiry blocked")
		if not finish(s): continue
		finish_room(s)
		_expect.call(s.execute("continue_run").ok, "next night for original owner")
		resume(s, "before original owner")
		open(s)
		if term == "short_redeem":
			var current := PawnReturnService.current(s._day.state)
			_expect.call(current.person == person and s.counter_model().visual.portrait_asset == person.portrait and s.counter_model().customer.contains(person.name), "return identity and portrait")
			_expect.call(s._day.state.visits[0].arrival == 10, "ordinary schedule shifted")
			_expect.call(not s.counter_command("redeem", s._day.state.visits[0].visit_id).ok, "other same-template visitor cannot redeem")
			_expect.call(s.counter_command("redeem", current.id).ok, "original owner redeems")
		else:
			_expect.call(PawnReturnService.current(s._day.state).is_empty(), "absent owner no imaginary redemption")
		if not finish(s): continue
		resume(s, "owner / default")
		if term == "short_default":
			finish_room(s)
			s.execute("continue_run")
			open(s)
			_expect.call(s.commerce_command("inquire", ticket.item_instance_id).ok, "retained collateral can be investigated following night")
			if finish(s): resume(s, "retained inquiry")

func _old_content() -> void:
	var old_catalog := JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog().catalog
	var old_run: RunDefinition = old_catalog.get_definition("runs", "p0_room")
	var old_path := "user://tests/variety_old9.json"
	var new_path := "user://tests/variety_import10.json"
	paths.append_array([old_path, new_path])
	var old := RunSession.new(old_run, 9, SaveManager.new(old_path), old_catalog)
	open(old)
	seal(old)
	var payload := SaveCodec.new().encode(old._day.state, 9)
	payload.save_version = 9
	var f := FileAccess.open(old_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload)); f.close()
	var original := FileAccess.get_file_as_string(old_path)
	var saver := SaveManager.new(new_path)
	saver.import_checkpoint_path = old_path
	var s := RunSession.new(run_def, 10, saver, catalog)
	_expect.call(s.load_checkpoint().ok and s.content_version == 9 and s.definition.id == "p0_room", "v9 continues old content")
	_expect.call(s.read_state() == old.read_state(), "old financial and item state unchanged")
	_expect.call(s.execute("enter_room").ok and FileAccess.get_file_as_string(old_path) == original, "import writes new file and preserves old")
	s.new_run()
	_expect.call(s.content_version == 10 and s.definition.id == "p0_variety" and s.read_state().ordinary_selections.size() == 4, "new game switches to v10")

func _batch() -> void:
	# A player-available strategy: inspect, bargain on revealed defects, make one
	# offer at the lower known estimate, then select an available buyer.
	for seed_value in [0, 1, 7, 42, 73, 121, 255, 511]:
		var s := seeded(seed_value)
		var trades := 0
		for night in 3:
			open(s)
			for guard in 110:
				events(s)
				var visit := active(s)
				if visit != null:
					var item: ItemDefinition = catalog.get_definition("items", visit.item.definition_id)
					if item.item_type == "normal":
						for step in item.appraisal_actions: action(s, "appraise", step.id)
						for clue in visit.item.revealed_clue_ids:
							if item.find_clue(clue).leverage > 0:
								if s._counter.reason(s._day, "pressure", visit.visit_id, clue).is_empty(): action(s, "pressure", clue)
						var offer := s._counter.appraisal.valuation(visit.item, item).x
						if visit.status == "active" and s.read_state().cash >= offer:
							action(s, "offer", "", offer)
							if visit.status == "bought":
								trades += 1
								var best := ""
								var price := -1
								for buyer: BuyerDefinition in catalog.get_all("buyers"):
									if s._commerce.sale_reason(s._day, visit.item, buyer).is_empty() and s._commerce.quote(visit.item, buyer) > price:
										best = buyer.id
										price = s._commerce.quote(visit.item, buyer)
								if not best.is_empty(): s.commerce_command("sell", visit.item.instance_id, best)
					if visit.status == "active": action(s, "reject")
				elif s._day.state.visits.all(func(v: CustomerVisit) -> bool: return v.status not in ["scheduled", "waiting", "active"]): break
				else: s.execute("short_task")
			if not finish(s): break
			finish_room(s)
			s.execute("continue_run")
		_expect.call(s.read_state().phase == "run_ended", "three-night executable route %d" % seed_value)
		_expect.call(trades > 0, "ordinary transactions executable %d" % seed_value)
		batch_results.append({"seed": seed_value, "cash": s.read_state().cash, "trades": trades, "minutes": s.read_state().summaries.map(func(r: Dictionary) -> int: return r.closed_at)})
	print("VARIETY BATCH ", JSON.stringify(batch_results))
