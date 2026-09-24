extends "res://tests/watch_negotiation_journey.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/pearl_market_manifest.json").load_catalog()
	check(loaded.is_success(),"v38 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,38,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,38),run_def,38,catalog,true)
	check(restored != null,"v38 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v38 replay "+label)


var pearl_claims := 0

func seal_stage(s: RunSession, v: CustomerVisit, tier: int, wrong := false) -> void:
	if not PearlEconomy.handles(s._day.state,v.item): super.seal_stage(s,v,tier,wrong); return
	var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"natural pearl apparatus")
	for i in 3: check(s.fan_command("luxury_pearl",id,JSON.stringify({"op":"hole","index":i})).ok,"natural hole")
	check(s.fan_command("luxury_pearl",id,'{"op":"light","index":0,"light":"right"}').ok,"batch light saved")
	for i in [3,4]: check(s.fan_command("luxury_pearl",id,JSON.stringify({"op":"select","index":i,"angle":2,"hole":true})).ok,"batch selection saved")
	check(s.fan_command("luxury_pearl",id,'{"op":"select","index":5,"angle":1,"hole":false}').ok,"batch surface selection saved")
	check(s.fan_command("luxury_pearl",id,'{"op":"compare","index":0,"other":1}').ok,"natural compare")
	check(s.fan_command("luxury_pearl",id,'{"op":"draft","material":"few","repair":"unsure"}').ok,"natural draft")
	check(s.fan_command("luxury_pearl",id,'{"op":"seal"}').ok,"natural seal")
	verify(s,"pearl partial inspection and seal")

func negotiate(s: RunSession, v: CustomerVisit) -> void:
	if WatchNegotiation.handles(s._day.state,v.item):
		check(s.counter_command("watch_claim",v.visit_id,'{"identity":"imitation","running":"stopping"}').ok,"v38 watch claims"); watch_claims += 1
	elif PearlEconomy.handles(s._day.state,v.item):
		var before := s.read_state(); (s._save as CountingStore).fail = true
		check(not s.counter_command("pearl_claim",v.visit_id,'{"material":"all","repair":"altered"}').ok and before==s.read_state(),"production pearl rollback")
		(s._save as CountingStore).fail = false; v=s._counter.customers.active(s._day.state)
		check(s.counter_command("pearl_claim",v.visit_id,'{"material":"all","repair":"altered"}').ok,"production pearl claims"); pearl_claims += 1
	else: check(s.counter_command("luxury_pressure",v.visit_id).ok,"other goods old evidence")
	verify(s,"fixed responses and value after negotiation")

func run() -> void:
	if not setup(): quit(1); return
	journey(609)
	var initial:int=run_def.initial_cash
	run_def._initial_cash = 2500
	for seed_value in [609,222,444,834,1074,2077,3069]:
		journey(seed_value)
		if pearl_claims>0 and watch_claims>0: break
	run_def._initial_cash=initial
	check(pearl_claims>0 and watch_claims>0,"pearl and watch naturally encountered")
	print("PEARL JOURNEY: pearl=%d watch=%d; %d passes, %d failures" % [pearl_claims,watch_claims,passes,failures])
	quit(0 if failures==0 else 1)
