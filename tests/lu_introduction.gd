extends "res://tests/shop_growth.gd"

func manifest_path() -> String:
	return "res://data/lu_trade_manifest.json"

func fixture_directory() -> String:
	return "res://.godot/qa/lu-v44/"

func setup() -> bool:
	var loaded := JsonContentProvider.new(manifest_path()).load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v44 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 44, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state, 44), run_def, 44, catalog, true)
	check(restored != null, "v44 cold reload " + label + " " + codec.error_message)
	if restored != null:
		check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact reload " + label)
		s._day.state = restored

func fixture(s: RunSession, label: String) -> void:
	DirAccess.make_dir_recursive_absolute(fixture_directory())
	var file := FileAccess.open(fixture_directory() + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 44)))

func run() -> void:
	if not setup(): quit(1); return
	var seed_value := 42
	for candidate in range(1, 100):
		if MarketService.demand(run_def, MarketService.current(run_def, candidate, 2, 0)).category == "jewelry": seed_value = candidate; break
	var s := fresh_growth(seed_value)
	driver.drain(s)
	check(not LuIntroduction.unlocked(s._day.state, run_def), "no letters before meeting")
	check(not BatchSaleReadModel.build(s._day, s._commerce).buyers.any(func(b: Dictionary) -> bool: return b.id == "buyer_lu"), "buyer hidden before meeting")
	check(MarketService.history_text(s._day).is_empty(), "no first-night demand history")
	act(s, "open_shop"); driver.drain(s)
	var visit := s._counter.customers.active(s._day.state)
	check(s.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "real first-night stock")
	driver.drain(s)
	var item_id: String = s._day.state.inventory_instances[0].instance_id
	var before := s.read_state()
	check(not s.sell_batch("buyer_lu", [item_id]).ok and before == s.read_state(), "direct first-night sale rejected without mutation")
	fixture(s, "first-night")
	finish_night(s)
	check(s._day.state.current_night_index == 2 and s._day.state.phase == &"pre_open", "natural second-night arrival")
	check(MilitaryIntroduction.active(s._day.state), "existing Sun visit retained")
	fixture(s, "sun-arrival")
	check(not s.event_command("lu_visit_greeting", "continue").ok, "cannot answer Lu over current visitor")
	for step in 3:
		fixture(s, "sun-speech-" + str(step))
		check(s.counter_command("military_intro", MilitaryIntroduction.id(s._day.state), str(step)).ok, "Sun introduction " + str(step))
	check(LuIntroduction.active(s._day.state), "Lu arrives after Sun before opening")
	verify(s, "arrival")
	before = s.read_state()
	for command in ["open_shop", "prep_finish", "prep_attract"]:
		check(not s.execute(command).ok and before == s.read_state(), "cannot skip visit " + command)
	check(not s.counter_command("lu_intro", "wrong", "continue").ok, "wrong visitor rejected")
	check(not s.counter_command("lu_intro", "lu_visit_greeting", "continue", 1).ok, "conversation takes no payment")
	check(not s.event_command("lu_visit_letters", "continue").ok, "cannot unlock by skipping dialogue")
	(s._save as CountingStore).fail = true
	check(not s.counter_command("lu_intro", "lu_visit_greeting", "continue").ok and before == s.read_state(), "failed save rolls back speech and unlock")
	(s._save as CountingStore).fail = false
	for index in LuIntroduction.EVENTS.size():
		var id: String = LuIntroduction.EVENTS[index]
		fixture(s, "speech-%d" % index)
		var model := s.counter_model()
		check(model.active_id == id and model.itemless and model.context_actions.item.is_empty(), "itemless Lu introduction")
		check(model.visual.portrait_asset == "fd.lu_elderly" and not LuIntroduction.unlocked(s._day.state, run_def), "elderly identity and locked letters during speech")
		check(s.counter_command("lu_intro", id, "continue").ok, "conversation " + id)
		var after := s.read_state()
		check(not s.counter_command("lu_intro", id, "continue").ok and after == s.read_state(), "no repeated choice " + id)
		verify(s, id)
	check(LuIntroduction.unlocked(s._day.state, run_def) and not LuIntroduction.active(s._day.state), "farewell unlocks letters")
	check(s._day.state.cash == before.cash and s._day.state.game_minutes == before.game_minutes, "introduction free of money and time")
	check(s.read_state().ordinary_selections == before.ordinary_selections, "ordinary customer plan unchanged")
	check(BatchSaleReadModel.build(s._day, s._commerce).buyers.any(func(b: Dictionary) -> bool: return b.id == "buyer_lu"), "buyer visible after introduction")
	fixture(s, "introduced")
	var library := SaveLibrary.new("user://tests/lu-v44/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog(manifest_path(), catalog)
	check(library.write_entry("manual/1", s._day.state, run_def, 44, catalog), "v44 manual save " + library.error_message)
	var saved := library.read_entry("manual/1")
	check(not saved.is_empty() and saved.catalog.content_version == 44 and LuIntroduction.unlocked(saved.state, saved.run), "library loads v44 content and unlock")
	act(s, "open_shop"); driver.drain(s)
	for attempt in 20:
		var active := s._counter.customers.active(s._day.state)
		if active == null: break
		check(s.counter_command("reject", active.visit_id).ok, "clear counter for delivery")
	check(MarketService.category(s._day) == "jewelry", "seeded current demand")
	check(s.sell_batch("buyer_lu", [item_id]).ok, "real sale after meeting follows current demand")
	verify(s, "first Lu sale")
	fixture(s, "letters-open")
	finish_night(s); driver.drain(s)
	check(s._day.state.current_night_index == 3 and not LuIntroduction.active(s._day.state), "visit does not repeat")
	verify(s, "third night")
	var old := JsonContentProvider.new("res://data/porcelain_release_manifest.json").load_catalog()
	check(old.is_success(), "v42 still loads")
	var old_run := old.catalog.get_definition("runs", old.catalog.default_run_id) as RunDefinition
	check(not LuIntroduction.enabled(old_run) and (old.catalog.get_definition("buyers", "buyer_lu") as BuyerDefinition).required_flags.is_empty(), "v42 retains original rules")
	var old_store := CountingStore.new()
	old_store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var old_session := RunSession.new(old_run, 42, old_store, old.catalog)
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(old_session._day.state, 42), old_run, 42, old.catalog, true) != null, "v42 save remains readable")
	check(library.write_entry("manual/2", old_session._day.state, old_run, 42, old.catalog), "v42 slot preserved separately")
	var old_saved := library.read_entry("manual/2")
	check(not old_saved.is_empty() and old_saved.catalog.content_version == 42 and library.read_entry("manual/1").catalog.content_version == 44, "same run identity resolves by saved content version")
	# Both previously playable v43 definitions must resolve by their own run id.
	for manifest in ["res://data/camera_manifest.json", "res://data/lu_introduction_manifest.json"]:
		var historical := JsonContentProvider.new(manifest).load_catalog()
		check(historical.is_success(), "historical v43 catalog " + manifest)
		var historical_run := historical.catalog.get_definition("runs", historical.catalog.default_run_id) as RunDefinition
		var historical_store := CountingStore.new()
		historical_store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
		var historical_session := RunSession.new(historical_run, 43, historical_store, historical.catalog)
		var decoded := SaveLibrary.new().decode_entry({"format": SaveLibrary.FORMAT, "saved_at": "compatibility", "payload": codec.encode(historical_session._day.state, 43)})
		check(not decoded.is_empty() and decoded.run.id == historical_run.id and decoded.catalog.content_version == 43, "historical v43 cold library decode " + manifest)
	print("LU INTRODUCTION: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
