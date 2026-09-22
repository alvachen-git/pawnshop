extends "res://tests/fan_bargaining.gd"

const CONDITION_DIR := "res://.godot/qa/fan-condition/"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/fan_condition_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v29 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,29,store,catalog)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(codec.encode(s._day.state,29),run_def,29,catalog,true)
	check(restored != null,"v29 replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute(CONDITION_DIR)
	var file := FileAccess.open(CONDITION_DIR + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,29)))

func load_case(label := "ordinary") -> RunSession:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONDITION_DIR + label + ".json"))
	var s := fresh_growth(int(payload.run_seed))
	s._day.state = SaveCodec.new().decode(payload,run_def,29,catalog,true)
	return s

func run() -> void:
	if not setup(): quit(1); return
	create_fixtures()
	for kind in ["informed", "ordinary", "urgent"]:
		var s := load_case(kind)
		claim(s); fixture(s, kind + "-ready")
	condition_fixtures()
	inspection_checks()
	pricing_matrix()
	stack_checks()
	condition_boundaries()
	condition_storage()
	legacy_check()
	print("FAN CONDITION: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func condition_fixtures() -> void:
	var selected := {}
	for seed_value in 500:
		var sample := fresh_growth(seed_value)
		for row in OpeningPreparation.plan(sample._day.state, run_def, catalog):
			if row.night != 5 or row.item_id != GoodsExpertise.FAN or "sell" not in row.transaction_modes or "pawn" not in row.transaction_modes: continue
			if row.get("familiar_reserved", false) or row.has("night_policy") or row.customer_id == "customer_scholar": continue
			var grade: String = row.goods.fan_condition
			if not selected.has(grade): selected[grade] = {"seed": seed_value, "visit_id": row.visit_id}
		if selected.size() == 3: break
	check(selected.size() == 3, "natural three conditions with purchase and pawn")
	for grade in selected:
		var s := unlock(int(selected[grade].seed))
		reach_selected(s, selected[grade].visit_id)
		fixture(s, grade)
		print("CONDITION FIXTURE ", grade, " ", selected[grade])
	var s := load_case("minor"); claim(s); fixture(s, "stack")
	var early := second_night(int(selected.minor.seed))
	while early._day.state.current_night_index < 5:
		act(early, "open_shop"); finish_night(early); driver.drain(early)
	reach_selected(early, selected.minor.visit_id)
	check(FanAppraisalService.bench_level(early._day.state) == 0, "natural no-bench fixture")
	fixture(early, "no-bench")

func reach_selected(s: RunSession, id: String) -> void:
	act(s, "open_shop"); driver.drain(s)
	for step in 100:
		var visit := CustomerManager.new().active(s._day.state)
		if visit != null:
			if visit.visit_id == id: return
			s.counter_command("reject", visit.visit_id)
		elif s.bell_model().enabled: s.bell_command("wait")
		else: break
		driver.drain(s)
	check(false, "target reached " + id)

func inspection_checks() -> void:
	for stage in ["no-bench", "intact", "minor", "major"]:
		var s := load_case(stage)
		var visit := CustomerManager.new().active(s._day.state)
		var item := visit.item
		var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
		var value := GoodsExpertise.value(item, definition)
		var minute := s._day.state.game_minutes
		var asking := visit.trade.asking_price
		var visual: Dictionary = s.counter_model().appraisal.visual
		check(visual.estimate == "品相待查" and not visual.goods_note.contains(FanConditionService.TEXT[item.goods.fan_condition]), "unchecked condition not disclosed")
		check(s.fan_command("condition", item.instance_id).ok, "check without bench " + stage)
		check(s._day.state.game_minutes == minute + 5 and visit.trade.asking_price == asking and GoodsExpertise.value(item, definition) == value, "inspection reveals, no depreciation or negotiation")
		check(FanConditionService.checked(item), "checked flag")
		invalid_fan(s, "condition", item.instance_id)
		var model := s.counter_model()
		check(not model.appraisal.buttons.any(func(b: Dictionary) -> bool: return b.command in ["appraise", "judge"]), "obsolete buttons removed")
		check(not model.appraisal.visual.goods_note.contains("对客说法"), "public talk only on trade page")
		for command in ["appraise", "judge"]:
			var before := s.read_state(); var writes: int = s._save.writes
			check(not s.counter_command(command, visit.visit_id, "sound").ok and before == s.read_state() and writes == s._save.writes, "no legacy bypass " + command)
		if stage == "no-bench":
			check(not FanConditionService.desk_reason(s._day, item.instance_id).is_empty(), "professional equipment required")
			invalid_fan(s, "draft", item.instance_id, FanEvidence.payload("brush", Vector2(.72,.32), Vector2(.38,.245), "same"))
		else:
			claim(s)
			check(s._day.state.game_minutes == minute + 15, "draft free, commit ten minutes")
		fixture(s, stage + "-checked")
		if stage != "intact":
			check(s.counter_command("condition_pressure", visit.visit_id).ok, "proven damage accepted")
			check(s._day.state.game_minutes == minute + (10 if stage == "no-bench" else 20), "damage pressure five minutes")
			fixture(s, stage + "-pressed")
		else: check(not s.counter_command("condition_pressure", visit.visit_id).ok, "intact cannot pressure")

func pricing_matrix() -> void:
	var s := load_case()
	var item := CustomerManager.new().active(s._day.state).item
	var definition := catalog.get_definition("items", item.definition_id) as ItemDefinition
	for truth in ["sound", "mended", "flawed"]:
		item.selected_variant_id = truth
		for grade in FanConditionService.RETAIN:
			item.goods.fan_condition = grade
			for expert in [false, true]:
				item.expert_reviewed = expert
				var base: int = definition.find_variant(truth).true_value if expert else 20
				var adjusted := maxi(1, roundi(base * int(FanConditionService.RETAIN[grade]) / 100.0))
				check(GoodsExpertise.value(item, definition) == adjusted, "truth / condition independent, single discount")
				item.goods.condition_checked = true
				check(GoodsExpertise.value(item, definition) == adjusted, "inspection does not affect resale")
				for buyer_id in ["buyer_recycler", "buyer_lu"]:
					var buyer := catalog.get_definition("buyers", buyer_id) as BuyerDefinition
					check(CommerceService.new(catalog).base_quote(item, buyer) == maxi(1, roundi(adjusted * buyer.value_multiplier)), "buyer multiplier after damage")
				item.goods.erase("condition_checked")
	item.expert_reviewed = false; item.goods.fan_claim = "sound"; item.goods.fan_weight = 20
	for grade in FanConditionService.RETAIN:
		item.goods.fan_condition = grade
		check(GoodsExpertise.value(item, definition) == maxi(1, roundi(31 * int(FanConditionService.RETAIN[grade]) / 100.0)), "self appraisal then damage")
	var counts := {"intact": 0, "minor": 0, "major": 0}
	for seed_value in 1000:
		var rows := [{"item_id": GoodsExpertise.FAN, "visit_id": "independent/sample", "variant_id": "sound"}]
		FanConditionService.attach(rows, run_def, seed_value)
		var generated: String = rows[0].goods.fan_condition
		counts[generated] += 1
		rows[0].variant_id = "flawed"; rows[0].erase("goods")
		FanConditionService.attach(rows, run_def, seed_value)
		check(rows[0].goods.fan_condition == generated, "truth cannot alter condition draw")
	print("CONDITION DISTRIBUTION ", counts)

func stack_checks() -> void:
	for grade in ["minor", "major"]:
		for order in [["condition_pressure", "fan_pressure"], ["fan_pressure", "condition_pressure"]]:
			for mode in ["offer", "pawn"]:
				var s := load_case(grade + "-checked")
				var visit := CustomerManager.new().active(s._day.state)
				var ask := visit.trade.asking_price; var reserve := visit.trade.reserve_price
				var minutes := s._day.state.game_minutes
				var keep: int = FanConditionService.RETAIN[grade]
				var fake_keep := 60 if visit.situation_id == "urgent" else 80
				var sale_reserve := reserve
				for command in order:
					check(s.counter_command(command, visit.visit_id).ok, "stack " + grade + " " + command)
					sale_reserve = maxi(1, roundi(sale_reserve * (keep if command == "condition_pressure" else fake_keep) / 100.0))
				check(visit.trade.asking_price == maxi(1, roundi(ask * keep / 100.0)) and visit.trade.reserve_price == maxi(1, roundi(reserve * keep / 100.0)), "only damage affects pawn")
				check(int(FanBargainingService.attempt(s._day.state, visit).reserve) == sale_reserve, "sequential integer discounts")
				check(s._day.state.game_minutes == minutes + 10, "separate five-minute rounds")
				var before := s.read_state(); var writes: int = s._save.writes
				check(not s.counter_command("condition_pressure", visit.visit_id).ok and not s.counter_command("fan_pressure", visit.visit_id).ok and not s.counter_command("belittle", visit.visit_id).ok, "no duplicate pressure")
				check(before == s.read_state() and writes == s._save.writes, "repeats no writes")
				var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
				var terms := catalog.get_definition("pawn_terms", VarietyService.terms_for(visit, customer)) as PawnTermsDefinition
				var price := sale_reserve if mode == "offer" else maxi(1, roundi(visit.trade.reserve_price * terms.loan_ratio))
				check(s.counter_command(mode, visit.visit_id, "", price).ok, "purchase or pawn respective reserve")
				check(visit.item.ownership_state == ("owned" if mode == "offer" else "pledged"), "acquisition committed")
				check(FanBargainingService.data(s._day.state).reputation_events.size() == (1 if mode == "offer" and visit.item.selected_variant_id == "sound" else 0), "hidden penalty only true purchased under fake claim")
				fixture(s, grade + "-" + order[0] + "-" + mode)
				print("STACK ", grade, " ", order, " ", mode, " cost=", price, " minutes=", s._day.state.game_minutes-minutes)

func condition_boundaries() -> void:
	for command in ["condition", "condition_pressure"]:
		for edge in ["deadline", "closing", "pending", "gone", "rounds", "patience"]:
			var s := load_case("minor" if command == "condition" else "minor-checked")
			var visit := CustomerManager.new().active(s._day.state)
			match edge:
				"deadline": visit.expires_at = s._day.state.game_minutes + 5
				"closing": s._day.state.game_minutes = 535; visit.expires_at = 600
				"pending": s._day.state.pending_event_id = "test_pending"
				"gone": visit.status = "left"
				"rounds": visit.trade.rounds_left = 0
				"patience": visit.trade.patience = 0
			if command == "condition" and edge in ["rounds", "patience"]: continue
			var before := s.read_state(); var writes: int = s._save.writes
			var result := s.fan_command(command, visit.item.instance_id) if command == "condition" else s.counter_command(command, visit.visit_id)
			check(not result.ok and before == s.read_state() and writes == s._save.writes, "invalid no-op " + command + " " + edge)
	var s := load_case("minor")
	var visit := CustomerManager.new().active(s._day.state)
	var customer := catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var old := customer.guest_rule
	customer.guest_rule = "no_appraisal"
	check(s.fan_command("condition", visit.item.instance_id).ok and visit.status == "inspection_refused" and not FanConditionService.checked(visit.item), "inspection taboo preserved")
	customer.guest_rule = old

func condition_storage() -> void:
	for stage in ["minor", "minor-checked"]:
		var s := load_case(stage)
		var visit := CustomerManager.new().active(s._day.state)
		var command := "condition" if stage == "minor" else "condition_pressure"
		var before := s.read_state()
		s._save.fail = true
		var result := s.fan_command(command, visit.item.instance_id) if command == "condition" else s.counter_command(command, visit.visit_id)
		check(not result.ok and before == s.read_state(), "write failure restores condition prices clock journal")
		s._save.fail = false
		visit = CustomerManager.new().active(s._day.state)
		result = s.fan_command(command, visit.item.instance_id) if command == "condition" else s.counter_command(command, visit.visit_id)
		check(result.ok, "retry after failure")
		fixture(s, stage + "-retry")
	var s := load_case("major-checked")
	var payload := SaveCodec.new().encode(s._day.state, 29)
	payload.ordinary_selections[0]["goods"] = {"fan_condition": "intact"}
	check(SaveCodec.new().decode(payload, run_def, 29, catalog, true) == null, "tampered condition rejected")
	for manifest in ["fan_bargaining", "shop_appraisal"]:
		var legacy := JsonContentProvider.new("res://data/" + manifest + "_manifest.json").load_catalog().catalog
		var legacy_run := legacy.get_definition("runs", legacy.default_run_id) as RunDefinition
		check(not FanConditionService.enabled(legacy_run), "old rule gate")
		var rows := [{"item_id": GoodsExpertise.FAN, "visit_id": "old/fan"}]
		FanConditionService.attach(rows, legacy_run, 0)
		check(not rows[0].has("goods"), "old condition never backfilled")
