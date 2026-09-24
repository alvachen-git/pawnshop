extends "res://tests/bangle_journey.gd"

var porcelain_claims:=0

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/porcelain_manifest.json").load_catalog()
	check(loaded.is_success(),"v41 catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,41,store,catalog)

func verify(s:RunSession,label:String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec:=SaveCodec.new();var restored:=codec.decode(codec.encode(s._day.state,41),run_def,41,catalog,true)
	check(restored!=null,"v41 cold replay "+label+" "+codec.error_message)
	if restored!=null:check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v41 replay "+label)

func seal_stage(s:RunSession,v:CustomerVisit,tier:int,wrong:=false) -> void:
	if not PorcelainEconomy.handles(s._day.state,v.item):super.seal_stage(s,v,tier,wrong);return
	var id:=v.item.instance_id;var facts:=v.item.goods.duplicate(true)
	check(s.fan_command("luxury_begin",id,"2").ok,"natural porcelain apparatus")
	for p in [{"op":"light","light":"right"},{"op":"group","group":"painting"},{"op":"zoom","zoom":true},{"op":"reference","era":"republic"},{"op":"sample","sample":1},{"op":"turn","angle":2},{"op":"draft","era":"qing","craft":"unsure"},{"op":"seal"}]:
		check(s.fan_command("luxury_porcelain",id,JSON.stringify(p)).ok,"natural free observation and partial notes")
	check(v.item.goods==facts,"fixed specimen after notes")
	verify(s,"porcelain partial notes")

func negotiate(s:RunSession,v:CustomerVisit) -> void:
	if not PorcelainEconomy.handles(s._day.state,v.item):super.negotiate(s,v);return
	var before:=s.read_state();(s._save as CountingStore).fail=true
	check(not s.counter_command("porcelain_claim",v.visit_id,'{"era":"republic","craft":"rough"}').ok and before==s.read_state(),"natural failed-write claim rollback")
	(s._save as CountingStore).fail=false;v=s._counter.customers.active(s._day.state)
	check(s.counter_command("porcelain_claim",v.visit_id,'{"era":"republic","craft":"rough"}').ok,"natural porcelain claims")
	porcelain_claims+=1;verify(s,"porcelain customer response")
	var codec:=SaveCodec.new();InvestigationSaveCodec.clear_cache();var restored:=codec.decode(codec.encode(s._day.state,41),run_def,41,catalog,true)
	check(restored!=null,"reload spent claim")
	if restored!=null:
		var old:CustomerVisit=restored.visits.filter(func(x:CustomerVisit)->bool:return x.visit_id==v.visit_id)[0]
		check(not PorcelainNegotiation.reason(DayController.new(run_def,restored),old,'{"era":"ming"}',0).is_empty(),"reload cannot retry issue")

func run() -> void:
	if not setup():quit(1);return
	journey(609)
	var initial:=run_def.initial_cash;run_def._initial_cash=2500
	for seed_value in [3,15,17,25,32,222,444,834,1074]:
		journey(seed_value)
		if porcelain_claims>0:break
	run_def._initial_cash=initial
	check(porcelain_claims>0,"naturally generated porcelain appraisal / claim / cold replay")
	print("PORCELAIN JOURNEY: porcelain=%d; %d passes, %d failures" % [porcelain_claims,passes,failures]);quit(0 if failures==0 else 1)
