extends "res://tests/pawn_interest.gd"

func manifest_path() -> String:
	return "res://data/preopen_recycler_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/recycler/"

func ready_stock() -> RunSession:
	var s := fresh_growth(42)
	driver.drain(s)
	fixture(s, "first-preopen")
	check(BatchSaleReadModel.build(s._day, s._commerce).buyers.map(func(b: Dictionary) -> String: return b.id) == [RecyclerPolicy.BUYER], "initial buyer list only recycler")
	act(s, "open_shop"); driver.drain(s)
	fixture(s, "first-open")
	for guard in 100:
		var visit := s._counter.customers.active(s._day.state)
		if visit != null:
			if visit.trade.reserve_price <= s._day.state.cash and "sell" in visit.transaction_modes:
				check(s.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "natural stock acquisition")
			else: check(s.counter_command("reject", visit.visit_id).ok, "decline costly offer")
			driver.drain(s)
		else: act(s, "short_task"); driver.drain(s)
		if s._day.state.inventory_instances.size() >= 3: break
	check(s._day.state.inventory_instances.size() >= 3, "three owned items for batch test")
	finish_night(s); driver.drain(s)
	check(s._day.state.current_night_index == 2 and s._day.state.phase == &"pre_open", "second-night preparation")
	check(LuIntroduction.unlocked(s._day.state, run_def), "existing Lu introduction retained")
	return s

func blocked_sale(s: RunSession, ids: Array, label: String, buyer := RecyclerPolicy.BUYER, pairs: Array = []) -> void:
	var before := s.read_state()
	var result := s.sell_batch(buyer, ids, pairs)
	check(not result.ok, "reject " + label)
	check(before == s.read_state(), "no mutation " + label)

func run() -> void:
	if not setup(): quit(1); return
	pricing()
	var s := ready_stock()
	verify(s, "preopen ready")
	fixture(s, "preopen")
	var ids: Array = s._day.state.inventory_instances.map(func(i: ItemInstance) -> String: return i.instance_id)
	var before := s.read_state()
	var model := BatchSaleReadModel.build(s._day, s._commerce)
	var recycler: Dictionary = model.buyers.filter(func(b: Dictionary) -> bool: return b.id == RecyclerPolicy.BUYER)[0]
	check(recycler.preopen and recycler.action_points == 2 and recycler.reason.is_empty(), "ready recycler model")
	check(s.counter_model().inventory.business_selling and not s.counter_model().inventory.buttons.any(func(b: Dictionary) -> bool: return b.command == "sell"), "no inventory sale intents")
	check(before == s.read_state(), "quote browsing is free")
	blocked_sale(s, [], "empty batch")
	blocked_sale(s, [ids[0], ids[0]], "duplicate item")
	blocked_sale(s, ["missing"], "unknown item")
	blocked_sale(s, [ids[0]], "hidden collector", "buyer_collector")
	blocked_sale(s, [ids[0]], "hidden silversmith", "buyer_silversmith")
	blocked_sale(s, [ids[0]], "premature mirror channel", "buyer_mirror")
	blocked_sale(s, [ids[0], ids[1]], "unsupported pair", RecyclerPolicy.BUYER, [[ids[0], ids[1]]])
	(s._save as CountingStore).fail = true
	check(not s.commerce_command("sell", ids[0], RecyclerPolicy.BUYER).ok and s.read_state() == before, "single command rolls back on save failure")
	blocked_sale(s, [ids[0], ids[1]], "save failure cash inventory AP journal rollback")
	(s._save as CountingStore).fail = false
	var expected := 0
	for row in recycler.stock:
		if row.id in ids.slice(0, 2): expected += row.price
	check(s.sell_batch(RecyclerPolicy.BUYER, ids.slice(0, 2)).ok, "multi-item sale")
	check(s._day.state.cash == before.cash + expected, "preview equals actual income")
	check(PreparationService.action_points(s._day.state, run_def) == 1 and s._day.state.game_minutes == 0, "batch charges one AP and zero time")
	check(s._day.state.sale_batches.back().action_points == 1 and s._day.state.sale_records.size() == 2, "one trip two sales")
	var receipt := s.receipt_for(s._day.state.ledger_entries.back().transaction_id)
	check(receipt.note.contains("1行动点") and not receipt.note.contains("20分钟"), "receipt shows actual cost")
	verify(s, "after batch sale")
	fixture(s, "sold")
	blocked_sale(s, ids.slice(0, 2), "double submit")
	var codec := SaveCodec.new()
	var saved := codec.encode(s._day.state, catalog.content_version)
	for field in ["cash", "sale_price", "action_points", "journal"]:
		var bad := saved.duplicate(true)
		match field:
			"cash": bad.cash += 1
			"sale_price": bad.sale_records.back().price += 1
			"action_points": bad.sale_batches.back().action_points = 0
			"journal": bad.action_journal.pop_back()
		InvestigationSaveCodec.clear_cache()
		check(codec.decode(bad, run_def, catalog.content_version, catalog, true) == null, "tamper rejected " + field)
	check(s.sell_batch(RecyclerPolicy.BUYER, [ids[2]]).ok, "second same-night trip allowed")
	check(PreparationService.action_points(s._day.state, run_def) == 0, "second batch consumes last AP")
	var empty_before := s.read_state()
	check(not s.execute("prep_visitors").ok and s.read_state() == empty_before, "other preparation shares sale AP")
	verify(s, "two batches")
	fixture(s, "no-points")
	# Restore a fully replayable pre-sale point, and exhaust AP with preparations.
	InvestigationSaveCodec.clear_cache()
	s._day.state = codec.decode(JSON.parse_string(FileAccess.get_file_as_string(fixture_directory() + "preopen.json")), run_def, catalog.content_version, catalog, true)
	check(s.execute("prep_visitors").ok, "prepare before sale")
	check(s.sell_batch(RecyclerPolicy.BUYER, [ids[0]]).ok, "sale uses remaining shared point")
	blocked_sale(s, [ids[1]], "AP exhausted with owned stock")
	fixture(s, "no-points-stock")
	act(s, "open_shop"); driver.drain(s)
	blocked_sale(s, [ids[1]], "sale during opening forbidden")
	verify(s, "mixed AP and opening")
	finish_night(s); driver.drain(s)
	check(PreparationService.action_points(s._day.state, run_def) == 2, "next night restores two AP after sales")
	verify(s, "next night after recycler trips")
	# Controlled boundaries isolate ownership, risk and phase validations.
	var u := fresh_growth()
	u._day.state.current_night_index = 2; u._day.state.phase = &"pre_open"; u._day.state.pending_event_id = ""
	u._day.state.social.intro_step = 3
	var item := ItemInstance.new(); item.instance_id = "unit-stock"; item.definition_id = "intro_silver_hairpin"; item.selected_variant_id = "mended"; item.ownership_state = "pledged"
	u._day.state.inventory_instances.append(item)
	blocked_sale(u, [item.instance_id], "pledged collateral")
	item.ownership_state = "owned"; u._day.state.pending_event_id = "lu_visit_greeting"
	blocked_sale(u, [item.instance_id], "pending story")
	u._day.state.pending_event_id = ""; u._day.state.current_night_index = 1
	blocked_sale(u, [item.instance_id], "first night AP not open")
	u._day.state.current_night_index = 2
	check(u.execute("prep_finish").ok, "finish preparation boundary")
	blocked_sale(u, [item.instance_id], "finished preparation")
	channels()
	print("RECYCLER V47: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func pricing() -> void:
	check(RecyclerPolicy.amount(25, 70) == 17 and RecyclerPolicy.amount(25, 100) == 25, "explicit base rounding boundaries")
	check(RecyclerPolicy.amount(1, 70) == 1 and RecyclerPolicy.amount(9, 99) == 8, "small prices floor with minimum one")
	var rates := {}; var differences := 0; var day_changes := 0
	for seed_value in 128:
		for night in range(1, 9):
			var rate := RecyclerPolicy.rate(seed_value, night, "intro_silver_hairpin")
			rates[rate] = true
			check(rate >= 70 and rate <= 100 and rate == RecyclerPolicy.rate(seed_value, night, "intro_silver_hairpin"), "stable bounded daily rate")
			if rate != RecyclerPolicy.rate(seed_value, night, "item_fountain_pen"): differences += 1
			if rate != RecyclerPolicy.rate(seed_value, night + 1, "intro_silver_hairpin"): day_changes += 1
	check(rates.size() == 31 and differences > 0 and day_changes > 0, "all rates reachable and independent across types and days")
	var s := fresh_growth()
	var buyer := catalog.get_definition("buyers", RecyclerPolicy.BUYER) as BuyerDefinition
	for definition in catalog.get_all("items"):
		var item := ItemInstance.new(); item.definition_id = definition.id
		for variant in definition.possible_variants:
			item.selected_variant_id = variant.id
			check(s._commerce.quote(item, buyer, s._day) == RecyclerPolicy.price(s._day.state, definition), "variant ignored " + String(definition.id))

func channels() -> void:
	var s := fresh_growth()
	s._day.state.current_night_index = 3; s._day.state.phase = &"open"; s._day.state.game_minutes = 360
	s._day.state.pending_event_id = ""; s._day.state.visits.clear()
	var mirror := ItemInstance.new(); mirror.definition_id = "item_weeping_mirror"; mirror.instance_id = "unit-mirror"; mirror.ownership_state = "owned"; mirror.selected_variant_id = "weeping"
	s._day.state.inventory_instances.append(mirror)
	check(RecyclerPolicy.visible(s._day, "buyer_mirror"), "mirror channel revealed with owned mirror")
	check(not s._commerce.item_reason(s._day, mirror, catalog.get_definition("buyers", RecyclerPolicy.BUYER)).is_empty(), "haunted mirror not regular recycler stock")
	check(not RecyclerPolicy.visible(s._day, "buyer_pen_appointment"), "pen contract hidden before intel")
	var mirror_cash := s._day.state.cash
	check(s._commerce.sell_batch(s._day, "buyer_mirror", [mirror.instance_id]).ok, "retained mirror channel executes")
	check(s._day.state.game_minutes == 380 and s._day.state.cash == mirror_cash + 90 and RecyclerPolicy.spent(s._day.state) == 0, "mirror price and 20-minute trip retained")
	s._day.state.current_night_index = 6; s._day.state.game_minutes = 60; s._day.state.phase = &"open"; s._day.state.pending_event_id = ""; s._day.state.visits.clear()
	check(RecyclerPolicy.visible(s._day, "buyer_pen_appointment"), "sixth night contract retained")
	var pen := ItemInstance.new(); pen.instance_id = "unit-pen"; pen.definition_id = "item_fountain_pen"; pen.selected_variant_id = "sound"; pen.ownership_state = "owned"
	s._day.state.inventory_instances.append(pen)
	check(s._commerce.sell_batch(s._day, "buyer_pen_appointment", [pen.instance_id]).ok and s._day.state.game_minutes == 80, "retained pen appointment sells with original time cost")
	check(not RecyclerPolicy.visible(s._day, "buyer_mirror"), "mirror channel disappears after departure")
	var old := JsonContentProvider.new("res://data/gramophone_release_manifest.json").load_catalog()
	check(old.is_success(), "v46 catalog retained")
	var old_run: RunDefinition = old.catalog.get_definition("runs", old.catalog.default_run_id)
	check(not RecyclerPolicy.enabled(old_run) and catalog.content_version == 47 and old.catalog.content_version == 46, "version isolation")
	var old_store := CountingStore.new()
	old_store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var legacy := RunSession.new(old_run, old.catalog.content_version, old_store, old.catalog)
	check(RecyclerPolicy.visible(legacy._day, "buyer_collector"), "old collector remains available")
	check(not legacy.counter_model().inventory.business_selling, "old inventory sale tab retained")
