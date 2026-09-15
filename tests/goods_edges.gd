extends "res://tests/run_goods_expertise.gd"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	unit_goods()
	var service := CommerceService.new(catalog)
	var buyer := catalog.get_definition("buyers", "buyer_collector") as BuyerDefinition
	var day := DayController.new(run_def, RunState.create(run_def)); day.state.phase = &"open"
	var fan := make_item(GoodsExpertise.FAN, "sound", "fan"); day.state.inventory_instances.append(fan)
	for variant in ["sound", "flawed", "mended"]:
		fan.selected_variant_id = variant; fan.expert_reviewed = false
		var def := catalog.get_definition("items", fan.definition_id) as ItemDefinition
		for buyer_id in run_def.buyer_ids:
			var b := catalog.get_definition("buyers", buyer_id) as BuyerDefinition
			check(service.quote(fan, b) == maxi(1, roundi(20 * b.value_multiplier)), "all unreviewed buyer quotes")
			fan.expert_reviewed = true
			check(service.quote(fan, b) == maxi(1, roundi(def.find_variant(variant).true_value * b.value_multiplier)), "all reviewed buyer quotes")
			fan.expert_reviewed = false
	for id in ["item_silver_ring", "item_silver_lock", GoodsExpertise.FAN, GoodsExpertise.CUP]:
		var def := catalog.get_definition("items", id) as ItemDefinition
		for variant in def.possible_variants:
			var item := make_item(id, variant.id, id)
			for action in def.appraisal_actions:
				check(action.minutes == 5 and not AppraisalSystem.new().perform(item, def, action.id).is_empty(), "all states three five-minute checks")
			var bounds := AppraisalSystem.new().valuation(item, def)
			check(variant.true_value >= bounds.x and variant.true_value <= bounds.y, "appraisal bounds include value")
	var before: Dictionary
	for cash in [0, 5]:
		day.state.cash = cash; before = day.state.to_read_model()
		check(not GoodsExpertise.perform(day, catalog, "fan", ["fan"]).ok and day.state.to_read_model() == before, "cash shortage atomic")
	day.state.cash = 100
	for minute in [run_def.night_minutes - 20, run_def.night_minutes - 15, run_def.night_minutes - 5]:
		day.state.game_minutes = minute; before = day.state.to_read_model()
		check(not GoodsExpertise.perform(day, catalog, "fan", ["fan"]).ok and day.state.to_read_model() == before, "finish before seal")
	day.state.game_minutes = run_def.night_minutes - 25
	check(GoodsExpertise.perform(day, catalog, "fan", ["fan"]).ok and day.state.game_minutes == run_def.night_minutes - 5, "last legal fan service")
	day = DayController.new(run_def, RunState.create(run_def)); day.state.phase = &"open"; day.state.game_minutes = 100
	var all := []
	for index in 4:
		var cup := make_item(GoodsExpertise.CUP, "sound", str(index)); cup.goods = {"pattern": index / 2, "side": index % 2, "workshop": 0}
		cup.provenance = {"status": "verified"}; day.state.inventory_instances.append(cup); all.append(str(index))
	for ids in [["0", "1"], ["2", "3"]]: check(GoodsExpertise.perform(day, catalog, "pair", ids).ok, "multiple original pairs")
	before = day.state.to_read_model()
	check(not service.sell_batch(day, "buyer_recycler", all, [["0", "1"]]).ok and before == day.state.to_read_model(), "recycler rejects bonus atomically")
	check(not service.sell_batch(day, buyer.id, ["0"], [["0", "1"]]).ok and before == day.state.to_read_model(), "missing pair item atomic")
	var cash := day.state.cash; var minute := day.state.game_minutes
	check(service.sell_batch(day, buyer.id, all, [["1", "0"], ["2", "3"]]).ok, "two pairs one batch")
	check(day.state.sale_batches.back().pairs == [["0", "1"], ["2", "3"]], "unordered selection stored canonically for replay")
	check(day.state.cash == cash + 234 and day.state.game_minutes == minute + 20, "base168 source24 pair42 no premium compounding")
	check(day.state.sale_records[0].price == 59 and day.state.sale_records[1].price == 58, "odd share in separate sale rows")
	before = day.state.to_read_model()
	check(not service.sell_batch(day, buyer.id, all, [["0", "1"]]).ok and before == day.state.to_read_model(), "cannot resell certified pair")
	day = DayController.new(run_def, RunState.create(run_def)); day.state.phase = &"open"
	fan = make_item(GoodsExpertise.FAN, "sound", "fan"); day.state.inventory_instances.append(fan)
	var visit := CustomerVisit.new(); visit.status = "active"; visit.expires_at = 10; visit.arrival = 0
	day.state.visits.append(visit)
	check(GoodsExpertise.reason(day, catalog, "fan", ["fan"]).is_empty(), "ordinary guest does not block delegated service")
	day.state.pending_event_id = "pending"
	check(not GoodsExpertise.reason(day, catalog, "fan", ["fan"]).is_empty(), "plot blocks service")
	day.state.pending_event_id = ""; day.state.risk_pending = "risk"
	check(not GoodsExpertise.reason(day, catalog, "fan", ["fan"]).is_empty(), "crisis blocks service")
	preparation_edges()
	print("GOODS EDGES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func prep_state() -> RunState:
	var state := RunState.create(run_def); state.run_seed = 0; state.current_night_index = 2
	var cup := make_item(GoodsExpertise.CUP, "sound", "target"); cup.revealed_clue_ids = ["form"]; cup.goods = {"pattern": 0, "side": 0, "workshop": 0}
	state.inventory_instances.append(cup)
	return state

func preparation_edges() -> void:
	for actions in [["attract", "seek"], ["seek", "attract"], ["visitors", "seek"], ["seek", "visitors"]]:
		var state := prep_state(); var original := OpeningPreparation.plan(state, run_def, catalog)
		for action in actions: check(OpeningPreparation.perform(state, run_def, catalog, action, "target" if action == "seek" else "").ok, "preparation order " + str(actions))
		var result := OpeningPreparation.plan(state, run_def, catalog)
		check(result.size() == (43 if "attract" in actions else 42), "seek never adds traffic")
		for row in original:
			if row.has("seven_role") or row.get("familiar_reserved", false): check(row in result, "protected slot survives seeking")
		var sought: Dictionary = state.preparation_history.filter(func(h: Dictionary) -> bool: return h.action == "seek")[0]
		check(not sought.change.visit_id.contains("prep_attract"), "seek never replaces attracted caller")
		var before := state.to_read_model()
		check(not OpeningPreparation.perform(state, run_def, catalog, "seek", "target").ok and before == state.to_read_model(), "repeated seeking atomic")
	var state := prep_state()
	check(OpeningPreparation.perform(state, run_def, catalog, "target", "porcelain").ok and not OpeningPreparation.perform(state, run_def, catalog, "seek", "target").ok, "target excludes seeking")
	state = prep_state()
	check(OpeningPreparation.perform(state, run_def, catalog, "seek", "target").ok and not OpeningPreparation.perform(state, run_def, catalog, "target", "porcelain").ok, "seeking excludes target")
	state = prep_state(); state.cash = 2
	var before := state.to_read_model()
	check(not OpeningPreparation.perform(state, run_def, catalog, "seek", "target").ok and before == state.to_read_model(), "seeking shortage atomic")
	state = prep_state(); var rows := OpeningPreparation.plan(state, run_def, catalog)
	state.preparation_history.append({"action": "visitors", "night": 2, "visit_ids": rows.filter(func(r: Dictionary) -> bool: return r.night == 2).map(func(r: Dictionary) -> String: return r.visit_id)})
	before = state.to_read_model()
	check(not OpeningPreparation.perform(state, run_def, catalog, "seek", "target").ok and before == state.to_read_model(), "no unrevealed slot atomic")
