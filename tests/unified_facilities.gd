extends "res://tests/fan_condition.gd"

const UNIFIED_FIXTURES := "res://.godot/qa/unified/"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/unified_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "unified catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, catalog.content_version, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state,30),run_def,30,catalog,true)
	check(restored != null, "unified cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "unified exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute(UNIFIED_FIXTURES)
	FileAccess.open(UNIFIED_FIXTURES + label + ".json",FileAccess.WRITE).store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,30)))

func run() -> void:
	if not setup(): quit(1); return
	var chosen := -1
	for seed_value in 200:
		var state := RunState.create(run_def); state.run_seed = seed_value; state.current_night_index = 5; state.ghost_catalog = catalog
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		var fans := rows.filter(func(row: Dictionary) -> bool: return row.night == 5 and row.item_id == GoodsExpertise.FAN)
		if not fans.is_empty() and fans[0].variant_id == "sound" and fans[0].customer_id in ["customer_house_agent", "customer_bookkeeper"] and fans[0].wait_minutes >= 55:
			chosen = seed_value; break
	check(chosen >= 0, "natural true fan with uninformed owner")
	if chosen < 0: quit(1); return
	driver.pause_military_intro = true
	var s := second_night(chosen)
	fixture(s, "introduction")
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),"0").ok and before == s.read_state(), "intro failure rolls back entire combined state")
	(s._save as CountingStore).fail = false
	for step in 3:
		check(s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),str(step)).ok, "real military introduction")
		verify(s, "intro " + str(step))
	driver.pause_military_intro = false
	fixture(s, "preparation")
	check(s.social_command("accept_contract").ok, "coat order in unified game")
	growth(s,"learn_knowledge","gu_yansheng")
	growth(s,"build","bench")
	check(PreparationService.count(s._day.state) == 2, "learning and construction share preparation")
	before = s.read_state()
	check(not s.social_command("gift").ok and before == s.read_state(), "military gift cannot exceed shared budget")
	act(s,"open_shop"); driver.drain(s)
	for step in 10:
		var active := s._counter.customers.active(s._day.state)
		if active == null: break
		check(s.counter_command("reject",active.visit_id).ok, "clear counter before selling")
	var hairpin := s._day.state.inventory_instances[0]
	check(s.commerce_command("sell",hairpin.instance_id,"buyer_recycler").ok,"real sale finances appraisal facilities")
	finish_night(s); driver.drain(s)
	growth(s,"bench_two")
	check(s.social_command("gift").ok,"military gift shares construction night")
	for i in 2:
		act(s,"open_shop"); driver.drain(s); finish_night(s); driver.drain(s)
	growth(s,"fan_tools")
	check(FanAppraisalService.bench_level(s._day.state) == 2,"two-night construction finished")
	var visit := reach_fan(s)
	check(visit != null and visit.item.selected_variant_id == "sound", "naturally reached true fan")
	if visit == null: quit(1); return
	fixture(s,"fan-before")
	check(s.fan_command("condition",visit.item.instance_id).ok,"inspect fan condition")
	claim(s)
	fixture(s,"fan-ready")
	check(s.counter_command("fan_pressure",visit.visit_id).ok,"same game fake claim pressure")
	var price := int(FanBargainingService.attempt(s._day.state,visit).reserve)
	var reputation: int = s._day.state.social.reputation
	check(s.counter_command("offer",visit.visit_id,"",price).ok,"same game buys pressured fan")
	var rows: Array = FanBargainingService.data(s._day.state).reputation_events
	check(rows.size() == 1,"true fan pressure records one penalty")
	check(s._day.state.social.changes.any(func(row: Dictionary) -> bool: return row.reason == rows[0].id and row.after - row.before == -2),"fan penalty reaches actual street reputation")
	check(s._day.state.social.reputation <= reputation - 2,"combined reputation applied")
	check(s._day.state.social.introduced and not s._day.state.social.contract.is_empty() and AqiCompanion.enabled(s.definition) and MirrorDreamService.call_enabled(s.definition),"one saved run retains all systems")
	fixture(s,"fan-bought")
	# Unit interaction: military and fan discounts must share the sale quote.
	var snapshot := RunSnapshot.copy(s._day.state)
	var target := snapshot.visits.filter(func(v: CustomerVisit) -> bool: return v.visit_id == visit.visit_id)[0] as CustomerVisit
	var old_ask := FanBargainingService.asking(snapshot,target)
	MilitaryPlaque.intimidate(snapshot,target)
	check(FanBargainingService.asking(snapshot,target) == maxi(1,ceili(old_ask*.9)),"military discount updates fan sale track")
	var fair := ReputationService.basis(snapshot,target)
	target.item.goods.fan_condition = "minor"
	FanConditionService.pressure(DayController.new(s.definition,snapshot),target)
	check(ReputationService.basis(snapshot,target) == maxi(1,roundi(fair*.8)),"genuine condition reduction preserves fair reputation baseline after threat")
	print("UNIFIED FACILITIES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
