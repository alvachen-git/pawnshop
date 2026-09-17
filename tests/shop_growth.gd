extends "res://tests/run_integrated_seven.gd"

class CountingStore extends GhostReplayStore:
	var writes := 0
	var fail := false
	func save_state(_state: RunState, _run: RunDefinition, _version: int) -> bool:
		writes += 1
		error_message = "测试写盘失败" if fail else ""
		return not fail

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/shop_growth_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "growth catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 25, store, catalog)

func act(s: RunSession, command: String) -> void:
	var result := s.execute(command)
	check(result.ok, command + ": " + result.message)

func finish_night(s: RunSession) -> void:
	driver.drain(s)
	if s._day.state.phase == &"open": act(s, "close_shop")
	if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
	for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id, "keep")
	act(s, "resolve_night")
	if s._day.state.phase in [&"dead", &"bankrupt"]: return
	act(s, "enter_room"); driver.drain(s)
	act(s, "sleep"); driver.drain(s)
	act(s, "finish_sleep"); act(s, "continue_run")

func second_night(seed_value := 42) -> RunSession:
	var s := fresh_growth(seed_value)
	driver.drain(s); act(s, "open_shop"); driver.drain(s)
	var visit := s._counter.customers.active(s._day.state)
	check(visit != null and visit.item.definition_id == "intro_silver_hairpin", "authored opening preserved")
	check(s.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "real opening stock purchase")
	driver.drain(s)
	finish_night(s)
	driver.drain(s)
	return s

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 25)
	var restored := codec.decode(data, run_def, 25, catalog, true)
	check(restored != null, "replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s, label)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/shop-growth")
	var f := FileAccess.open("res://.godot/qa/shop-growth/" + label + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 25)))

func invalid(s: RunSession, command: String, detail: String, label: String) -> void:
	var before := s.read_state()
	var writes: int = s._save.writes
	check(not s.growth_command(command, detail).ok, label)
	check(s.read_state() == before and s._save.writes == writes, label + " no journal, state, write")

func run() -> void:
	if not setup(): quit(1); return
	facilities()
	exploration()
	display_rules()
	buyer_paths()
	save_edges()
	print("SHOP GROWTH: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func facilities() -> void:
	var s := fresh_growth()
	driver.drain(s)
	invalid(s, "build", "bench", "night one locked")
	s = second_night()
	fixture(s, "preparation")
	var cash := s._day.state.cash
	check(s.growth_command("build", "bench").ok, "bench build")
	check(s._day.state.cash == cash - 40 and PreparationService.count(s._day.state) == 1, "bench cash and prep")
	invalid(s, "build", "bench", "no duplicate bench")
	check(s.growth_command("build", "display").ok, "display build")
	check(s._day.state.cash == cash - 100 and PreparationService.count(s._day.state) == 2, "two builds share quota")
	check(not s.execute("prep_tea").ok, "other preparation shares quota")
	var financial := FinancialSummary.build(s._day.state)
	check(financial.facility_investment == 100 and financial.realized_profit == 0 and financial.operating_profit == 0 and financial.purchase_spend == 0, "separate capital and business")
	verify(s, "both facilities")
	fixture(s, "facilities")
	for item in catalog.get_all("items"):
		for action in item.appraisal_actions:
			var expected: int = 5 if item.item_type == "normal" and item.ghost_rule_id.is_empty() and action.minutes == 10 and action.required_tool in ["magnifier", "lamp", "magnet"] else action.minutes
			check(ShopGrowthService.appraisal_minutes(s._day.state, item, action.id) == expected, "effective minutes " + String(item.id) + "/" + action.id)
	s = second_night()
	s._day.state.cash = 39
	invalid(s, "build", "bench", "insufficient funds")
	s = second_night()
	check(s.execute("prep_tea").ok and s.execute("prep_visitors").ok, "existing prep twice")
	invalid(s, "build", "bench", "quota exhausted")
	s = second_night(); act(s, "prep_finish")
	invalid(s, "build", "bench", "finished prep locked")
	# Boundary fixtures verify the shared calculator through actual service and UI.
	s = second_night(); s.growth_command("build", "bench"); act(s, "open_shop"); driver.drain(s)
	if s._counter.customers.active(s._day.state) == null: s.bell_command("wait"); driver.drain(s)
	var v := s._counter.customers.active(s._day.state)
	var item: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
	if item == null: item = catalog.get_definition("items", "item_silver_hairpin")
	if item == null:
		for candidate in catalog.get_all("items"):
			if candidate.item_type == "normal" and candidate.appraisal_actions.any(func(a: AppraisalActionDefinition) -> bool: return a.minutes == 10): item = candidate; break
	v.item.definition_id = item.id; v.item.selected_variant_id = item.possible_variants[0].id
	v.item.completed_action_ids.clear(); v.item.revealed_clue_ids.clear(); v.scenario_id = ""; v.night_policy = ""
	for clue in item.clues: v.item.revealed_clue_ids.append(clue.id)
	var action: AppraisalActionDefinition
	for a in item.appraisal_actions:
		if a.minutes == 10: action = a; break
	var now := s._day.state.game_minutes
	var model := s.counter_model()
	check(model.appraisal.buttons.any(func(b: Dictionary) -> bool: return b.detail == action.id and b.label.ends_with("5分钟")), "UI shows effective five")
	check(s.counter_command("appraise", v.visit_id, action.id).ok and s._day.state.game_minutes == now + 5, "actual five minutes")

func exploration() -> void:
	var s := second_night()
	invalid(s, "explore", "0", "not before closing")
	act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
	fixture(s, "closed")
	var cash := s._day.state.cash; var prep := PreparationService.count(s._day.state)
	invalid(s, "explore", "1", "no skipping evidence")
	check(s.growth_command("explore", "0").ok, "old ledger exploration")
	check(s._day.state.shop_growth.exploration.size() == 1 and s._day.state.cash == cash and PreparationService.count(s._day.state) == prep, "exploration free no prep")
	check(not s._day.state.shop_growth.bench and not s._day.state.shop_growth.display, "no facility prerequisite")
	verify(s, "first exploration")
	check(not ShopGrowthReadModels.page(s._day, 2).body.contains("顾敬堂"), "no premature seal disclosure")
	finish_night(s); driver.drain(s); act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
	check(s.growth_command("explore", "1").ok, "second step another night")
	check(s.growth_command("explore", "2").ok, "third step")
	check(s._day.state.shop_growth.exploration.size() == 3 and s._day.state.inventory_instances.size() == 1, "evidence not inventory")
	invalid(s, "explore", "2", "repeat investigation free view only")
	fixture(s, "discovery")
	s = second_night(); act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
	s._day.state.pending_event_id = "forced"
	invalid(s, "explore", "0", "forced event blocks exploration")
	s._day.state.pending_event_id = ""; s._day.state.game_minutes = 530
	invalid(s, "explore", "0", "not enough night")
	s._day.state.game_minutes = 525
	check(s.growth_command("explore", "0").ok and s._day.state.game_minutes == 540 and s._day.state.shop_growth.exploration.size() == 1, "exact seal evidence before risk")
	check(s._day.state.phase == &"night_resolution", "normal seal phase")

func display_rules() -> void:
	var s := second_night(); s.growth_command("build", "display")
	var item := s._day.state.inventory_instances[0]
	invalid(s, "display", "missing", "missing stock")
	item.ownership_state = "pledged"; invalid(s, "display", item.instance_id, "pawn collateral forbidden"); item.ownership_state = "owned"
	var original := item.definition_id
	item.definition_id = "item_weeping_mirror"; invalid(s, "display", item.instance_id, "ghost forbidden"); item.definition_id = original
	var count := PreparationService.count(s._day.state)
	check(s.growth_command("display", item.instance_id).ok and PreparationService.count(s._day.state) == count, "display no prep")
	invalid(s, "display", item.instance_id, "duplicate display")
	act(s, "open_shop"); driver.drain(s)
	var locked := ShopGrowthService.opportunity(s._day.state).duplicate(true)
	for i in 4: s.counter_model(); ShopGrowthReadModels.page(s._day, 1); s.execute("open_shop")
	check(ShopGrowthService.opportunity(s._day.state) == locked, "no page/open reroll")
	check(s.growth_command("withdraw").ok, "withdraw during business")
	invalid(s, "display", item.instance_id, "cannot retarget tonight")
	verify(s, "withdraw")
	finish_night(s); driver.drain(s)
	check(s.growth_command("display", item.instance_id).ok, "next night choose allowed")
	act(s, "open_shop"); driver.drain(s)
	finish_night(s)
	check(s._day.state.shop_growth.display_id == item.instance_id, "display persists across nights")
	verify(s, "persistent display")

func buyer_session(seed_value: int) -> RunSession:
	var s := second_night(seed_value)
	s.growth_command("build", "display")
	s.growth_command("display", s._day.state.inventory_instances[0].instance_id)
	act(s, "open_shop"); driver.drain(s)
	for step in 100:
		var visit := s._counter.customers.active(s._day.state)
		if visit != null:
			if visit.purpose == "display_buyer": return s
			s.counter_command("reject", visit.visit_id)
		elif s.bell_model().enabled: s.bell_command("wait")
		else: return s
		driver.drain(s)
	return s

func buyer_paths() -> void:
	var chosen := -1
	for seed_value in 30:
		if VarietyService.rng(seed_value, "growth/2/chance").randi_range(0, 99) < 40: chosen = seed_value; break
	check(chosen >= 0, "seeded buyer available")
	for mode in ["accept", "counter", "failed", "reject", "timeout", "withdraw", "closed"]:
		var s := buyer_session(chosen)
		var v := s._counter.customers.active(s._day.state)
		check(v != null and v.purpose == "display_buyer", "extra buyer reaches counter " + mode)
		if v == null or v.purpose != "display_buyer": continue
		check(s._day.state.visits.size() == 7 and s._day.state.inventory_instances.size() == 1, "seventh visitor no duplicate inventory")
		var row := ShopGrowthService.opportunity(s._day.state)
		var model := s.counter_model()
		check(model.trade.display_buyer and not model.trade.can_offer and not model.trade.can_pawn and not model.trade.has("cap"), "buyer only UI no hidden ceiling")
		check(LivingMirror.customer(s._day, catalog).life == "living", "extra buyer alive")
		var before := s.read_state(); var writes: int = s._save.writes
		check(not s.counter_command("display_counter", v.visit_id, "", row.offer).ok, "counter must exceed opening")
		check(s.read_state() == before and s._save.writes == writes, "invalid counter no mutation")
		var cash := s._day.state.cash; var now := s._day.state.game_minutes
		var price: int = row.offer
		match mode:
			"accept":
				fixture(s, "buyer")
				check(s.counter_command("display_accept", v.visit_id).ok, "accept")
			"counter":
				price = row.cap
				if price <= row.offer: price = row.offer + 1; row.cap = price # separate boundary case; exact replay covers ordinary accept
				check(s.counter_command("display_counter", v.visit_id, "", price).ok, "counter accepted")
			"failed": check(s.counter_command("display_counter", v.visit_id, "", row.cap + 1).ok, "counter failed is completed decision")
			"reject": check(s.counter_command("reject", v.visit_id).ok and s._day.state.game_minutes == now, "reject free")
			"timeout":
				while v.status == "active": s.execute("short_task"); driver.drain(s)
				check(v.status == "timed_out", "buyer expiration")
			"withdraw": check(s.growth_command("withdraw").ok and v.status == "display_cancelled", "withdraw cancels buyer")
			"closed": check(s.execute("close_shop").ok and v.status == "shop_closed", "closing cancels waiting")
		if mode in ["accept", "counter"]:
			check(s._day.state.cash == cash + price and s._day.state.game_minutes == now + 5, "onsite price and time")
			check(s._day.state.sale_records.size() == 1 and s._day.state.shop_growth.display_id.is_empty(), "single sale clears display")
			check(s.receipt_for("sale/" + v.item.instance_id).get("amount", 0) == price, "existing receipt")
			check(not s.counter_command("display_accept", v.visit_id).ok, "no duplicate sale")
		else: check(s._day.state.cash == cash and s._day.state.sale_records.is_empty(), "no unintended sale " + mode)
		if mode != "counter": verify(s, "buyer " + mode)
	# Frozen price and quote priority across the buyer's deadline.
	var s := buyer_session(chosen); var v := s._counter.customers.active(s._day.state)
	var offer: int = ShopGrowthService.opportunity(s._day.state).offer
	s._day.state.game_minutes = v.expires_at - 5
	check(s.counter_command("display_accept", v.visit_id).ok and v.status == "display_sold", "quote resolves at expiry")
	check(s._day.state.sale_records.back().price == offer, "frozen quote")
	s = buyer_session(chosen); v = s._counter.customers.active(s._day.state)
	s._day.state.game_minutes = 535; v.expires_at = 540
	check(not s.counter_command("display_accept", v.visit_id).ok, "trade must finish strictly before 03")

func save_edges() -> void:
	var s := second_night()
	var before := s.read_state(); var visits := s._day.state.visits.size()
	s._save.fail = true
	check(not s.growth_command("build", "bench").ok, "save failure reported")
	check(s.read_state() == before and s._day.state.visits.size() == visits, "facility full rollback")
	s._save.fail = false; s.growth_command("build", "bench")
	var codec := SaveCodec.new(); var data := codec.encode(s._day.state, 25)
	for field in ["bench", "display", "investments", "exploration", "display_id", "opportunities"]:
		var forged := data.duplicate(true)
		if field in ["bench", "display"]: forged.shop_growth[field] = not forged.shop_growth[field]
		elif field == "display_id": forged.shop_growth[field] = "invented"
		else: forged.shop_growth[field] = [{"fake": true}]
		check(codec.decode(forged, run_def, 25, catalog, true) == null, "tamper rejected " + field)
	var forged := data.duplicate(true)
	forged.action_journal.append({"method": "growth_command", "args": ["build", "bench"]})
	check(codec.decode(forged, run_def, 25, catalog, true) == null, "invalid duplicate journal rejected")
	verify(s, "valid after tamper")
	var old_catalog := JsonContentProvider.new("res://data/mirror_investigation_manifest.json").load_catalog().catalog
	var old_run: RunDefinition = old_catalog.get_definition("runs", old_catalog.default_run_id)
	var old_store := GhostReplayStore.new()
	old_store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var old_s := RunSession.new(old_run, 23, old_store, old_catalog)
	check(not old_s._day.state.shop_growth_enabled and not old_s.read_state().has("shop_growth"), "old state shape unchanged")
	var old_payload := codec.encode(old_s._day.state, 23)
	check(codec.decode(old_payload, old_run, 23, old_catalog, true) != null, "old v23 load")
	check(codec.decode(old_payload, run_def, 25, catalog, true) == null, "old save not promoted to growth")
