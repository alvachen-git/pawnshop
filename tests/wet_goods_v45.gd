extends "res://tests/special_guests_rules.gd"

var content_version := 46 if "v46" in OS.get_cmdline_user_args() else 45
var manifest := "res://data/special_guests_late_v46_manifest.json" if content_version == 46 else "res://data/special_guests_wet_v45_manifest.json"

func fresh_special(seed_value := 42) -> RunSession:
	var store := FailingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, content_version, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, content_version)
	var restored := codec.decode(payload, run_def, content_version, catalog, true)
	check(restored != null, "cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact replay " + label)

func run() -> void:
	var loaded := JsonContentProvider.new(manifest).load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v45 content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var bootstrap := Bootstrap.new()
	bootstrap.manifest_path = manifest
	bootstrap.save_path = "user://special_guests_v%d/autosave_v%d.json" % [content_version,content_version]
	check(bootstrap.initialize().is_success(),"normal entry initializes")
	check(bootstrap.session._save.library.path == "user://special_guests_v%d/library.json" % content_version,"normal entry has isolated library")
	bootstrap.free()
	boundaries()
	journey()
	print("WET GOODS V%d: %d passes, %d failures" % [content_version, passes, failures])
	quit(0 if failures == 0 else 1)

func boundaries() -> void:
	for nights in range(1,9):
		var s := fresh_special()
		SpecialGuestsPreview.bedroom(s, nights)
		var st := s._day.state
		st.shop_growth.display_id = st.inventory_instances[0].instance_id
		var before := st.to_read_model()
		WetGoodsRisk.warning(st); WetGoodsRisk.item_note(st,st.inventory_instances[0]); s.economy_model()
		check(before == st.to_read_model(), "reading age does not change state")
		check((not WetGoodsRisk.warning(st).is_empty()) == (nights >= 4), "warning before harm")
		check(s.execute("sleep").ok, "sleep with displayed wet goods")
		check(st.personal_damage == (1 if nights >= 5 else 0), "fifth bedtime boundary %d" % nights)
		check((not WetGoodsRisk.bedtime_text(st).is_empty()) == (nights >= 5), "bedtime narration")
		WetGoodsRisk.sleep(st)
		check(st.personal_damage == (1 if nights >= 5 else 0), "same night cannot double charge")
		if nights >= 5:
			PersonalRisk.recover(st, "fixture-heal")
			WetGoodsRisk.sleep(st)
			check(st.personal_damage == 0, "healing does not reset night dedupe")
	for ownership in ["sold", "transferred", "lost"]:
		var s := fresh_special(); SpecialGuestsPreview.bedroom(s,5)
		s._day.state.inventory_instances[0].ownership_state = ownership
		check(WetGoodsRisk.warning(s._day.state).is_empty(), "disposed warning cleared " + ownership)
		check(s.execute("sleep").ok and s._day.state.personal_damage == 0, "disposed goods never harm " + ownership)
	var ordinary := fresh_special(); SpecialGuestsPreview.bedroom(ordinary,5)
	ordinary._day.state.inventory_instances[0].source_visit_id = "ordinary/same-bowl"
	check(ordinary.execute("sleep").ok and ordinary._day.state.personal_damage == 0, "same named ordinary item never harms")
	var old := JsonContentProvider.new("res://data/special_guests_manifest.json").load_catalog().catalog
	var legacy_store := GhostReplayStore.new()
	legacy_store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var legacy := RunSession.new(old.get_definition("runs",old.default_run_id),44,legacy_store,old)
	SpecialGuestsPreview.bedroom(legacy,5)
	check(legacy.execute("sleep").ok and legacy._day.state.personal_damage == 0, "v44 retains harmless rule")

func journey() -> void:
	run_def._initial_cash = 6000
	var s: RunSession
	for seed_value in range(100):
		s = fresh_special(seed_value)
		OpeningPreparation.plan(s._day.state,run_def,catalog)
		if int(SpecialGuests.data(s._day.state).targets.wet) <= 7: break
	var bought := 0
	for n in range(1,19):
		driver.drain(s); act(s,"open_shop"); driver.drain(s)
		for step in 160:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if VarietySaveCodec.selection(s._day.state,v.visit_id).get("special_key") == "wet":
					check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"buy natural wet item")
					bought = n
				else: check(s.counter_command("reject",v.visit_id).ok,"reject other customer")
				driver.drain(s)
			else:
				if not s.bell_model().enabled: break
				s.bell_command("wait"); driver.drain(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
		act(s,"resolve_night"); driver.drain(s); act(s,"enter_room"); driver.drain(s)
		var age_now := n - bought + 1 if bought > 0 else 0
		if age_now >= 4: verify(s,"before sleep %d" % age_now)
		if age_now == 5:
			var before := s.read_state()
			(s._save as FailingStore).fail = true
			check(not s.execute("sleep").ok,"failed save rejects damaging sleep")
			check(s.read_state() == before,"failed sleep rolls back lamp and history")
			(s._save as FailingStore).fail = false
		act(s,"sleep")
		check(s._day.state.personal_damage == clampi(age_now-4,0,4),"daily harm at held night %d" % age_now)
		if age_now >= 4:
			verify(s,"after sleep %d" % age_now)
			var tampered := SaveCodec.new().encode(s._day.state,content_version)
			tampered.personal_damage = 0 if age_now >= 5 else 1
			check(SaveCodec.new().decode(tampered,run_def,content_version,catalog,true) == null,"cannot forge lamp counter")
		if age_now == 5:
			var saves := SaveManager.new("user://tests/wet-v45/replay.json")
			saves.catalog = catalog
			check(saves.save_state(s._day.state,run_def,content_version),"real atomic save " + saves.error_message)
			check(saves.load_state(run_def,content_version) != null,"real save reload " + saves.error_message)
			saves.library = SaveLibrary.new("user://tests/wet-v45/library-" + str(Time.get_ticks_usec()) + ".json")
			saves.library.register_catalog(manifest,catalog)
			check(saves.save_state(s._day.state,run_def,content_version),"isolated library saves damage " + saves.error_message)
			check(saves.load_state(run_def,content_version) != null,"isolated library reloads damage " + saves.error_message)
		if s._day.state.phase == &"dead":
			check(age_now == 8 and s._day.state.personal_death_phase == "sleep_resolution","fourth charge extinguishes bedroom lamp")
			check(s._day.state.death_archive.back().cause.contains("哭声"),"death narration retains pressure and crying")
			return
		driver.drain(s); act(s,"finish_sleep"); driver.drain(s)
		if n < 18: act(s,"continue_run")
	check(false,"journey reaches wet item death")
