extends "res://tests/tiered_journey.gd"

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
	print("NATURAL WATCH APPRAISAL ",v.visit_id)
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
