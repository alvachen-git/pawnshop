extends "res://tests/tiered_appraisal.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v33 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,33,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,33),run_def,33,catalog,true)
	check(restored != null,"v33 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v33 replay "+label)

func command(s: RunSession, id: String, payload: Dictionary) -> ActionResult:
	return s.fan_command("luxury_watch",id,JSON.stringify(payload))

func seal_stage(s: RunSession, v: CustomerVisit, tier: int, wrong := false) -> void:
	if not WatchAppraisal.handles(s._day.state,v.item): super.seal_stage(s,v,tier,wrong); return
	var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"watch start")
	check(command(s,id,{"op":"wind"}).ok,"wind")
	for pose in ["flat","vertical"]:
		check(command(s,id,{"op":"pose","pose":pose}).ok,"pose")
		check(command(s,id,{"op":"listen","clip":"wound/"+pose}).ok,"complete listening")
	var behavior := WatchAppraisal.profile(s._day.state,v.item)
	if behavior != "stable":
		check(command(s,id,{"op":"mark","clip":"wound/vertical" if behavior == "positional" else "wound/flat","time":3.0 if behavior == "positional" else 5.0}).ok,"audible anomaly mark")
	check(command(s,id,{"op":"open"}).ok,"open case")
	for i in 2:
		var point := WatchAppraisal.spot(v.item,i)
		check(command(s,id,{"op":"inspect","point":[point.x,point.y]}).ok,"actual movement spot")
	var book := LuxuryAppraisalService.info(s._day.state,v.item)
	check(command(s,id,{"op":"draft","identity":"imitation" if wrong else book.identity[v.item.selected_variant_id],"condition":book.condition[v.item.selected_variant_id],"running":behavior}).ok,"three independent findings")
	check(command(s,id,{"op":"seal"}).ok,"seal watch notes")

func run() -> void:
	if not setup(): quit(1); return
	var count := 0
	var behaviors := {}
	for variant in ["sound","mended","flawed"]:
		for damage in ["intact","minor","major"]:
			for hidden in [false,true]:
				for seed_value in 12:
					var s := unit_visit("customer_wealthy_factory",WatchAppraisal.ITEM,variant); equip(s,2)
					s._day.state.run_seed = seed_value*3571
					var v: CustomerVisit = s._day.state.visits[0]; v.item.goods.precision = {"damage":damage,"hidden":hidden}
					var id := v.item.instance_id
					behaviors[WatchAppraisal.profile(s._day.state,v.item)] = true
					check(not s.fan_command("luxury_begin",id,"3").ok,"no deep tier")
					check(s.fan_command("luxury_exterior",id).ok,"basic")
					seal_stage(s,v,2)
					check(s._day.state.game_minutes == 15,"all manipulation and replay free")
					check(TieredAppraisal.correct(s._day.state,v.item,2),"valid cross evidence despite old hidden flag")
					check(not command(s,id,{"op":"draft","identity":"imitation","condition":"altered","running":"unsure"}).ok,"sealed immutable")
					var before := s._day.state.game_minutes
					check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes == before,"reopen free")
					check(s.counter_command("luxury_pressure",v.visit_id).ok,"evidence negotiation")
					var definition := catalog.get_definition("items",WatchAppraisal.ITEM) as ItemDefinition
					check(WealthyCustomers.trade(s._day.state,v).value == TieredAppraisal.adjusted(v.item,definition.find_variant(variant).true_value),"price from used facts once")
					check(v.trade.reserve_price >= WealthyCustomers.trade(s._day.state,v).funding,"funding floor preserved")
					check(not s.counter_command("luxury_pressure",v.visit_id).ok,"no repeated evidence")
					var a := WatchAppraisal.ticks(s._day.state,v.item,"wound/vertical")
					var copy := RunSnapshot.copy(s._day.state)
					check(a == WatchAppraisal.ticks(copy,copy.visits[0].item,"wound/vertical"),"reload same ticks")
					count += 1
	check(behaviors.size() == 3,"all three operational patterns covered")
	var s := unit_visit("customer_wealthy_factory",WatchAppraisal.ITEM,"sound"); equip(s,2)
	var v: CustomerVisit = s._day.state.visits[0]; var id := v.item.instance_id
	MarketService.sync(s._day.state,run_def)
	var baseline := s.read_state(); (s._save as CountingStore).fail = true
	var failure := s.fan_command("luxury_begin",id,"2")
	check(not failure.ok,"begin write reports failure")
	for k in baseline:
		check(baseline[k] == s.read_state()[k],"begin write failure atomic "+str(k))
	(s._save as CountingStore).fail = false; v = s._day.state.visits[0]
	check(s.fan_command("luxury_begin",id,"2").ok,"begin restored")
	baseline = s.read_state(); (s._save as CountingStore).fail = true
	check(not command(s,id,{"op":"wind"}).ok and baseline == s.read_state(),"winding failed-write rollback")
	(s._save as CountingStore).fail = false; v = s._day.state.visits[0]
	check(not command(s,id,{"op":"seal"}).ok,"cannot skip observations")
	check(not command(s,id,{"op":"mark","clip":"wound/flat","time":3}).ok,"cannot mark unheard clip")
	seal_stage(s,v,2,true)
	var patience := v.trade.patience
	check(s.counter_command("luxury_pressure",v.visit_id).ok and v.trade.patience < patience,"wrong identity costs patience")
	s = unit_visit("customer_wealthy_factory",WatchAppraisal.ITEM,"mended"); equip(s,2); v = s._day.state.visits[0]; id = v.item.instance_id
	s._day.state.shop_growth.precision.kits.clear()
	check(not s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes == 0,"missing kit no time")
	check(s.fan_command("luxury_exterior",id).ok,"basic without kit")
	equip(s,2); s._day.state.game_minutes = v.expires_at-10
	var before := s._day.state.game_minutes
	check(not s.fan_command("luxury_begin",id,"2").ok and before == s._day.state.game_minutes,"deadline no charge")
	var old := JsonContentProvider.new("res://data/tiered_manifest.json").load_catalog()
	check(old.is_success(),"v32 still loads")
	var oldrun := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
	check(not oldrun.variety.has("watch_appraisal_version"),"v32 rules not retrofitted")
	check((old.catalog.get_definition("items",WatchAppraisal.ITEM) as ItemDefinition).display_name == "金壳怀表","v32 original item preserved")
	print("WATCH V33: %d combinations, %d passes, %d failures" % [count,passes,failures])
	quit(0 if failures == 0 else 1)
