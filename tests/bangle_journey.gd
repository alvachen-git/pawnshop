extends "res://tests/pearl_journey.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/bangle_market_manifest.json").load_catalog()
	check(loaded.is_success(),"v39 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,39,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,39),run_def,39,catalog,true)
	check(restored != null,"v39 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v39 replay "+label)


var bangle_claims:=0
func seal_stage(s: RunSession, v: CustomerVisit, tier: int, wrong := false) -> void:
	if not BangleEconomy.handles(s._day.state,v.item): super.seal_stage(s,v,tier,wrong);return
	var id:=v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"natural bangle apparatus")
	for payload in [{"op":"place"},{"op":"weight","grams":20,"direction":1},{"op":"weight","grams":10,"direction":1},{"op":"select","part":"inner"},{"op":"fire_start"},{"op":"fire_stop"},{"op":"fire_start"},{"op":"fire_finish"},{"op":"wipe"},{"op":"compare"},{"op":"draft","material":"lower","repair":"unsure"},{"op":"seal"}]:
		check(s.fan_command("luxury_bangle",id,JSON.stringify(payload)).ok,"natural bangle action")
	verify(s,"bangle saved partial inspection")

func negotiate(s: RunSession, v: CustomerVisit) -> void:
	if not BangleEconomy.handles(s._day.state,v.item):super.negotiate(s,v);return
	var before:=s.read_state();(s._save as CountingStore).fail=true
	check(not s.counter_command("bangle_claim",v.visit_id,'{"material":"plated","repair":"altered"}').ok and before==s.read_state(),"natural claim disk rollback")
	(s._save as CountingStore).fail=false;v=s._counter.customers.active(s._day.state)
	check(s.counter_command("bangle_claim",v.visit_id,'{"material":"plated","repair":"altered"}').ok,"natural bangle public claims")
	bangle_claims+=1;verify(s,"bangle negotiation")

func run() -> void:
	if not setup():quit(1);return
	var initial:=run_def.initial_cash
	journey(609)
	run_def._initial_cash=2500
	for seed_value in [3,15,17,25,32]:
		journey(seed_value)
		if bangle_claims>0:break
	run_def._initial_cash=initial
	check(bangle_claims>0,"naturally generated bangle cold replay")
	print("BANGLE JOURNEY: bangle=%d pearl=%d watch=%d; %d passes, %d failures" % [bangle_claims,pearl_claims,watch_claims,passes,failures]);quit(0 if failures==0 else 1)
