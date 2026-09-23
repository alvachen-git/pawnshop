extends "res://tests/social_v27.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/unified_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "unified social catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,30,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state,30),run_def,30,catalog,true)
	check(restored != null,"unified social replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/unified-social")
	var file := FileAccess.open("res://.godot/qa/unified-social/" + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,30)))

func run() -> void:
	if not setup(): quit(1); return
	price_boundaries()
	military_boundaries()
	coats_rules()
	plaque_rules()
	seeded_coats()
	failed_quote_then_leave()
	reply_feedback()
	story_during_military_night()
	var s := delivery_session()
	verify(s,"natural purchased coats and accepted order")
	var ids: Array = CoatProcurement.stock(s._day.state).slice(0,3).map(func(item: ItemInstance) -> String: return item.instance_id)
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.social_command("deliver",detail_for(s,ids)).ok and before == s.read_state(), "delivery save failure restores inventory cash and relation")
	(s._save as CountingStore).fail = false
	check(s.social_command("deliver",detail_for(s,ids)).ok, "natural unified coat delivery")
	check(s._day.state.social.military == 6 and s._day.state.social.contract.is_empty(), "delivery reward and completed order")
	fixture(s,"delivered")
	check(s.social_command("gift").ok, "gift shares preparation")
	check(s.growth_command("build","bench").ok and PreparationService.count(s._day.state) == 2, "gift and bench share two actions")
	check(not s.execute("prep_tea").ok, "no third preparation")
	for gift_night in [6,9]:
		while s._day.state.current_night_index < gift_night:
			act(s,"open_shop"); finish_night(s); settle_social(s)
		var result := s.social_command("gift")
		check(result.ok,"gift after two quiet nights: " + result.message)
	check(s._day.state.social.plaque_awarded, "natural delivery and gifts award plaque")
	fixture(s,"plaque")
	act(s,"open_shop"); driver.drain(s)
	var v := active_ordinary(s)
	check(v != null and s.counter_command("intimidate",v.visit_id).ok, "natural plaque at counter")
	verify(s,"natural plaque discount")
	var duplicate := SaveCodec.new().encode(s._day.state,30)
	duplicate.action_journal.append({"method":"counter_command","args":["intimidate",v.visit_id,"",0]})
	check(SaveCodec.new().decode(duplicate,run_def,30,catalog,true) == null,"forged duplicate intimidation rejected")
	var data := SaveCodec.new().encode(s._day.state,30)
	data.social.intimidations.clear()
	check(SaveCodec.new().decode(data,run_def,30,catalog,true) == null,"forged plaque use rejected")
	legacy_unchanged()
	print("UNIFIED SOCIAL: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func delivery_session() -> RunSession:
	var picked := 42
	for seed_value in 500:
		var probe := fresh_growth(seed_value)
		var rows := OpeningPreparation.plan(probe._day.state,run_def,catalog)
		if rows.filter(func(r: Dictionary) -> bool: return r.night <= 2 and r.item_id == CoatProcurement.ITEM and "sell" in r.transaction_modes).size() >= 4:
			picked = seed_value; break
	var s := fresh_growth(picked)
	for night in range(1,6):
		driver.drain(s)
		if night >= 2 and CoatProcurement.stock(s._day.state).size() >= 3: break
		act(s,"open_shop"); driver.drain(s)
		for step in 100:
			driver.drain(s)
			var v := CustomerManager.new().active(s._day.state)
			if v != null:
				var modes: Array = catalog.get_definition("customers",v.customer_id).transaction_modes if v.transaction_modes.is_empty() else v.transaction_modes
				if v.item != null and v.item.definition_id in [CoatProcurement.ITEM, "intro_silver_hairpin"] and "sell" in modes:
					check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok, "buy naturally offered coat")
				else: check(s.counter_command("reject",v.visit_id).ok,"pass other goods")
			elif s.bell_model().enabled: s.bell_command("wait")
			else: break
		print("COATS night=",night," stock=",CoatProcurement.stock(s._day.state).size())
		finish_night(s)
	driver.drain(s)
	check(CoatProcurement.stock(s._day.state).size() >= 3,"natural stock contains three coats")
	check(s.social_command("accept_contract").ok,"accept unlimited coat order")
	check(s._day.state.social.contract.due == 0,"latest procurement has no deadline")
	return s

func settle_social(s: RunSession) -> void:
	driver.drain(s)
	if s._day.state.social.pending.get("kind", "") == "supply":
		check(s.social_command("decline_supply").ok,"decline optional military goods before opening")

func story_during_military_night() -> void:
	var s := second_night()
	act(s,"open_shop"); driver.drain(s)
	act(s,"close_shop"); act(s,"wait_until_seal"); act(s,"resolve_night")
	driver.drain(s); act(s,"enter_room"); driver.drain(s)
	SocialRules.night(s._day.state)["military_event"] = true
	check(s.observe_room("aq_coat").ok,"military event does not suppress Aqi room clue")

func finish_night(s: RunSession) -> void:
	driver.drain(s)
	if s._day.state.phase == &"open": act(s,"close_shop")
	if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
	for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id,"keep")
	act(s,"resolve_night"); driver.drain(s)
	act(s,"enter_room"); driver.drain(s)
	act(s,"sleep"); driver.drain(s)
	act(s,"finish_sleep"); act(s,"continue_run")
