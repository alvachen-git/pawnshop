extends "res://tests/watch_market_journey.gd"

var watch_claims := 0
func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_negotiation_manifest.json").load_catalog()
	check(loaded.is_success(),"v35 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,35,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,35),run_def,35,catalog,true)
	check(restored != null,"v35 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v35 replay "+label)

func seal_stage(s: RunSession, v: CustomerVisit, tier: int, wrong := false) -> void:
	if not WatchNegotiation.handles(s._day.state,v.item): super.seal_stage(s,v,tier,wrong); return
	var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"start natural watch")
	check(command(s,id,{"op":"listen_start","clip":"arrival/flat"}).ok,"natural unwound click")
	check(command(s,id,{"op":"draft","identity":"original","condition":"unsure","running":"stable"}).ok,"natural partial notes")
	check(command(s,id,{"op":"seal"}).ok,"natural partial seal")
	verify(s,"partial listen and seal")

func negotiate(s: RunSession, v: CustomerVisit) -> void:
	if not WatchNegotiation.handles(s._day.state,v.item): super.negotiate(s,v); return
	var baseline := s.read_state(); (s._save as CountingStore).fail = true
	check(not s.counter_command("watch_claim",v.visit_id,'{"identity":"imitation","running":"stopping"}').ok and s.read_state() == baseline,"natural claim write failure")
	(s._save as CountingStore).fail = false; v = s._counter.customers.active(s._day.state)
	check(s.counter_command("watch_claim",v.visit_id,'{"identity":"imitation","running":"stopping"}').ok,"natural public claims")
	watch_claims += 1
	verify(s,"customer belief and fixed reactions")
	var codec := SaveCodec.new(); InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(codec.encode(s._day.state,35),run_def,35,catalog,true)
	check(restored != null,"cold restore for retry")
	if restored != null:
		var day := DayController.new(run_def,restored)
		check(not WatchNegotiation.reason(day,restored.visits.filter(func(row: CustomerVisit) -> bool: return row.visit_id == v.visit_id)[0],'{"identity":"original"}',0).is_empty(),"reload cannot reset spent claim")

func run() -> void:
	if not setup(): quit(1); return
	journey(609)
	run_def._initial_cash = 2500
	journey(609)
	check(watch_claims > 0,"natural watch transaction covered")
	print("WATCH NEGOTIATION JOURNEY: claims=%d; %d passes, %d failures" % [watch_claims,passes,failures])
	quit(0 if failures == 0 else 1)
