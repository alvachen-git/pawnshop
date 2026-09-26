extends "res://tests/special_guests_rules.gd"

func fresh_special(seed_value := 42) -> RunSession:
	var store := FailingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,47,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state,47),run_def,47,catalog,true)
	check(restored != null,"cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/medicine_huaian_v47_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v47 content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var b := Bootstrap.new(); b.manifest_path = "res://data/medicine_huaian_v47_manifest.json"
	b.save_path = "user://medicine_huaian_v47/autosave_v47.json"
	check(b.initialize().is_success(),"bootstrap")
	check(b.session._save.library.path == "user://medicine_huaian_v47/library.json","independent save library")
	b.free()
	var generated := {}
	for seed_value in 32:
		var s := fresh_special(seed_value)
		for n in MedicineStory.NIGHTS:
			s._day.state.current_night_index = n
			var rows := OpeningPreparation.plan(s._day.state,run_def,catalog)
			var visits := rows.filter(func(row: Dictionary) -> bool: return row.night == n and row.has("medicine_stage"))
			check(visits.size() == 1,"exactly one protected appointment")
			if visits.is_empty(): continue
			generated[visits[0].item_id] = true
			check(visits[0].item_id in MedicineStory.pool(run_def,catalog),"ordinary goods only")
			check(not SpecialGuests.available(s._day.state,visits[0]),"special guests cannot replace medicine visits")
			var snapshot := s.read_state()
			check(rows == OpeningPreparation.plan(s._day.state,run_def,catalog) and snapshot == s.read_state(),"seeded plan read-only")
	check(generated.size() >= 10,"ordinary assortment sampled " + str(generated.size()))
	run_def._initial_cash = 6000
	for mode in ["early","exact","short","refused","partial"]:
		journey(mode)
		if failures: break
	print("MEDICINE V47: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func talk(s: RunSession) -> void:
	var model := MedicineStory.dialogue(s._day.state)
	if not model.is_empty(): check(s.execute("medicine_talk",model.key).ok,"finish RPG conversation")

func journey(mode: String) -> void:
	var s := fresh_special(42)
	var seen: Array = []
	for n in range(1,20):
		driver.drain(s); talk(s); act(s,"open_shop"); driver.drain(s)
		for step in 200:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.customer_id == MedicineStory.CUSTOMER:
					seen.append(n)
					check(v.person.name == MedicineStory.NAME,"fixed identity")
					if n == 19 and mode != "early": check(v.trade.asking_price == 200-MedicineStory.funds(s._day.state),"final ask equals missing amount")
					if n in [3,19]: verify(s,mode+" before talk"+str(n))
					var model := MedicineStory.dialogue(s._day.state)
					check(not model.is_empty(),"visit begins in RPG dialogue")
					var snapshot := s.read_state()
					(s._save as FailingStore).fail = true
					check(not s.execute("medicine_talk",model.key).ok and snapshot == s.read_state(),"failed dialogue save rollback")
					(s._save as FailingStore).fail = false
					talk(s)
					v = s._counter.customers.active(s._day.state)
					if mode == "early" and n > 3:
						check(v == null or v.customer_id != MedicineStory.CUSTOMER,"funded return has no sale")
						continue
					if (mode in ["early","partial"] and n == 3) or (n == 19 and mode in ["exact","short","partial"]):
						var prior := MedicineStory.funds(s._day.state)
						var amount := (maxi(60,v.trade.reserve_price) if n == 3 else 200-prior) if mode == "partial" else 199 if mode == "short" else 200
						snapshot = s.read_state()
						(s._save as FailingStore).fail = true
						check(not s.counter_command("offer",v.visit_id,"",amount).ok and snapshot == s.read_state(),"failed payment rollback")
						(s._save as FailingStore).fail = false
						v = s._counter.customers.active(s._day.state)
						check(s.counter_command("offer",v.visit_id,"",amount).ok,"medicine purchase")
						check(MedicineStory.funds(s._day.state) == prior + amount,"only paid silver counts")
						verify(s,mode+" purchase")
					else: check(s.counter_command("reject",v.visit_id).ok,"rejection does not cancel future appointments")
				else: s.counter_command("reject",v.visit_id)
				driver.drain(s)
			else:
				if not s.bell_model().enabled: break
				s.bell_command("wait"); driver.drain(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
		act(s,"resolve_night"); driver.drain(s); act(s,"enter_room"); driver.drain(s)
		act(s,"sleep"); driver.drain(s); act(s,"finish_sleep"); driver.drain(s)
		act(s,"continue_run")
		if failures: return
	driver.drain(s)
	check(seen == [3,9,18,19],"four appearances "+str(seen))
	check(s._day.state.current_night_index == 20,"reaches twentieth night")
	var model := MedicineStory.dialogue(s._day.state)
	check(not model.is_empty(),"ending pending")
	if model.is_empty(): return
	var saved := mode in ["early","exact","partial"]
	check(model.speaker == (MedicineStory.NAME if saved else "周婶"),"only neighbor delivers death news")
	check(("没熬过去" in model.text) == not saved,"correct ending")
	check(s.counter_model().visual.customer_id == (MedicineStory.CUSTOMER if saved else "intro_neighbor"),"correct ending portrait")
	verify(s,mode+" ending pending")
	if mode == "partial":
		var saves := SaveManager.new("user://tests/medicine-v47/replay.json")
		saves.catalog = catalog
		check(saves.save_state(s._day.state,run_def,47),"real save writes ending checkpoint")
		check(saves.load_state(run_def,47) != null,"real checkpoint reload")
		saves.library = SaveLibrary.new("user://tests/medicine-v47/library-"+str(Time.get_ticks_usec())+".json")
		saves.library.register_catalog("res://data/medicine_huaian_v47_manifest.json",catalog)
		check(saves.save_state(s._day.state,run_def,47),"library writes new content")
		check(saves.load_state(run_def,47) != null,"library restores new content")
		var forged := SaveCodec.new().encode(s._day.state,47)
		forged.narrative_flags.append(MedicineStory.ENDING)
		check(SaveCodec.new().decode(forged,run_def,47,catalog,true) == null,"cannot forge heard ending")
	var before_ending := s.read_state()
	(s._save as FailingStore).fail = true
	check(not s.execute("medicine_talk",model.key).ok and before_ending == s.read_state(),"ending save failure leaves conversation pending")
	(s._save as FailingStore).fail = false
	talk(s); verify(s,mode+" ending heard")
	check(MedicineStory.dialogue(s._day.state).is_empty(),"ending not repeated")
	check(("medicine/mother_saved" in s._day.state.narrative_flags) == saved,"outcome recorded")
