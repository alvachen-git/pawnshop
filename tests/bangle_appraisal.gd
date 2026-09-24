extends "res://tests/pearl_appraisal.gd"

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/bangle_market_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v39 catalog")
	if not loaded.is_success(): return false
	catalog=loaded.catalog; run_def=catalog.get_definition("runs",catalog.default_run_id)
	driver.check=check; driver.catalog=catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new(); store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,39,store,catalog)

func bangle(kind := "fine", repair := "intact", damage := "intact", hidden := false, cid := "customer_wealthy_factory", mode := "sell") -> RunSession:
	var s:=unit_visit(cid,BangleEconomy.ITEM,{"fine":"sound","lower":"mended","plated":"flawed"}[kind],mode); equip(s,2)
	var v:CustomerVisit=s._day.state.visits[0]
	v.item.goods.precision={"damage":damage,"hidden":hidden}; v.item.goods.erase("bangle_value"); BangleEconomy.prepare(s._day.state,v)
	v.item.goods.bangle_value.repair=repair; v.item.goods.bangle_value.actual=BangleEconomy.valuation(kind,repair,damage)
	var o:=BangleEconomy.owner(s._day.state,v); o.belief={"material":"fine","repair":"intact"}; o.rate=100; o.urgent=false
	BangleEconomy.reprice_initial(s._day.state,v); BangleNegotiation.prepare(s._day.state,v)
	MarketService.sync(s._day.state,run_def); return s

func ba(s: RunSession, payload: Dictionary) -> ActionResult:
	return s.fan_command("luxury_bangle",s._day.state.visits[0].item.instance_id,JSON.stringify(payload))

func bc(s: RunSession, payload: Dictionary) -> ActionResult:
	return s.counter_command("bangle_claim",s._day.state.visits[0].visit_id,JSON.stringify(payload))

func inspect(s: RunSession, tier := 2) -> void:
	var v:CustomerVisit=s._day.state.visits[0]; var id:=v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"start apparatus")
	if tier==0:return
	check(ba(s,{"op":"place"}).ok,"place bangle")
	for i in int(v.item.goods.bangle_value.weight): check(ba(s,{"op":"weight","grams":1,"direction":1}).ok,"increment balance")
	check(BangleAppraisal.row(s._day.state,id).measured==v.item.goods.bangle_value.weight,"balanced measured weight")
	check(ba(s,{"op":"select","part":"joint"}).ok,"select joint"); check(ba(s,{"op":"view"}).ok,"view joint")
	if tier==1:return
	check(ba(s,{"op":"select","part":"stamp"}).ok,"select stamp"); check(ba(s,{"op":"view"}).ok,"view stamp")
	for part in ["inner","joint"]:
		check(ba(s,{"op":"select","part":part}).ok,"select fire site")
		check(ba(s,{"op":"fire_start"}).ok,"start fire record")
		check(ba(s,{"op":"fire_stop"}).ok,"stop early")
		check(part not in BangleAppraisal.row(s._day.state,id).finished,"interruption not completed")
		check(ba(s,{"op":"fire_start"}).ok,"restart fire")
		check(ba(s,{"op":"fire_finish"}).ok,"finish fire")
		check(ba(s,{"op":"wipe"}).ok,"wipe")
		check(part in BangleAppraisal.row(s._day.state,id).wiped,"wipe supplies comparison without extra action")

func run() -> void:
	if not setup(): quit(1);return
	matrix(); gates(); negotiation(); atomicity(); generation(); knowledge()
	print("BANGLE V39: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)

func matrix() -> void:
	for kind in ["fine","lower","plated"]:
		for repair in ["intact","altered"]:
			for damage in ["intact","minor","major"]:
				for hidden in [false,true]:
					for weight in BangleEconomy.WEIGHTS[kind]:
						var s:=bangle(kind,repair,damage,hidden);var v:CustomerVisit=s._day.state.visits[0];var id:=v.item.instance_id
						v.item.goods.bangle_value.weight=weight;var facts:=v.item.goods.duplicate(true)
						check(facts.bangle_value.actual==maxi(1,roundi(float({"fine":440,"lower":330,"plated":70}[kind])*(.85 if repair=="altered" else 1.0)*float({"intact":1.0,"minor":.8,"major":.5}[damage]))),"36 conditions independent value")
						check(s.counter_model().visual.estimate=="70–440","initial public range")
						check(s.fan_command("luxury_exterior",id).ok,"exterior")
						inspect(s)
						var record:=BangleAppraisal.row(s._day.state,id)
						for part in BangleAppraisal.PARTS:
							ba(s,{"op":"select","part":part});ba(s,{"op":"turn","angle":int(facts.bangle_value.angles[part])})
							check(BangleAppraisal.visible_detail(v.item,record),"every hidden clue accessible")
						check(BangleNegotiation.strength(s._day.state,v,"material")==2 and BangleNegotiation.strength(s._day.state,v,"repair")==2,"strong checks distinct")
						check(ba(s,{"op":"draft","material":"plated","repair":"unsure"}).ok and ba(s,{"op":"seal"}).ok,"partial private note")
						check(not ba(s,{"op":"draft","material":"fine","repair":"intact"}).ok,"sealed note immutable")
						check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes==15,"revisit free")
						check(bc(s,{"material":"lower","repair":"altered","exterior":"observed"}).ok,"combined public claims")
						check(record.material=="plated","speech does not overwrite note")
						check(not bc(s,{"material":"fine"}).ok,"issue once")
						check(v.item.goods==facts,"all actions keep fixed facts")
						for buyer_id in run_def.buyer_ids:
							var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
							check(s._commerce.base_quote(v.item,buyer)==maxi(1,roundi(facts.bangle_value.actual*buyer.value_multiplier)),"sale uses fixed value")

func gates() -> void:
	for missing in ["bench","kit","knowledge","time"]:
		var s:=bangle();var v:CustomerVisit=s._day.state.visits[0]
		if missing=="bench":
			s._day.state.shop_growth.appraisal.bench_due=0; s._day.state.shop_growth.precision.due=0
		elif missing=="kit":s._day.state.shop_growth.precision.kits=[]
		elif missing=="knowledge":s._day.state.shop_growth.knowledge.erase("luxury_metal")
		else:v.expires_at=9
		var before:=s.read_state()
		check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok and before==s.read_state(),"gate rollback "+missing)
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"basic without apparatus "+missing)
	var s:=bangle();var v:CustomerVisit=s._day.state.visits[0];equip(s,3)
	check(s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"tier3 inherits")
	check(not s.fan_command("luxury_begin",v.item.instance_id,"3").ok,"no deep action")
	check(ba(s,{"op":"seal"}).ok,"empty partial seal allowed")

func negotiation() -> void:
	for skill_index in 3:
		for tier in 3:
			for truthful in [true,false]:
				var s:=bangle();inspect(s,tier);var v:CustomerVisit=s._day.state.visits[0]
				BangleEconomy.owner(s._day.state,v).skill=["expert","ordinary","novice"][skill_index]
				for part in ["material","repair"]:
					var word:String=("fine" if truthful else "plated") if part=="material" else ("intact" if truthful else "altered")
					check(BangleNegotiation.chance(s._day.state,v,part,word)==(WatchNegotiation.TRUE_CHANCES if truthful else WatchNegotiation.FALSE_CHANCES)[tier][skill_index],"belief probabilities")
	for urgent in [false,true]:
		for personality in ["easy","careful","firm"]:
			var results:=[]
			for split in [false,true]:
				var s:=bangle();var v:CustomerVisit=s._day.state.visits[0];BangleEconomy.owner(s._day.state,v).urgent=urgent;BangleEconomy.reprice_initial(s._day.state,v);BangleNegotiation.prepare(s._day.state,v)
				var n:=BangleNegotiation.data(s._day.state,v);n.personality=personality;n.rolls.material=0;n.rolls.repair=0
				var initial:=v.trade.asking_price;var actual:int=v.item.goods.bangle_value.actual
				if split:check(bc(s,{"material":"plated"}).ok and bc(s,{"repair":"altered"}).ok,"separate claims")
				else:check(bc(s,{"material":"plated","repair":"altered"}).ok,"grouped claims")
				check(v.trade.asking_price==initial if personality=="firm" and not urgent else v.trade.asking_price<initial,"personality concession")
				check(v.item.goods.bangle_value.actual==actual and n.facts.is_empty(),"believed lie not true evidence")
				results.append([v.trade.asking_price,v.trade.reserve_price,n.belief,n.rolls])
				var ask:=v.trade.asking_price;BangleNegotiation.reprice(s._day.state,v);check(ask==v.trade.asking_price,"idempotent reprice")
			check(results[0]==results[1],"group and order independent")
	var s:=bangle();var v:CustomerVisit=s._day.state.visits[0];var n:=BangleNegotiation.data(s._day.state,v);n.rolls.material=99;n.rolls.repair=99
	var rep:int=s._day.state.social.reputation
	check(bc(s,{"material":"plated"}).ok,"false claim rejected")
	var after:int=s._day.state.social.reputation
	check(after==rep-2,"identified false accusation penalty")
	check(bc(s,{"repair":"altered"}).ok and s._day.state.social.reputation==after,"penalty once")
	for cid in WealthyCustomers.NAMES:
		for mode in ["sell","pawn"]:
			var holder:=bangle("plated","altered","major",false,cid,mode);var visit:CustomerVisit=holder._day.state.visits[0]
			var d:=BangleNegotiation.data(holder._day.state,visit);d.personality="easy";d.rolls.material=0;d.rolls.repair=0
			check(bc(holder,{"material":"plated","repair":"altered"}).ok,"holder accepts")
			var funding:int=WealthyCustomers.trade(holder._day.state,visit).funding
			check(funding==0 if mode=="sell" else funding==roundi(220*float(run_def.variety.luxury.profiles[cid].funding_percent)/100),"holder funding")
			check(visit.trade.reserve_price>=funding,"funding cannot be waived")

func atomicity() -> void:
	for operation in ["begin","weight","fire_start","fire_finish","wipe","seal","claim"]:
		var s:=bangle();var v:CustomerVisit=s._day.state.visits[0]
		if operation!="begin":s.fan_command("luxury_begin",v.item.instance_id,"2")
		if operation in ["fire_finish","wipe"]:ba(s,{"op":"fire_start"})
		if operation=="wipe":ba(s,{"op":"fire_finish"})
		var before:=s.read_state();(s._save as CountingStore).fail=true
		var result:ActionResult
		if operation=="begin":result=s.fan_command("luxury_begin",v.item.instance_id,"2")
		elif operation=="claim":result=bc(s,{"material":"plated"})
		else:result=ba(s,{"op":"weight","grams":10,"direction":1} if operation=="weight" else {"op":operation})
		check(not result.ok and before==s.read_state(),"disk rollback "+operation)
	var s:=bangle();inspect(s)
	for payload in [{"op":"weight","grams":3,"direction":1},{"op":"weight","grams":20,"direction":-1},{"op":"select","part":"bad"},{"op":"turn","angle":4},{"op":"fire_finish"}]:
		var before:=s.read_state();check(not ba(s,payload).ok and before==s.read_state(),"invalid action atomic")

func generation() -> void:
	var repair_count:=0;var seen:={}
	for seed_value in 1000:
		var state:=RunState.create(run_def);state.ghost_catalog=catalog;state.run_seed=seed_value
		for variant in ["sound","mended","flawed"]:
			var item:=ItemInstance.new();item.definition_id=BangleEconomy.ITEM;item.instance_id="bangle/sample";item.selected_variant_id=variant
			TieredAppraisal.attach(state,item,"bangle/sample");BangleEconomy.attach(state,item)
			var facts:=item.goods.duplicate(true);BangleEconomy.attach(state,item)
			check(item.goods==facts,"attach idempotent")
			seen[facts.bangle_value.material+str(facts.bangle_value.weight)]=true
			if variant=="sound" and facts.bangle_value.repair=="altered":repair_count+=1
	check(seen.size()==9 and repair_count>200 and repair_count<300,"all weights and independent repair distribution")
	var old:=JsonContentProvider.new("res://data/pearl_market_manifest.json").load_catalog()
	var state:=RunState.create(old.catalog.get_definition("runs",old.catalog.default_run_id));state.ghost_catalog=old.catalog
	var item:=ItemInstance.new();item.definition_id=BangleEconomy.ITEM;item.selected_variant_id="sound"
	BangleEconomy.attach(state,item);check(not item.goods.has("bangle_value"),"v38 has no new facts")
	check(old.catalog.get_definition("items",BangleEconomy.ITEM).display_name=="赤金手镯","v38 name unchanged")

func knowledge() -> void:
	var s:=second_night()
	var cash:=s._day.state.cash
	check(s.growth_command("learn_knowledge","luxury_metal").ok,"learn metal")
	check(s._day.state.cash==cash and ShopKnowledgeService.preparation_count(s._day.state)==1,"study once free")
	check(not s.growth_command("learn_knowledge","luxury_metal").ok and ShopKnowledgeService.preparation_count(s._day.state)==1,"no double study")
