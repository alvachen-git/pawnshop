extends "res://tests/porcelain_journey.gd"

var camera_claims:=0

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/camera_manifest.json").load_catalog()
	check(loaded.is_success(),"v43 catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,43,store,catalog)

func verify(s:RunSession,label:String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec:=SaveCodec.new();var restored:=codec.decode(codec.encode(s._day.state,43),run_def,43,catalog,true)
	check(restored!=null,"v43 cold replay "+label+" "+codec.error_message)
	if restored!=null:check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay "+label)

func seal_stage(s:RunSession,v:CustomerVisit,tier:int,wrong:=false) -> void:
	if not CameraEconomy.handles(s._day.state,v.item):super.seal_stage(s,v,tier,wrong);return
	var id:=v.item.instance_id;var fixed:=v.item.goods.duplicate(true)
	check(s.fan_command("luxury_begin",id,"2").ok,"natural camera apparatus")
	for p in [{"op":"group","group":"lens"},{"op":"light","light":"right"},{"op":"aperture","value":"open"},{"op":"wind"},{"op":"shutter"},{"op":"draft","identity":"unsure","lens":"haze","mechanism":"unsure"},{"op":"seal"}]:
		check(s.fan_command("luxury_camera",id,JSON.stringify(p)).ok,"natural camera action")
	check(v.item.goods==fixed,"fixed facts after notes");verify(s,"camera notes and shutter")

func negotiate(s:RunSession,v:CustomerVisit) -> void:
	if not CameraEconomy.handles(s._day.state,v.item):super.negotiate(s,v);return
	var before:=s.read_state();(s._save as CountingStore).fail=true
	check(not s.counter_command("camera_claim",v.visit_id,'{"identity":"imitation","lens":"haze"}').ok and before==s.read_state(),"natural rollback")
	(s._save as CountingStore).fail=false;v=s._counter.customers.active(s._day.state)
	check(s.counter_command("camera_claim",v.visit_id,'{"identity":"imitation","lens":"haze"}').ok,"natural camera speech")
	camera_claims+=1;verify(s,"camera fixed responses")

func run() -> void:
	if not setup():quit(1);return
	var initial:=run_def.initial_cash;run_def._initial_cash=2500
	for seed_value in [3,15,17,25,32,222,444,834,1074,609]:
		journey(seed_value)
		if camera_claims>0:break
	run_def._initial_cash=initial
	check(camera_claims>0,"natural camera / saved actions / cold replay")
	print("CAMERA JOURNEY: camera=%d; %d passes, %d failures" % [camera_claims,passes,failures]);quit(0 if failures==0 else 1)
