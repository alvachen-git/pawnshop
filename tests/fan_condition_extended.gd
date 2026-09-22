extends "res://tests/fan_condition.gd"

func run() -> void:
	if not setup(): quit(1); return
	disk_checks()
	economy_checks()
	more_boundaries()
	display_prices()
	redemption_and_rounding()
	print("FAN CONDITION EXTENDED: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func disk_checks() -> void:
	var s := load_case("stack")
	var manager := SaveManager.new("user://tests/fan_condition/auto.json")
	manager.catalog = catalog; manager.library = SaveLibrary.new("user://tests/fan_condition/library.json")
	check(manager.save_state(s._day.state, run_def, 29), "real disk initial save")
	s._save = manager
	for command in ["condition", "fan_pressure", "condition_pressure", "offer"]:
		var visit := CustomerManager.new().active(s._day.state)
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(manager.library.path)
		var amount := int(FanBargainingService.attempt(s._day.state, visit).reserve) if command == "offer" else 0
		manager.library.fail_write = true
		var result := s.fan_command(command, visit.item.instance_id) if command == "condition" else s.counter_command(command, visit.visit_id, "", amount)
		check(not result.ok and s.read_state() == before and bytes == FileAccess.get_file_as_bytes(manager.library.path), "actual disk rollback " + command)
		manager.library.fail_write = false
		visit = CustomerManager.new().active(s._day.state)
		result = s.fan_command(command, visit.item.instance_id) if command == "condition" else s.counter_command(command, visit.visit_id, "", amount)
		check(result.ok, "actual disk retry " + command)
	var restored := manager.load_state(run_def, 29)
	check(restored != null and GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "real library purchase exact restore")
	fixture(s, "saved-sale")
	for field in ["fan_condition", "condition_checked", "condition_pressure"]:
		var payload := SaveCodec.new().encode(s._day.state, 29)
		for row in payload.inventory_instances:
			if row.definition_id == GoodsExpertise.FAN: row.goods.erase(field)
		InvestigationSaveCodec.clear_cache()
		check(SaveCodec.new().decode(payload, run_def, 29, catalog, true) == null, "tampered goods rejected " + field)

func economy_checks() -> void:
	var report := []
	for grade in ["minor", "major"]:
		for strategy in ["ordinary", "damage", "fake", "both"]:
			var s := load_case(grade + "-checked")
			var visit := CustomerManager.new().active(s._day.state)
			var before := s._day.state.game_minutes
			if strategy in ["damage", "both"]: check(s.counter_command("condition_pressure", visit.visit_id).ok, "economy damage")
			if strategy in ["fake", "both"]: check(s.counter_command("fan_pressure", visit.visit_id).ok, "economy fake")
			var quote := FanBargainingService.attempt(s._day.state, visit)
			var price: int = quote.reserve if quote.get("accepted", false) else visit.trade.reserve_price
			check(s.counter_command("offer", visit.visit_id, "", price).ok, "economic purchase")
			var events: Array = FanBargainingService.data(s._day.state).reputation_events
			check(events.is_empty() if strategy in ["ordinary", "damage"] else events.size() == (1 if visit.item.selected_variant_id == "sound" else 0), "damage alone never penalizes reputation")
			for i in 10:
				var current := CustomerManager.new().active(s._day.state)
				if current == null: break
				s.counter_command("reject", current.visit_id)
			var result := s.commerce_command("sell", visit.item.instance_id, "buyer_recycler")
			var delayed := not result.ok
			var handling := s._day.state.game_minutes - before
			if delayed:
				check(result.message.contains("来不及"), "late sale correctly blocked")
				finish_night(s); driver.drain(s); act(s, "open_shop"); driver.drain(s)
				for i in 10:
					var current := CustomerManager.new().active(s._day.state)
					if current == null: break
					s.counter_command("reject", current.visit_id)
				result = s.commerce_command("sell", visit.item.instance_id, "buyer_recycler")
				check(result.ok, "stock can sell next night " + result.message)
				handling += 20
			else: check(result.ok, "same-night actual resale")
			if not result.ok: continue
			var sale: Dictionary = s._day.state.sale_records.back()
			var row := {"condition": grade, "strategy": strategy, "cost": price, "income": sale.price, "profit": sale.realized_profit, "handling_minutes": handling, "held_overnight": delayed, "sold_night": s._day.state.current_night_index}
			report.append(row); print("CONDITION ECONOMY ", row)
	DirAccess.make_dir_recursive_absolute("res://docs/qa/fan-condition")
	FileAccess.open("res://docs/qa/fan-condition/economy.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))

func more_boundaries() -> void:
	for stage in ["ordinary-ready", "informed-ready", "urgent-ready"]:
		var expected := {}
		for truth in ["sound", "mended", "flawed"]:
			var s := load_case(stage)
			var visit := CustomerManager.new().active(s._day.state)
			visit.item.selected_variant_id = truth; visit.item.goods.fan_condition = "major"; visit.item.goods.condition_checked = true
			var result := s.counter_command("condition_pressure", visit.visit_id)
			check(result.ok, "knowledge and truth do not resist proven damage")
			var public := {"message": result.message, "ask": visit.trade.asking_price, "reserve": visit.trade.reserve_price}
			if expected.is_empty(): expected = public
			else: check(public == expected, "no truth oracle in damage reaction")
	for minute in [534, 535, 536]:
		var s := load_case("minor")
		var visit := CustomerManager.new().active(s._day.state)
		visit.expires_at = 600; s._day.state.game_minutes = minute
		check(s.fan_command("condition", visit.item.instance_id).ok == (minute < 535), "strict closing boundary")
	for price in [1, 2, 3, 5]:
		var s := load_case("major-checked")
		var visit := CustomerManager.new().active(s._day.state)
		visit.trade.asking_price = price; visit.trade.reserve_price = price
		check(s.counter_command("condition_pressure", visit.visit_id).ok, "small damage price")
		check(visit.trade.asking_price == maxi(1, roundi(price * .5)) and visit.trade.reserve_price >= 1, "round half up minimum one")
	var s := load_case("minor-checked")
	var visit := CustomerManager.new().active(s._day.state)
	visit.trade.rounds_left = 1
	check(s.counter_command("condition_pressure", visit.visit_id).ok and visit.status == "rounds_exhausted", "last damage round seller leaves")
	check(FanBargainingService.data(s._day.state).reputation_events.is_empty(), "no sale no event")
	# Owned fans can be inspected; pawned and sold fans cannot.
	for mode in ["offer", "pawn"]:
		s = load_case("minor"); visit = CustomerManager.new().active(s._day.state)
		check(s.counter_command(mode, visit.visit_id, "", visit.trade.asking_price).ok, "acquire unchecked fan")
		check(s.fan_command("condition", visit.item.instance_id).ok == (mode == "offer"), "inspect only owned inventory")
		if mode == "offer":
			fixture(s, "owned-checked")
			check(s.commerce_command("sell", visit.item.instance_id, "buyer_recycler").ok, "sell inspected owned fan")
			invalid_fan(s, "condition", visit.item.instance_id)

func display_prices() -> void:
	for grade in ["intact", "minor", "major"]:
		for expert in [false, true]:
			for source in ["unchecked", "verified"]:
				var s := load_case("minor")
				var visit := CustomerManager.new().active(s._day.state)
				visit.purpose = "display_buyer"
				visit.item.goods.fan_condition = grade
				visit.item.expert_reviewed = expert
				visit.item.selected_variant_id = "sound"
				visit.item.provenance.status = source
				var row := {"night": s._day.state.current_night_index, "status": "scheduled", "offer_factor": 110, "cap_factor": 130}
				s._day.state.shop_growth.opportunities = [row]
				ShopGrowthService.activate(s._day.state, visit)
				var value := maxi(1, roundi((75 if expert else 20) * int(FanConditionService.RETAIN[grade]) / 100.0))
				var base := maxi(1, roundi(value * 1.1))
				var cap := maxi(1, roundi(value * 1.3))
				check(row.offer == base + (floori(base * .15) if source == "verified" else 0), "display damage before factor and source premium")
				check(row.cap == cap + (floori(cap * .15) if source == "verified" else 0), "display cap same pipeline")
				var original: int = row.offer
				visit.item.goods.condition_checked = true
				ShopGrowthService.activate(s._day.state, visit)
				check(row.offer == original, "inspection does not refresh fixed buyer quote")

func redemption_and_rounding() -> void:
	var s := load_case("minor-fan_pressure-pawn")
	var ticket: PawnTicket = s._day.state.pawn_tickets.back()
	var collateral := InventoryManager.new().find(s._day.state, ticket.collateral_id())
	s._day.state.pawn_returns.append({"id": "test-return", "ticket_id": ticket.ticket_id, "customer_id": ticket.customer_id, "item_instance_id": collateral.instance_id, "night": s._day.state.current_night_index, "status": "waiting", "command": "redeem", "minutes": 5})
	var model := s.counter_model()
	check(model.visual.estimate == FanConditionService.estimate(collateral, catalog.get_definition("items", GoodsExpertise.FAN)), "redemption retains known condition instead of old estimate")
	check(not model.appraisal.buttons.any(func(b: Dictionary) -> bool: return b.command in ["condition", "fan_open"]), "return handling blocks new inspections")
	s = load_case("ordinary-ready")
	var visit := CustomerManager.new().active(s._day.state)
	visit.item.selected_variant_id = "sound"; visit.item.goods.fan_condition = "major"; visit.item.goods.condition_checked = true
	visit.trade.asking_price = 2; visit.trade.reserve_price = 2
	check(s.counter_command("fan_pressure", visit.visit_id).ok and FanBargainingService.attempt(s._day.state, visit).asking == 2, "rounding creates no actual fake concession")
	check(s.counter_command("condition_pressure", visit.visit_id).ok and visit.trade.asking_price == 1, "later real damage lowers price")
	check(s.counter_command("offer", visit.visit_id, "", 1).ok, "buy after actual damage concession")
	check(FanBargainingService.data(s._day.state).reputation_events.is_empty(), "damage discount not misattributed to fake claim")
