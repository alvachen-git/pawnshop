extends "res://tests/recycler_sales.gd"

func manifest_path() -> String:
	return "res://data/silver_market_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/silver/"

func market_checks() -> void:
	var regimes := {}; var flat := {}
	for seed_value in 120:
		var prior := -1
		for cycle in 5:
			var first := SilverPolicy.market(seed_value, cycle * 5 + 1)
			check(first.regime != prior, "consecutive cycles differ")
			prior = first.regime; regimes[prior] = true
			for day in 5:
				var row := SilverPolicy.market(seed_value, cycle * 5 + day + 1)
				check(row.regime == first.regime and row.day == day + 1, "five-day boundaries")
				check(row == SilverPolicy.market(seed_value, cycle * 5 + day + 1), "stable seeded market")
				if row.regime == 1:
					flat[row.percent] = true; check(row.percent >= 90 and row.percent <= 110, "bounded sideways")
				else: check(row.percent == (SilverPolicy.BULL if row.regime == 0 else SilverPolicy.BEAR)[day], "authored bull bear rates")
	check(regimes.size() == 3 and flat.size() == 21, "all regimes and flat endpoints reachable")
	check(SilverPolicy.amount(1, 40) == 1 and SilverPolicy.amount(25, 110) == 28 and SilverPolicy.amount(12, 180) == 22, "round half up and minimum one")

func unit_checks() -> void:
	var s := fresh_growth()
	SocialRules.change(s._day.state, "reputation", 15, "unit")
	check(SilverPolicy.invited_night(s._day.state) == 0, "15 does not invite")
	SocialRules.change(s._day.state, "reputation", 1, "unit")
	check(SilverPolicy.invited_night(s._day.state) == 1 and not SilverPolicy.due(s._day.state), "16 invites for later night")
	SocialRules.change(s._day.state, "reputation", -20, "unit")
	s._day.state.current_night_index = 2
	check(SilverPolicy.due(s._day.state), "invitation persists despite falling reputation")
	s._day.state.narrative_flags.append(SilverPolicy.FLAG)
	check(SilverPolicy.unlocked(s._day.state), "unlock survives falling reputation")
	var buyer := catalog.get_definition("buyers", SilverPolicy.BUYER) as BuyerDefinition
	for id in ["intro_silver_hairpin", "item_silver_hairpin", "item_silver_ring", "item_silver_lock", "item_luxury_gold_bangle", "item_luxury_silver_service"]:
		var definition := catalog.get_definition("items", id) as ItemDefinition
		for variant in definition.possible_variants:
			var item := ItemInstance.new(); item.definition_id = id; item.selected_variant_id = variant.id; item.ownership_state = "owned"
			SilverPolicy.attach(item, run_def)
			check(SilverPolicy.item_reason(item, definition).is_empty() == (id in run_def.variety.silver_trade.items), "true silver jewelry by material and category " + id + variant.id)
			if id not in run_def.variety.silver_trade.items: continue
			for origin in SilverPolicy.ORIGINS:
				item.silver_trade.origin = origin
				check(SilverPolicy.item_reason(item, definition).is_empty() == (origin in ["ordinary", "inherited"]), "explicit origin " + origin)
			item.silver_trade.origin = "ordinary"
			for material in SilverPolicy.MATERIALS:
				item.silver_trade.material = material
				check(SilverPolicy.item_reason(item, definition).is_empty() == (material == "silver"), "material " + material)
			item.silver_trade.material = "silver"
			check(s._commerce.quote(item, buyer, s._day) == SilverPolicy.amount(variant.true_value, SilverPolicy.rate(s._day.state)), "condition valuation and daily rate")
	var old := JsonContentProvider.new("res://data/preopen_recycler_manifest.json").load_catalog()
	check(old.is_success() and not SilverPolicy.enabled(old.catalog.get_definition("runs", old.catalog.default_run_id)), "v47 retains old rules")

func silver_journey() -> RunSession:
	var s := fresh_growth(42)
	for night in 12:
		if SilverPolicy.active(s._day.state): return s
		driver.drain(s)
		if s._day.state.current_night_index >= 2:
			var goods: Array = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state == "owned" and i.definition_id != "intro_silver_hairpin" and s._commerce.item_reason(s._day, i, catalog.get_definition("buyers", RecyclerPolicy.BUYER)).is_empty()).map(func(i: ItemInstance) -> String: return i.instance_id)
			if not goods.is_empty(): check(s.sell_batch(RecyclerPolicy.BUYER, goods).ok, "fund next night's trading through recycler")
			if s._day.state.current_night_index >= 4 and s._day.state.cash > 45 and s.can_execute("prep_advertise"): check(s.execute("prep_advertise").ok, "advertise naturally")
		act(s, "open_shop"); driver.drain(s)
		for guard in 180:
			if failures or s._day.state.phase != &"open": break
			var visit := s._counter.customers.active(s._day.state)
			if visit == null:
				if s._day.state.game_minutes >= 490: break
				act(s, "short_task"); driver.drain(s); continue
			var offer := maxi(visit.trade.reserve_price, ceili(visit.trade.opening_price * 1.2))
			var eligible := ReputationService.eligible(s._day.state, visit)
			if (eligible or visit.item.definition_id == "intro_silver_hairpin") and offer <= mini(85, s._day.state.cash - 10) and "sell" in visit.transaction_modes:
				check(s.counter_command("offer", visit.visit_id, "", offer).ok, "fair funded acquisition")
			else: check(s.counter_command("reject", visit.visit_id).ok, "decline without bad quote")
			driver.drain(s)
			if SilverPolicy.invited_night(s._day.state) > 0 or s._day.state.social.trades.filter(func(t: Dictionary) -> bool: return t.night == s._day.state.current_night_index and t.delta > 0).reduce(func(total: int, t: Dictionary) -> int: return total + int(t.delta), 0) >= 6: break
		print("SILVER JOURNEY night=%d reputation=%d cash=%d" % [s._day.state.current_night_index, s._day.state.social.reputation, s._day.state.cash])
		finish_night(s)
		if failures or s._day.state.phase in [&"dead", &"bankrupt"]: break
	check(false, "natural reputation unlock reached")
	return s

func run() -> void:
	if not setup(): quit(1); return
	market_checks(); unit_checks(); unit_sales()
	var s := silver_journey()
	if failures: print("SILVER: %d passes, %d failures" % [passes, failures]); quit(1); return
	var n := s._day.state.current_night_index
	check(n == SilverPolicy.invited_night(s._day.state) + 1, "next night arrival")
	for step in 3:
		verify(s, "introduction page " + str(step)); fixture(s, "intro-" + str(step))
		check(SilverPolicy.active(s._day.state) and s._day.state.pending_event_id == SilverPolicy.EVENTS[step], "ordered story page")
		check(not s.can_execute("open_shop") and not SilverPolicy.unlocked(s._day.state), "opening and silver sales locked during intro")
		var before := s.read_state()
		(s._save as CountingStore).fail = true
		check(not s.counter_command("silver_intro", SilverPolicy.EVENTS[step], "continue").ok and s.read_state() == before, "intro save failure rollback")
		(s._save as CountingStore).fail = false
		check(s.counter_command("silver_intro", SilverPolicy.EVENTS[step], "continue").ok, "advance silver introduction")
		check(s._day.state.game_minutes == 0 and PreparationService.action_points(s._day.state, run_def) == 2, "story costs no time or AP")
	check(SilverPolicy.unlocked(s._day.state), "farewell permanently unlocks")
	verify(s, "unlocked"); fixture(s, "unlocked")
	var item: ItemInstance = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.definition_id == "intro_silver_hairpin" and i.ownership_state == "owned")[0]
	var before := s.read_state()
	var model := BatchSaleReadModel.build(s._day, s._commerce)
	var buyer: Dictionary = model.buyers.filter(func(b: Dictionary) -> bool: return b.id == SilverPolicy.BUYER)[0]
	check(buyer.preopen and buyer.daily_rate == SilverPolicy.rate(s._day.state) and not buyer.has("regime") and not buyer.has("day"), "public model only current percentage")
	check(before == s.read_state(), "browsing no mutation")
	blocked_sale(s, [], "empty silver batch", SilverPolicy.BUYER)
	blocked_sale(s, [item.instance_id, item.instance_id], "duplicate silver item", SilverPolicy.BUYER)
	blocked_sale(s, [item.instance_id], "silver pair bonuses", SilverPolicy.BUYER, [[item.instance_id, item.instance_id]])
	(s._save as CountingStore).fail = true
	blocked_sale(s, [item.instance_id], "silver save failure", SilverPolicy.BUYER)
	check(not s.commerce_command("sell", item.instance_id, SilverPolicy.BUYER).ok and s.read_state() == before, "single sell rollback")
	(s._save as CountingStore).fail = false
	var price := s._commerce.quote(item, catalog.get_definition("buyers", SilverPolicy.BUYER), s._day)
	check(s.commerce_command("sell", item.instance_id, SilverPolicy.BUYER).ok, "single API uses batch silver contract")
	check(s._day.state.cash == before.cash + price and s._day.state.game_minutes == 0 and PreparationService.action_points(s._day.state, run_def) == 1, "funds AP time")
	verify(s, "sold"); fixture(s, "sold")
	blocked_sale(s, [item.instance_id], "repeat silver sale", SilverPolicy.BUYER)
	var saved := SaveCodec.new().encode(s._day.state, catalog.content_version)
	for field in ["price", "origin", "material", "unlock", "reputation", "seed", "AP"]:
		var bad := saved.duplicate(true)
		match field:
			"price": bad.sale_records.back().price += 1
			"origin": bad.inventory_instances[0].silver_trade.origin = "corpse"
			"material": bad.inventory_instances[0].silver_trade.material = "silver_plated"
			"unlock": bad.narrative_flags.erase(SilverPolicy.FLAG)
			"reputation": bad.social.changes[0].after = 16
			"seed": bad.run_seed += 1
			"AP": bad.sale_batches.back().action_points = 0
		InvestigationSaveCodec.clear_cache()
		check(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog, true) == null, "reject forged " + field)
	act(s, "open_shop"); driver.drain(s)
	blocked_sale(s, [item.instance_id], "silver during opening", SilverPolicy.BUYER)
	finish_night(s); driver.drain(s)
	check(SilverPolicy.unlocked(s._day.state) and not SilverPolicy.active(s._day.state), "no repeated introduction")
	verify(s, "next day"); fixture(s, "next-day")
	print("SILVER: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

# Controlled service boundaries complement the fully replayable journey.
func unit_sales() -> void:
	var s := fresh_growth()
	s._day.state.current_night_index = 4; s._day.state.phase = &"pre_open"; s._day.state.pending_event_id = ""; s._day.state.social.intro_step = 3
	s._day.state.narrative_flags.append(SilverPolicy.FLAG)
	var buyer := catalog.get_definition("buyers", SilverPolicy.BUYER) as BuyerDefinition
	for index in 3:
		var item := ItemInstance.new(); item.definition_id = "item_silver_ring"; item.selected_variant_id = ["sound", "mended", "flawed"][index]
		item.instance_id = "unit-silver-%d" % index; item.ownership_state = "owned"; SilverPolicy.attach(item, run_def)
		s._day.state.inventory_instances.append(item)
	var items := s._day.state.inventory_instances
	var ids := items.map(func(i: ItemInstance) -> String: return i.instance_id)
	var before := s.read_state()
	items[1].silver_trade.origin = "corpse"
	var refused_before := s.read_state()
	check(not s._commerce.sell_batch(s._day, SilverPolicy.BUYER, ids).ok and s.read_state() == refused_before, "mixed batch atomic rejection before cost")
	items[1].silver_trade.origin = "ordinary"
	items[1].ownership_state = "pledged"
	check(not s._commerce.sell_batch(s._day, SilverPolicy.BUYER, ids).ok, "pledged silver cannot be sold")
	items[1].ownership_state = "owned"
	var expected := 0
	for item in items: expected += s._commerce.quote(item, buyer, s._day)
	check(s._commerce.sell_batch(s._day, SilverPolicy.BUYER, ids.slice(0, 2)).ok and PreparationService.action_points(s._day.state, run_def) == 1, "two silver goods one AP")
	check(s._commerce.sell_batch(s._day, SilverPolicy.BUYER, [ids[2]]).ok and PreparationService.action_points(s._day.state, run_def) == 0, "second batch last AP")
	check(s._day.state.cash == before.cash + expected, "individually rounded batch total")
	var item := ItemInstance.new(); item.definition_id = "item_silver_lock"; item.selected_variant_id = "sound"; item.instance_id = "remaining"; item.ownership_state = "owned"; SilverPolicy.attach(item, run_def); items.append(item)
	var exhausted := s.read_state()
	check(not s._commerce.sell_batch(s._day, SilverPolicy.BUYER, [item.instance_id]).ok and s.read_state() == exhausted, "exhausted AP with valid owned silver")
	s._day.state.current_night_index = 5
	check(s._commerce.trip_reason(s._day, buyer).is_empty() and PreparationService.action_points(s._day.state, run_def) == 2, "next night resets shared AP")
	s._day.state.preparation_history.append({"action":"finish","night":5})
	check(not s._commerce.trip_reason(s._day, buyer).is_empty(), "finished preparation blocks silver")
	s._day.state.preparation_history.clear(); s._day.state.phase = &"open"
	check(not s._commerce.trip_reason(s._day, buyer).is_empty(), "silver rejects open phase")
	# Ensure the invitation waits behind both existing introductions.
	var intro := fresh_growth(); SocialRules.change(intro._day.state, "reputation", 16, "unit")
	intro._day.state.current_night_index = 2; intro._day.state.pending_event_id = "lu_visit_greeting"
	check(not SilverPolicy.active(intro._day.state) and not intro.counter_command("silver_intro", "silver_greeting", "continue").ok, "existing Lu event cannot be overwritten")
	intro._day.state.pending_event_id = "silver_greeting"; intro._day.state.social.intro_step = 0
	check(MilitaryIntroduction.active(intro._day.state) and not SilverPolicy.active(intro._day.state), "military greeting retains priority")
