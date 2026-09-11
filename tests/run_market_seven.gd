extends "res://tests/run_mirror_chapter.gd"

var combined := "combined" in OS.get_cmdline_user_args()

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/goods_expertise_manifest.json" if "goods" in OS.get_cmdline_user_args() else "res://data/pawn_chance_manifest.json" if "chance" in OS.get_cmdline_user_args() else "res://data/market_familiar_manifest.json" if combined else "res://data/market_seven_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v17 market seven catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/market_seven"))
	contract()
	batch_edges()
	preparation_timing()
	for route in ["ability", "pursue", "death", "reject", "sold", "missed"]: chapter(route)
	compatibility()
	print("MARKET SEVEN TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func chapter_transfer_path() -> String:
	return "res://.godot/qa/market_seven/chance_cross_process.json" if "chance" in OS.get_cmdline_user_args() else "res://.godot/qa/market_seven/combined_cross_process.json" if combined else "res://.godot/qa/market_seven/cross_process.json"

func contract() -> void:
	var found := {}
	for seed_value in 256:
		var rows := MarketService.plan(run_def, seed_value)
		check(rows.size() == 8 and rows == MarketService.plan(run_def, seed_value), "eight stable demand messages")
		for index in range(1, 8):
			var row: Dictionary = rows[index]
			check(row.night == index and row.minute >= 120 and row.minute <= 300 and row.minute % 5 == 0 and row.demand_id != rows[index - 1].demand_id, "one non-repeating change each night")
			found[row.demand_id] = true
			if index > 1: check(MarketService.current(run_def, seed_value, index, 0) == rows[index - 1], "carry demand into next night")
	check(found.size() == 6, "all six external demands")
	var lu: BuyerDefinition = catalog.get_definition("buyers", "buyer_lu")
	check(lu.night_min == 1 and lu.night_max == 7 and lu.value_multiplier == 1.4 and lu.capacity_per_night == 0, "lu seven-night pricing")
	var s := fresh("read_only")
	var before := s.read_state()
	for i in 3: s.counter_model(); s.event_model()
	check(before == s.read_state(), "viewing cannot change demand or reveal future")
	check(s.counter_model().inventory.sales.history.contains(MarketService.demand(run_def, before.market_history[0]).body), "initial current message visible")
	var appointment: BuyerDefinition = catalog.get_definition("buyers", PreparationService.BUYER)
	check(appointment.value_multiplier == 1.25 and appointment.night_min == 6 and appointment.window_end == 180, "appointment unchanged")
	for definition: ItemDefinition in catalog.get_all("items"):
		for variant: ItemVariantDefinition in definition.possible_variants:
			var item := ItemInstance.new()
			item.definition_id = definition.id; item.selected_variant_id = variant.id
			var base := maxi(1, roundi(GoodsExpertise.value(item, definition) * 1.4))
			check(s._commerce.quote(item, lu) == base, "all variant price rounding")
			item.provenance = {"status": "verified"}
			check(s._commerce.quote(item, lu) == base + floori(base * 0.15), "verified source premium")

func fixture(night := 1, minute := 0) -> RunSession:
	var s := fresh("fixture")
	s._day.state.phase = &"open"
	s._day.state.pending_event_id = ""
	s._day.state.visits.clear()
	s._day.state.current_night_index = night
	s._day.state.game_minutes = minute
	MarketService.sync(s._day.state, run_def)
	return s

func stock(s: RunSession, id := "item_fountain_pen", variant := "sound") -> ItemInstance:
	var i := ItemInstance.new()
	i.definition_id = id; i.selected_variant_id = variant
	i.instance_id = "fixture/%d" % s._day.state.inventory_instances.size()
	i.acquisition_price = 10; i.acquired_night = 1
	s._day.state.inventory_instances.append(i)
	return i

func batch_edges() -> void:
	var s := fixture(4)
	for seed_value in 128:
		if MarketService.demand(run_def, MarketService.current(run_def, seed_value, 4, 0)).category == "stationery":
			s._day.state.run_seed = seed_value; break
	MarketService.sync(s._day.state, run_def)
	var pens: Array = [stock(s).instance_id, stock(s, "item_fountain_pen", "replacement_nib").instance_id]
	var first := s.read_state()
	check(s.sell_batch("buyer_lu", pens).ok and s._day.state.game_minutes == 20 and s._day.state.sale_records.size() == 2, "two real-variant pens sold early in one trip")
	check(s._day.state.cash > first.cash and s._day.state.sale_batches.size() == 1, "one batch ledger total")
	var after := s.read_state()
	check(not s.sell_batch("buyer_lu", pens).ok and after == s.read_state(), "no repeated sale")
	s._day.state.current_night_index = 6; s._day.state.game_minutes = 60
	check(not s.sell_batch(PreparationService.BUYER, pens).ok, "sold pens cannot be submitted to appointment")
	var kept := fixture(6, 60)
	check(kept.sell_batch(PreparationService.BUYER, [stock(kept).instance_id]).ok, "same pen kind can instead be held for appointment")
	var late := fixture(6, 160)
	var item := stock(late)
	before_unchanged(late, PreparationService.BUYER, [item.instance_id], "trip cannot finish at closing boundary")
	late._day.state.current_night_index = 7; late._day.state.game_minutes = 60
	before_unchanged(late, PreparationService.BUYER, [item.instance_id], "missed appointment not rescheduled")
	for kind in ["active", "waiting", "return", "story", "risk"]:
		var blocked := fixture()
		item = stock(blocked)
		if kind in ["active", "waiting"]:
			var guest := CustomerVisit.new(); guest.status = kind; blocked._day.state.visits.append(guest)
		elif kind == "return": blocked._day.state.pawn_returns.append({"night": 1, "status": "waiting"})
		elif kind == "story": blocked._day.state.pending_event_id = "pending"
		else: blocked._day.state.risk_pending = "pending"
		before_unchanged(blocked, "buyer_recycler", [item.instance_id], "blocked by " + kind)
	var invalid := fixture()
	item = stock(invalid)
	for ids in [[], [item.instance_id, item.instance_id], [item.instance_id, "missing"]]: before_unchanged(invalid, "buyer_recycler", ids, "atomic invalid batch")
	var across := fixture()
	var change: Dictionary = MarketService.plan(run_def, across._day.state.run_seed)[1]
	across._day.state.game_minutes = change.minute - 10
	MarketService.sync(across._day.state, run_def)
	for definition: ItemDefinition in catalog.get_all("items"):
		if definition.category != MarketService.category(across._day): continue
		item = stock(across, definition.id, definition.possible_variants[0].id)
		var old_id: String = across._day.state.market_history.back().id
		check(across.sell_batch("buyer_lu", [item.instance_id]).ok, "departure demand locks across change")
		check(across._day.state.sale_batches.back().market_id == old_id and across._day.state.market_history.back().id != old_id, "old quote and new notice retained independently")
		break
	var incoming := fixture(1, 80)
	var guest := CustomerVisit.new(); guest.status = "scheduled"; guest.arrival = 85; guest.expires_at = 150
	incoming._day.state.visits.append(guest)
	check(incoming.sell_batch("buyer_recycler", [stock(incoming).instance_id]).ok and guest.status == "active", "incoming customer waits during trip")
	var history := fixture(4)
	var model: Dictionary = history.counter_model().inventory.sales
	check(model.history.contains("外埠") and model.history.contains("陆掌眼") and not model.history.contains(PreparationService.DETAILS), "both messages visible without revealing appointment details")
	var appointment_card: Dictionary = model.buyers.filter(func(b: Dictionary) -> bool: return b.id == PreparationService.BUYER)[0]
	check(appointment_card.wanted.contains("细目待打听"), "unknown requirements stay unknown")
	before_unchanged(history, "buyer_lu", [stock(history, "item_weeping_mirror").instance_id], "lu never accepts ghost goods")

func before_unchanged(s: RunSession, buyer: String, ids: Array, label: String) -> void:
	var before := s.read_state()
	check(not s.sell_batch(buyer, ids).ok and s.read_state() == before, label)

func preparation_timing() -> void:
	for action in ["attract", "tea", "target"]:
		var s := fixture(2)
		s._day.state.phase = &"pre_open"
		check(OpeningPreparation.perform(s._day.state, run_def, catalog, action, "watches" if action == "target" else "").ok, "prepare " + action)
		var prepared := OpeningPreparation.plan(s._day.state, run_def, catalog)
		var record: Dictionary = s._day.state.preparation_history.back()
		var chosen: Dictionary = record.change
		if action == "tea":
			chosen = prepared.filter(func(row: Dictionary) -> bool: return row.night == 2 and OpeningPreparation.ordinary(row))[0]
		var start: int = chosen.arrival
		if action == "tea": start += int(chosen.wait_minutes) - 10
		# Every other visitor has been served; only the prepared visitor remains.
		for row in prepared:
			if row.visit_id != chosen.visit_id: s._day.state.visit_history.append({"visit_id": row.visit_id, "night": row.night, "minute": 0, "outcome": "rejected"})
		s._day.state.sale_batches.append({"id": "test", "night": 2, "start": start, "minute": start + 20, "item_ids": ["test"]})
		s._day.state.sale_records.append({"batch_id": "test", "item_instance_id": "test"})
		check(MarketSaveCodec.validate_timing(s._day.state, run_def, catalog) == "客人仍在店里时不能交货。", "save guard includes " + action)
		s._day.state.visit_history.append({"visit_id": chosen.visit_id, "night": chosen.night, "minute": start, "outcome": "rejected"})
		check(MarketSaveCodec.validate_timing(s._day.state, run_def, catalog).is_empty(), "prepared guest resolved allows sale " + action)

func compatibility() -> void:
	var s := fresh("library17")
	var lib := SaveLibrary.new("res://.godot/qa/market_seven/combined_library.json" if combined else "res://.godot/qa/market_seven/library.json")
	s._save.library = lib
	check(lib.write_entry("manual/1", s._day.state, run_def, catalog.content_version, catalog), "save new opening with initial market")
	var original := FileAccess.get_file_as_string(lib.path)
	var before := s.read_state()
	lib.fail_write = true
	var event := s.event_model()
	check(not s.event_command(event.pending_id, event.buttons[0].detail).ok and before == s.read_state() and original == FileAccess.get_file_as_string(lib.path), "failed save rolls back market and story")
	lib.fail_write = false
	for manifest in ["market_seven_manifest", "familiar_manifest", "familiar_early_manifest", "mirror_chapter_manifest", "preparation_manifest", "integrated_manifest", "seven_night_manifest", "four_night_manifest", "content_manifest"]:
		var old := JsonContentProvider.new("res://data/" + manifest + ".json").load_catalog().catalog
		var definition: RunDefinition = old.get_definition("runs", old.default_run_id)
		var previous := RunSession.new(definition, old.content_version, SaveManager.new("user://tests/old_market17.json"), old)
		check(lib.write_entry("manual/2", previous._day.state, definition, old.content_version, old), "write legacy " + manifest)
		check(lib.adopt(lib.read_entry("manual/2"), s) and s.content_version == old.content_version and s.definition.market == definition.market, "old slot keeps original market rules")
		s.new_run()
		check(s.definition.id == run_def.id and s.content_version == catalog.content_version and s._day.state.market_history.size() == 1, "new game returns to selected content")
