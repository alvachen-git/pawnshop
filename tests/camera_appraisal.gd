extends "res://tests/pearl_appraisal.gd"

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/camera_manifest.json").load_catalog()
	for issue in loaded.issues:print(issue.format_message())
	check(loaded.is_success(),"v43 catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,43,store,catalog)

func camera(identity:="original",lens:="clear",mechanism:="smooth",damage:="intact",cid:="customer_wealthy_factory",mode:="sell") -> RunSession:
	var s:=unit_visit(cid,CameraEconomy.ITEM,"sound",mode);equip(s,2)
	var v:CustomerVisit=s._day.state.visits[0]
	v.item.goods.precision={"damage":damage,"hidden":false}
	v.item.goods.camera_value={"identity":identity,"lens":lens,"mechanism":mechanism,"fault_at":"both","actual":CameraEconomy.valuation(identity,lens,mechanism,damage)}
	CameraEconomy.prepare(s._day.state,v)
	var o:=CameraEconomy.owner(s._day.state,v);o.belief={"identity":"original","lens":"clear","mechanism":"smooth"};o.rate=100;o.urgent=false
	CameraEconomy.reprice_initial(s._day.state,v);CameraNegotiation.prepare(s._day.state,v);MarketService.sync(s._day.state,run_def)
	return s

func ca(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.fan_command("luxury_camera",s._day.state.visits[0].item.instance_id,JSON.stringify(payload))

func cc(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.counter_command("camera_claim",s._day.state.visits[0].visit_id,JSON.stringify(payload))

func begin(s:RunSession) -> void:
	check(s.fan_command("luxury_begin",s._day.state.visits[0].item.instance_id,"2").ok,"apparatus begins")

func run() -> void:
	if not setup():quit(1);return
	matrix();gates();negotiation_camera();atomic_camera();generation_camera();knowledge_camera()
	print("CAMERA V43: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)

func matrix() -> void:
	for identity in CameraEconomy.BASE:
		for lens in CameraEconomy.LENS:
			for mechanism in CameraEconomy.MECHANISM:
				for damage in TieredAppraisal.RETAIN:
					var s:=camera(identity,lens,mechanism,damage);var v:CustomerVisit=s._day.state.visits[0];var id:=v.item.instance_id
					var fixed:=v.item.goods.duplicate(true)
					check(fixed.camera_value.actual==roundi(float({"original":800,"rebuilt":480,"imitation":120}[identity])*float({"clear":1.0,"haze":.8,"scratched":.65}[lens])*float({"smooth":1.0,"sticky":.8,"stuck":.5}[mechanism])*float({"intact":1.0,"minor":.8,"major":.5}[damage])),"81 independent combinations")
					check(s.counter_model().visual.estimate=="39–800","range does not leak truth")
					check(s.fan_command("luxury_exterior",id).ok,"exterior independent")
					begin(s);ca(s,{"op":"zoom","zoom":true});ca(s,{"op":"zoom","zoom":false})
					ca(s,{"op":"group","group":"lens"});ca(s,{"op":"light","light":"right"})
					ca(s,{"op":"group","group":"aperture"})
					for aperture in ["open","middle","narrow"]:check(ca(s,{"op":"aperture","value":aperture}).ok,"manual aperture")
					ca(s,{"op":"group","group":"shutter"});ca(s,{"op":"shutter"})
					check(CameraNegotiation.strength(s._day.state,v,"mechanism")==1,"unwound test not strong evidence")
					ca(s,{"op":"wind"});ca(s,{"op":"shutter"})
					for part in ["identity","lens","mechanism"]:check(CameraNegotiation.strength(s._day.state,v,part)==2,"persistent independent evidence")
					check(ca(s,{"op":"draft","identity":"imitation","lens":"unsure","mechanism":"unsure"}).ok and ca(s,{"op":"seal"}).ok,"partial note")
					check(not ca(s,{"op":"draft","identity":"original","lens":"clear","mechanism":"smooth"}).ok,"sealed immutable")
					check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes==15,"repeat examination free")
					check(cc(s,{"identity":"rebuilt","lens":"scratched","mechanism":"stuck","exterior":"observed"}).ok,"combined speech")
					check(CameraAppraisal.row(s._day.state,id).identity=="imitation" and not cc(s,{"identity":"original"}).ok,"speech separate / once")
					check(v.item.goods==fixed,"facts fixed after actions lies and price")
					for buyer_id in run_def.buyer_ids:
						var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
						check(s._commerce.base_quote(v.item,buyer)==maxi(1,roundi(fixed.camera_value.actual*buyer.value_multiplier)),"every resale quote uses fixed value")

func gates() -> void:
	for missing in ["bench","knowledge","time"]:
		var s:=camera();var v:CustomerVisit=s._day.state.visits[0]
		if missing=="bench":s._day.state.shop_growth.appraisal.bench_due=0;s._day.state.shop_growth.precision.due=0
		elif missing=="knowledge":s._day.state.shop_growth.knowledge.erase("luxury_textile")
		else:v.expires_at=9
		var before:=s.read_state();check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok and before==s.read_state(),"gated atomically "+missing)
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"no equipment exterior")
	var s:=camera();equip(s,3);begin(s)
	check(ca(s,{"op":"seal"}).ok,"no full check needed")
	check(not s.fan_command("luxury_begin",s._day.state.visits[0].item.instance_id,"3").ok,"no deep entry")
	check(not cc(s,{"exterior":"observed"}).ok,"cannot invent outer damage")

func negotiation_camera() -> void:
	for personality in ["easy","careful","firm"]:
		for urgent in [false,true]:
			var outcomes:=[]
			for split in [false,true]:
				var s:=camera();var v:CustomerVisit=s._day.state.visits[0];var o:=CameraEconomy.owner(s._day.state,v);o.urgent=urgent
				CameraEconomy.reprice_initial(s._day.state,v);CameraNegotiation.prepare(s._day.state,v)
				var n:=CameraNegotiation.data(s._day.state,v);n.personality=personality
				for part in n.rolls:n.rolls[part]=0
				var before:=v.trade.asking_price
				if split:check(cc(s,{"identity":"imitation"}).ok and cc(s,{"lens":"haze","mechanism":"sticky"}).ok,"split claims")
				else:check(cc(s,{"identity":"imitation","lens":"haze","mechanism":"sticky"}).ok,"combined claims")
				check(v.trade.asking_price==before if personality=="firm" and not urgent else v.trade.asking_price<before,"trust versus concession")
				check(n.facts.is_empty() and WealthyCustomers.trade(s._day.state,v).value==800,"lies do not reduce fair price")
				outcomes.append([v.trade.asking_price,v.trade.reserve_price,n.belief,n.rolls])
				var price:=v.trade.asking_price;CameraNegotiation.reprice(s._day.state,v);check(price==v.trade.asking_price,"no cumulative discount")
			check(outcomes[0]==outcomes[1],"order-independent prices and fixed rolls")
	var s:=camera();var v:CustomerVisit=s._day.state.visits[0];var n:=CameraNegotiation.data(s._day.state,v)
	for part in n.rolls:n.rolls[part]=99
	var rep:int=s._day.state.social.reputation
	check(cc(s,{"identity":"imitation"}).ok and s._day.state.social.reputation==rep-2,"caught false accusation")
	check(cc(s,{"mechanism":"stuck"}).ok and s._day.state.social.reputation==rep-2,"penalty once")
	for cid in WealthyCustomers.NAMES:
		s=camera("imitation","haze","stuck","intact",cid,"pawn");v=s._day.state.visits[0]
		n=CameraNegotiation.data(s._day.state,v);n.personality="easy"
		for part in n.rolls:n.rolls[part]=0
		cc(s,{"identity":"imitation","lens":"haze","mechanism":"stuck"})
		var funding:=260 if cid=="customer_wealthy_factory" else 300 if cid=="customer_wealthy_comprador" else 0
		check(WealthyCustomers.trade(s._day.state,v).funding==funding and v.trade.reserve_price>=funding,"holder funding")

func atomic_camera() -> void:
	for payload in [{"op":"wind"},{"op":"shutter"},{"op":"aperture","value":"open"},{"op":"seal"}]:
		var s:=camera();begin(s);var before:=s.read_state();(s._save as CountingStore).fail=true
		check(not ca(s,payload).ok and before==s.read_state(),"save failure rollback "+payload.op)
	var s:=camera();var before:=s.read_state();(s._save as CountingStore).fail=true
	check(not cc(s,{"identity":"imitation"}).ok and before==s.read_state(),"speech save rollback")

func generation_camera() -> void:
	var s:=camera();var item:ItemInstance=s._day.state.visits[0].item;var counts:={"haze":0,"scratched":0,"sticky":0,"stuck":0}
	for seed_value in 2000:
		s._day.state.run_seed=seed_value;item.goods.erase("camera_value");CameraEconomy.attach(s._day.state,item)
		var f:Dictionary=item.goods.camera_value
		if f.lens in counts:counts[f.lens]+=1
		if f.mechanism in counts:counts[f.mechanism]+=1
		var fixed:=item.goods.duplicate(true);CameraEconomy.attach(s._day.state,item);check(item.goods==fixed,"attach once")
	for part in counts:check(absf(counts[part]/2000.0-(.2 if part in ["haze","sticky"] else .1))<.035,"independent distribution "+part)
	var old:=JsonContentProvider.new("res://data/porcelain_release_manifest.json").load_catalog()
	check(not CameraEconomy.enabled(old.catalog.get_definition("runs",old.catalog.default_run_id)),"legacy rules disabled")
	check(old.catalog.get_definition("items",CameraEconomy.ITEM).display_name=="精品绣屏" and catalog.get_definition("items",CameraEconomy.ITEM).display_name=="德国徕卡Ⅰ型相机","new replacement / old embroidery retained")
	for cid in run_def.variety.luxury_carry_weights:check(run_def.variety.luxury_carry_weights[cid][CameraEconomy.ITEM]>0,"all holders may carry")

func knowledge_camera() -> void:
	var s:=camera();s._day.state.phase=&"pre_open";s._day.state.current_night_index=2;s._day.state.visits.clear();s._day.state.shop_growth.knowledge.clear()
	var cash:=s._day.state.cash;var prep:=PreparationService.count(s._day.state)
	check(s.growth_command("learn_knowledge","luxury_textile").ok,"camera guide learning")
	check(s._day.state.cash==cash and PreparationService.count(s._day.state)==prep+1,"once free preparation")
	check(not s.growth_command("learn_knowledge","luxury_textile").ok,"no duplicate learning")
