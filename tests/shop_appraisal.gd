extends "res://tests/shop_growth.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/shop_appraisal_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "unified catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 27, store, catalog)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, 27)
	InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(payload, run_def, 27, catalog, true)
	check(restored != null, "cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s, label)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/shop-appraisal")
	var file := FileAccess.open("res://.godot/qa/shop-appraisal/" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 27)))

func growth(s: RunSession, command: String, detail := "") -> void:
	var result := s.growth_command(command, detail)
	check(result.ok, command + ": " + result.message)

func unlock(seed_value: int) -> RunSession:
	var s := second_night(seed_value)
	invalid(s, "bench_two", "", "requires old manual")
	growth(s, "build", "bench")
	act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
	growth(s, "explore", "0")
	var cash := s._day.state.cash
	growth(s, "fan_manual")
	check(s._day.state.cash == cash and s._day.state.shop_growth.exploration.size() == 1, "manual free and independent of cabinet steps")
	invalid(s, "fan_manual", "", "duplicate manual")
	finish_night(s); driver.drain(s)
	fixture(s, "upgrade")
	growth(s, "bench_two")
	check(FanAppraisalService.bench_level(s._day.state) == 1, "construction keeps level one")
	invalid(s, "bench_two", "", "duplicate construction")
	growth(s, "fan_study")
	check(PreparationService.count(s._day.state) == 2, "study shares quota")
	check(not s.execute("prep_tea").ok, "no third preparation")
	verify(s, "construction and knowledge")
	for night in [3, 4]:
		act(s, "open_shop"); finish_night(s); driver.drain(s)
	check(s._day.state.current_night_index == 5 and FanAppraisalService.bench_level(s._day.state) == 2, "automatic two-night construction")
	growth(s, "fan_tools")
	invalid(s, "fan_tools", "", "duplicate tools")
	invalid(s, "fan_study", "", "duplicate study")
	check(FinancialSummary.build(s._day.state).facility_investment == 30, "current night tool cost separate")
	fixture(s, "ready")
	return s

func reach_fan(s: RunSession) -> CustomerVisit:
	act(s, "open_shop"); driver.drain(s)
	for step in 60:
		var visit := s._counter.customers.active(s._day.state)
		if visit != null:
			if visit.purpose.is_empty() and visit.item.definition_id == GoodsExpertise.FAN: return visit
			s.counter_command("reject", visit.visit_id)
		elif s.bell_model().enabled: s.bell_command("wait")
		else: break
		driver.drain(s)
	return null

func invalid_fan(s: RunSession, command: String, id: String, detail := "") -> void:
	var before := s.read_state()
	var writes: int = s._save.writes
	check(not s.fan_command(command, id, detail).ok, "invalid fan " + command)
	check(s.read_state() == before and s._save.writes == writes, "invalid fan is exact no-op")

func run() -> void:
	if not setup(): quit(1); return
	check(ShopGrowthService.enabled(run_def) and MirrorReunionService.enabled(run_def) and "aq_coat" in run_def.event_ids, "one run includes growth reunion and Aqi")
	var seeds := {}
	for seed_value in 300:
		for row in VarietyService.plan(run_def, catalog, seed_value):
			if row.night == 5 and row.item_id == GoodsExpertise.FAN:
				if not seeds.has(row.variant_id): seeds[row.variant_id] = seed_value
				break
		if seeds.size() == 3: break
	check(seeds.size() == 3, "three fan variants available naturally")
	for variant in seeds:
		var s := unlock(seeds[variant])
		var visit := reach_fan(s)
		check(visit != null, "natural fan available")
		if visit == null: continue
		var id := visit.item.instance_id
		fixture(s, "fan-" + variant)
		invalid_fan(s, "verdict", id, "sound")
		var before := s.read_state()
		var model := FanAppraisalModels.comparison(s._day, id)
		check(not str(model).contains(FanAppraisalService.OBSERVATIONS[String(visit.item.selected_variant_id)].brush), "unseen evidence stays hidden")
		check(s.read_state() == before, "view is read-only")
		var start := s._day.state.game_minutes
		check(s.fan_command("brush", id).ok, "brush comparison")
		check(s._day.state.game_minutes == start + 10, "no level-one professional discount")
		invalid_fan(s, "brush", id)
		check(s.fan_command("inscription", id).ok, "inscription comparison")
		if visit.status != "active":
			check(FanAppraisalService.record(s._day.state, id).get("checks", []).size() < 2, "deadline gives no late evidence")
			continue
		var guessed := "sound" # Includes deliberate wrong judgements; they must not be auto-corrected.
		check(s.fan_command("verdict", id, guessed).ok, "player judgement accepted")
		check(not visit.item.expert_reviewed and visit.item.goods.fan_claim == guessed, "self claim is not expert truth")
		var definition := catalog.get_definition("items", GoodsExpertise.FAN) as ItemDefinition
		check(GoodsExpertise.value(visit.item, definition) == 31, "low standing only weights 20 percent of claimed difference")
		invalid_fan(s, "verdict", id, "mended")
		verify(s, "pre-purchase judgement")
		var price := visit.trade.asking_price
		var trade := s.counter_command("offer", visit.visit_id, "", price)
		check(trade.ok and visit.item.ownership_state == "owned", "self appraised real purchase")
		if visit.item.ownership_state != "owned": continue
		var expected := 1 if visit.item.selected_variant_id == guessed else -2
		var reviewed := s.commerce_command("expert_fan", id)
		check(reviewed.ok, "expert confirms prior judgement " + reviewed.message)
		check(FanAppraisalService.data(s._day.state).standing == expected, "standing follows independent review")
		check(GoodsExpertise.value(visit.item, definition) == definition.find_variant(visit.item.selected_variant_id).true_value, "expert price replaces self claim")
		var standing: int = FanAppraisalService.data(s._day.state).standing
		s.commerce_command("expert_fan", id)
		check(FanAppraisalService.data(s._day.state).standing == standing, "no reputation farming")
		verify(s, "expert confirmation")
		var payload := SaveCodec.new().encode(s._day.state, 27)
		payload.shop_growth.appraisal.standing = 8
		check(SaveCodec.new().decode(payload, run_def, 27, catalog, true) == null, "forged standing rejected")
	unit_boundaries()
	storage_checks()
	print("SHOP APPRAISAL: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func unit_boundaries() -> void:
	var s := load_fan()
	var visit := CustomerManager.new().active(s._day.state)
	# Isolated boundary fixture: keep mutation out of replay tests above.
	visit.item.definition_id = GoodsExpertise.FAN
	visit.item.selected_variant_id = "flawed"
	visit.expires_at = s._day.state.game_minutes + 10
	var id := visit.item.instance_id
	check(s.fan_command("brush", id).ok, "expiry commits elapsed time")
	check(FanAppraisalService.record(s._day.state, id).is_empty(), "no evidence exactly at departure")
	s = load_fan()
	visit = CustomerManager.new().active(s._day.state)
	visit.item.definition_id = GoodsExpertise.FAN
	visit.item.selected_variant_id = "sound"
	visit.expires_at = 540
	id = visit.item.instance_id
	var before := s.read_state()
	s._save.fail = true
	check(not s.fan_command("brush", id).ok, "injected save failure")
	check(s.read_state() == before, "full comparison rollback including time and evidence")
	s._save.fail = false
	s._day.state.game_minutes = 530
	invalid_fan(s, "brush", id)
	var old := JsonContentProvider.new("res://data/shop_growth_manifest.json").load_catalog().catalog
	var old_run := old.get_definition("runs", old.default_run_id) as RunDefinition
	var old_state := RunState.create(old_run)
	check(not old_state.shop_growth.has("appraisal"), "old growth format frozen")
	# Gate checks use isolated copied fixtures, never author impossible saves.
	s = load_fan()
	visit = CustomerManager.new().active(s._day.state)
	id = visit.item.instance_id
	var a := FanAppraisalService.data(s._day.state)
	a.tools = false
	invalid_fan(s, "brush", id)
	a.tools = true; a.knowledge = false
	invalid_fan(s, "brush", id)
	a.knowledge = true
	visit.customer_id = "ghost_closed_bundle"
	check(s.fan_command("brush", id).ok and visit.status == "inspection_refused", "no-appraisal guest leaves")
	check(FanAppraisalService.record(s._day.state, id).is_empty(), "taboo inspection reveals nothing")
	for standing in [-4, 0, 8]:
		s = load_fan(); visit = CustomerManager.new().active(s._day.state); id = visit.item.instance_id
		FanAppraisalService.data(s._day.state).standing = standing
		check(s.fan_command("brush", id).ok and s.fan_command("inscription", id).ok, "price boundary evidence")
		check(s.fan_command("verdict", id, "sound").ok, "price boundary judgement")
		var definition := catalog.get_definition("items", GoodsExpertise.FAN) as ItemDefinition
		check(GoodsExpertise.value(visit.item, definition) == {-4: 20, 0: 31, 8: 53}[standing], "standing materially weights self claim")
		check(not visit.item.expert_reviewed, "even respected appraisal is not expert certification")
	s = load_fan()
	var state := s._day.state
	var held := state.inventory_instances[0]
	held.definition_id = GoodsExpertise.FAN; held.ownership_state = "pawned"
	invalid_fan(s, "brush", held.instance_id)
	state.pending_event_id = "pending"
	invalid_fan(s, "brush", CustomerManager.new().active(state).item.instance_id)

func storage_checks() -> void:
	var s := load_fan()
	var id := CustomerManager.new().active(s._day.state).item.instance_id
	check(s.fan_command("brush", id).ok, "save partial evidence")
	var manager := SaveManager.new("user://tests/shop_appraisal/auto.json")
	manager.catalog = catalog
	manager.library = SaveLibrary.new("user://tests/shop_appraisal/library.json")
	check(manager.save_state(s._day.state, run_def, 27), "real atomic write")
	s._save = manager
	var before := s.read_state()
	var bytes := FileAccess.get_file_as_bytes(manager.library.path)
	manager.library.fail_write = true
	check(not s.fan_command("inscription", id).ok, "real storage failure returned")
	check(s.read_state() == before and bytes == FileAccess.get_file_as_bytes(manager.library.path), "write failure preserves memory and prior disk bytes")
	manager.library.fail_write = false
	check(s.fan_command("inscription", id).ok, "retry after failed write")
	check(s.fan_command("verdict", id, "mended").ok, "persist unverified self claim")
	fixture(s, "saved-claim")
	var restored := manager.load_state(run_def, 27)
	check(restored != null and GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "saved self claim and weighted price restored")
	var forged := SaveCodec.new().encode(s._day.state, 27)
	forged.shop_growth.appraisal.records[id].verdict = "sound"
	check(SaveCodec.new().decode(forged, run_def, 27, catalog, true) == null, "forged judgement rejected")

func load_fan() -> RunSession:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/fan-sound.json"))
	var s := fresh_growth(int(payload.run_seed))
	s._day.state = SaveCodec.new().decode(payload, run_def, 27, catalog, true)
	return s
