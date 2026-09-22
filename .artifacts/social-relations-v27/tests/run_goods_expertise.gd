extends "res://tests/run_familiar_stories.gd"

const QA := "res://.godot/qa/goods/"
var fixtures := {}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA))
	var loaded := JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v21 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	unit_goods()
	distribution_goods()
	if "distribution" in OS.get_cmdline_user_args():
		print("GOODS DISTRIBUTION: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1); return
	for seed_value in (range(32) if "economy" in OS.get_cmdline_user_args() else range(3)):
		play_goods(seed_value, "review")
		if "economy" in OS.get_cmdline_user_args(): play_goods(seed_value, "plain")
	print("GOODS TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func make_item(id: String, variant: String, identity: String) -> ItemInstance:
	var item := ItemInstance.new(); item.instance_id = identity; item.definition_id = id; item.selected_variant_id = variant
	item.acquisition_price = 20
	return item

func unit_goods() -> void:
	var buyer := catalog.get_definition("buyers", "buyer_collector") as BuyerDefinition
	var service := CommerceService.new(catalog)
	var day := DayController.new(run_def, RunState.create(run_def)); day.state.phase = &"open"; day.state.run_seed = 3
	var fan := make_item(GoodsExpertise.FAN, "sound", "fan")
	day.state.inventory_instances.append(fan)
	for variant in ["sound", "flawed", "mended"]:
		fan.selected_variant_id = variant
		check(service.base_quote(fan, buyer) == 24, "unreviewed quote hides identity")
		var def := catalog.get_definition("items", fan.definition_id) as ItemDefinition
		fan.revealed_clue_ids = []
		for action in ["observe", "inspect", "crosscheck"]: AppraisalSystem.new().perform(fan, def, action)
		check(fan.revealed_clue_ids == ["form", "sound", "secondary_sound"], "inspection cannot reveal authorship")
	var before := day.state.cash
	check(GoodsExpertise.perform(day, catalog, "fan", ["fan"]).ok and day.state.cash == before - 6, "expert gives definite conclusion for fee")
	check(service.base_quote(fan, buyer) == 42, "reviewed copy identity quote")
	before = day.state.cash
	check(not GoodsExpertise.perform(day, catalog, "fan", ["fan"]).ok and day.state.cash == before, "no repeat fee")
	var a := make_item(GoodsExpertise.CUP, "sound", "a"); var b := make_item(GoodsExpertise.CUP, "sound", "b")
	a.goods = {"pattern": 0, "side": 0, "workshop": 0}; b.goods = {"pattern": 0, "side": 1, "workshop": 0}
	day.state.inventory_instances.append_array([a, b])
	check(GoodsExpertise.perform(day, catalog, "pair", ["b", "a"]).ok, "pair certificate")
	check(not GoodsExpertise.perform(day, catalog, "pair", ["a", "b"]).ok, "unordered repeat rejected")
	var quote := GoodsExpertise.pair_bonus(day.state, catalog, buyer, ["a", "b"], [["a", "b"]])
	check(quote.error.is_empty() and quote.bonuses.a == 11 and quote.bonuses.b == 10, "odd bonus deterministic split")
	check(not GoodsExpertise.pair_bonus(day.state, catalog, buyer, ["a", "b"], [["a", "b"], ["a", "b"]]).error.is_empty(), "duplicate pair rejected")
	for k in ["pattern", "side", "workshop"]:
		b.goods[k] = 1 - int(b.goods[k]); check(not GoodsExpertise.paired(a, b), "wrong " + k); b.goods[k] = 1 - int(b.goods[k])
	b.selected_variant_id = "flawed"
	check(not GoodsExpertise.pair_bonus(day.state, catalog, buyer, ["a", "b"], [["a", "b"]]).error.is_empty(), "damaged pair no premium")
	b.selected_variant_id = "sound"; b.ownership_state = "pledged"
	check(not GoodsExpertise.reason(day, catalog, "pair", ["a", "b"]).is_empty(), "pledge blocked")
	var state_before := day.state.to_read_model()
	check(not GoodsExpertise.perform(day, catalog, "fan", ["missing"]).ok and state_before == day.state.to_read_model(), "invalid transaction atomic")

func distribution_goods() -> void:
	var counts := {}; var match_count := 0
	var by_profession := {}; var by_state := {}; var cup_traits := {}; var seek_condition := {}
	for seed_value in 512:
		var state := RunState.create(run_def); state.run_seed = seed_value
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		check(rows.size() == 42 and rows == OpeningPreparation.plan(state, run_def, catalog), "stable complete plan")
		for row in rows:
			if row.item_id in ["item_silver_ring", "item_silver_lock", GoodsExpertise.FAN, GoodsExpertise.CUP]:
				counts[row.item_id] = int(counts.get(row.item_id, 0)) + 1
				var key: String = row.item_id + "/" + row.customer_id
				by_profession[key] = int(by_profession.get(key, 0)) + 1
				key = row.item_id + "/" + row.variant_id
				by_state[key] = int(by_state.get(key, 0)) + 1
				var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
				check(row.item_id in customer.item_pool, "new goods use matching profession pool")
			if row.item_id == GoodsExpertise.CUP:
				check(row.goods.size() == 3, "cup traits attached")
				var key := "%d/%d/%d" % [row.goods.pattern, row.goods.side, row.goods.workshop]
				cup_traits[key] = int(cup_traits.get(key, 0)) + 1
			if row.get("seven_role") == "pawn": check(row.terms_id == "sample_three_redeem", "protected pawn")
		state.current_night_index = 2
		var cup := make_item(GoodsExpertise.CUP, "sound", "target"); cup.goods = GoodsExpertise.traits(seed_value, "target"); cup.revealed_clue_ids = ["form"]
		state.inventory_instances.append(cup)
		var candidates := rows.filter(func(r: Dictionary) -> bool: return r.night == 2 and OpeningPreparation.ordinary(r) and not r.has("seven_role") and not r.get("familiar_reserved", false))
		if candidates.is_empty(): continue
		var found := GoodsSeeking.make(state, run_def, catalog, "target", candidates[0])
		check(found.goods.pattern == cup.goods.pattern and found.goods.side != cup.goods.side, "seeking visible constraints")
		if found.goods.workshop == cup.goods.workshop: match_count += 1
		seek_condition[found.variant_id] = int(seek_condition.get(found.variant_id, 0)) + 1
	check(counts.size() == 4 and match_count > 210 and match_count < 302, "new goods and fifty percent seek distribution")
	check(cup_traits.size() == 8 and cup_traits.values().all(func(n: int) -> bool: return n >= 100), "all natural pattern side workshop combinations")
	check(by_state.size() == 12 and seek_condition.size() == 3, "all twelve new goods states and independent seeking conditions")
	var file := FileAccess.open(QA + "distribution.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seeds": 512, "goods": counts, "profession_goods": by_profession, "states": by_state, "natural_cup_traits": cup_traits, "seek_matched": match_count, "seek_condition": seek_condition}, "  ")); file.close()

func play_goods(seed_value: int, strategy: String) -> void:
	run_def._randomize_seed = false; run_def._seed = seed_value
	var manager := SaveManager.new(QA + "runtime.json"); manager.library = SaveLibrary.new(QA + "library_%s_%d_%d.json" % [strategy, seed_value, Time.get_ticks_usec()])
	var s := RunSession.new(run_def, 21, manager, catalog); s.new_run()
	for night in range(1, 8):
		driver.drain(s)
		if night >= 2:
			if strategy == "review":
				for item in s._day.state.inventory_instances:
					if GoodsSeeking.reason(s._day.state, item.instance_id).is_empty():
						var seek := s.execute("prep_seek", item.instance_id)
						if seek.ok: check(PreparationService.used(s._day.state, "seek", night), "real seeking")
						break
			check(s.execute("prep_finish").ok, "finish preparation " + s.message)
		check(s.execute("open_shop").ok, "open " + s.message)
		driver.drain(s)
		for step in 150:
			if s._day.state.game_minutes >= 465 or failures > 0: break
			driver.drain(s)
			var returning := PawnReturnService.current(s._day.state)
			if not returning.is_empty(): check(s.counter_command("redeem", returning.id).ok, "redeem"); continue
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.item.definition_id in ["item_silver_ring", "item_silver_lock", GoodsExpertise.FAN, GoodsExpertise.CUP] and "sell" in v.transaction_modes and s._day.state.cash > 100:
					for action in ["observe", "inspect", "crosscheck"]:
						if s._counter.reason(s._day, "appraise", v.visit_id, action, 0).is_empty(): s.counter_command("appraise", v.visit_id, action)
					if v.status == "active" and v.trade.asking_price <= s._day.state.cash:
						check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "buy new goods")
				else: s.counter_command("reject", v.visit_id)
				continue
			if strategy == "review":
				var model: Dictionary = s.counter_model().inventory
				var worked := false
				for button in model.buttons:
					if button.command.begins_with("expert_") and button.enabled:
						check(s.commerce_command(button.command, button.target_id, button.detail).ok, "real expert work")
						worked = true; break
				if worked: continue
			# Both policies can use only current public quotes. Review policy holds
			# cups until final night to allow seeking; all other stock uses best quote.
			var buyers: Array = s.counter_model().inventory.sales.buyers
			var sold := false
			for buyer in buyers:
				if not buyer.reason.is_empty(): continue
				var ids := []
				for row in buyer.stock:
					var item := InventoryManager.new().find(s._day.state, row.id)
					if not row.reason.is_empty() or (strategy == "review" and night < 7 and item.definition_id == GoodsExpertise.CUP): continue
					if buyers.any(func(b: Dictionary) -> bool: return b.reason.is_empty() and b.stock.any(func(r: Dictionary) -> bool: return r.id == row.id and r.reason.is_empty() and r.price > row.price)): continue
					ids.append(row.id)
				if ids.is_empty(): continue
				var pairs := []; var used := []
				for pair in buyer.get("pairs", []):
					if pair.ids.all(func(id: String) -> bool: return id in ids and id not in used): pairs.append(pair.ids); used.append_array(pair.ids)
				check(s.sell_batch(buyer.id, ids, pairs).ok, "real batch")
				sold = true; break
			if not sold: s.execute("short_task")
		check(s.execute("close_shop").ok and s.execute("wait_until_seal").ok, "seal")
		check(s.execute("resolve_night").ok, "resolve " + s.message)
		for action in ["enter_room", "sleep", "finish_sleep"]: driver.drain(s); check(s.execute(action).ok, action + " " + s.message)
		check(s.execute("continue_run").ok, "continue " + s.message)
		var payload := SaveCodec.new().encode(s._day.state, 21); var codec := SaveCodec.new()
		check(codec.decode(JSON.parse_string(JSON.stringify(payload)), run_def, 21, catalog, true) != null, "restore " + codec.error_message)
		var file := FileAccess.open(QA + "%s_%d_%d.json" % [strategy, seed_value, night], FileAccess.WRITE); file.store_string(JSON.stringify(payload)); file.close()
		if failures > 0: return
	check(s._day.state.phase == &"run_ended", "seven nights complete")
