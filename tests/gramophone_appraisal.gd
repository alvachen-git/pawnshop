extends "res://tests/pearl_appraisal.gd"

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/gramophone_manifest.json").load_catalog()
	for issue in loaded.issues:print(issue.format_message())
	check(loaded.is_success(),"v44 catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,44,store,catalog)

func gramophone(identity:="original",sound:="clear",motor:="steady",damage:="intact",cid:="customer_wealthy_factory",mode:="sell") -> RunSession:
	var s:=unit_visit(cid,GramophoneEconomy.ITEM,"sound",mode);equip(s,2)
	var v:CustomerVisit=s._day.state.visits[0]
	v.item.goods.precision={"damage":damage,"hidden":false}
	v.item.goods.gramophone_value={"identity":identity,"sound":sound,"motor":motor,"initial_wound":false,"record_worn":false,"engraving":"standard","actual":GramophoneEconomy.valuation(identity,sound,motor,damage)}
	GramophoneEconomy.prepare(s._day.state,v)
	var o:=GramophoneEconomy.owner(s._day.state,v);o.belief={"identity":"original","sound":"clear","motor":"steady"};o.rate=100;o.urgent=false
	GramophoneEconomy.reprice_initial(s._day.state,v);GramophoneNegotiation.prepare(s._day.state,v);MarketService.sync(s._day.state,run_def)
	return s

func ca(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.fan_command("luxury_gramophone",s._day.state.visits[0].item.instance_id,JSON.stringify(payload))

func cc(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.counter_command("gramophone_claim",s._day.state.visits[0].visit_id,JSON.stringify(payload))

func begin(s:RunSession) -> void:
	check(s.fan_command("luxury_begin",s._day.state.visits[0].item.instance_id,"2").ok,"apparatus begins")

func run() -> void:
	if not setup():quit(1);return
	matrix();gates();negotiation_gramophone();atomic_gramophone();generation_gramophone();knowledge_gramophone()
	print("GRAMOPHONE V44: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)

func matrix() -> void:
	for identity in GramophoneEconomy.BASE:
		for sound in GramophoneEconomy.SOUND:
			for motor in GramophoneEconomy.MOTOR:
				for damage in TieredAppraisal.RETAIN:
					var s:=gramophone(identity,sound,motor,damage);var v:CustomerVisit=s._day.state.visits[0];var id:=v.item.instance_id
					var fixed:=v.item.goods.duplicate(true)
					check(fixed.gramophone_value.actual==roundi(float({"original":700,"rebuilt":420,"imitation":100}[identity])*float({"clear":1.0,"rasping":.8,"muffled":.65}[sound])*float({"steady":1.0,"wavering":.8,"stopping":.5}[motor])*float({"intact":1.0,"minor":.8,"major":.5}[damage])),"81 independent combinations")
					check(s.counter_model().visual.estimate=="33–700","range does not leak truth")
					check(s.fan_command("luxury_exterior",id).ok,"exterior independent")
					begin(s);ca(s,{"op":"zoom","zoom":true});ca(s,{"op":"zoom","zoom":false})
					ca(s,{"op":"group","group":"soundbox"});ca(s,{"op":"group","group":"playback"})
					ca(s,{"op":"listen"});ca(s,{"op":"stop"})
					check(GramophoneAppraisal.row(s._day.state,id).tests.size()==1,"click then stop records immediately")
					check(GramophoneNegotiation.strength(s._day.state,v,"motor")==0,"unwound evidence weak")
					ca(s,{"op":"wind"});ca(s,{"op":"listen"});ca(s,{"op":"record","value":"reference"});ca(s,{"op":"listen"})
					ca(s,{"op":"speed","value":"slow"});ca(s,{"op":"speed","value":"nominal"})
					for part in ["identity","sound","motor"]:check(GramophoneNegotiation.strength(s._day.state,v,part)==2,"independent operational evidence")
					check(ca(s,{"op":"draft","identity":"imitation","sound":"unsure","motor":"unsure"}).ok and ca(s,{"op":"seal"}).ok,"partial note")
					check(not ca(s,{"op":"draft","identity":"original","sound":"clear","motor":"steady"}).ok,"sealed immutable")
					check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes==15,"repeat examination free")
					check(cc(s,{"identity":"rebuilt","sound":"muffled","motor":"stopping","exterior":"observed"}).ok,"combined speech")
					check(GramophoneAppraisal.row(s._day.state,id).identity=="imitation" and not cc(s,{"identity":"original"}).ok,"speech separate / once")
					check(v.item.goods==fixed,"facts fixed after actions lies and price")
					for buyer_id in run_def.buyer_ids:
						var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
						check(s._commerce.base_quote(v.item,buyer)==maxi(1,roundi(fixed.gramophone_value.actual*buyer.value_multiplier)),"every resale quote uses fixed value")

func gates() -> void:
	for missing in ["bench","knowledge","time"]:
		var s:=gramophone();var v:CustomerVisit=s._day.state.visits[0]
		if missing=="bench":s._day.state.shop_growth.appraisal.bench_due=0;s._day.state.shop_growth.precision.due=0
		elif missing=="knowledge":s._day.state.shop_growth.knowledge.erase("luxury_watch")
		else:v.expires_at=9
		var before:=s.read_state();check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok and before==s.read_state(),"gated atomically "+missing)
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"no equipment exterior")
	var s:=gramophone();equip(s,3);begin(s)
	check(ca(s,{"op":"seal"}).ok,"no full check needed")
	check(not s.fan_command("luxury_begin",s._day.state.visits[0].item.instance_id,"3").ok,"no deep entry")
	check(not cc(s,{"exterior":"observed"}).ok,"cannot invent outer damage")

func negotiation_gramophone() -> void:
	for personality in ["easy","careful","firm"]:
		for urgent in [false,true]:
			var outcomes:=[]
			for split in [false,true]:
				var s:=gramophone();var v:CustomerVisit=s._day.state.visits[0];var o:=GramophoneEconomy.owner(s._day.state,v);o.urgent=urgent
				GramophoneEconomy.reprice_initial(s._day.state,v);GramophoneNegotiation.prepare(s._day.state,v)
				var n:=GramophoneNegotiation.data(s._day.state,v);n.personality=personality
				for part in n.rolls:n.rolls[part]=0
				var before:=v.trade.asking_price
				begin(s);ca(s,{"op":"listen"})
				if split:check(cc(s,{"identity":"imitation"}).ok and cc(s,{"sound":"rasping","motor":"wavering"}).ok,"split claims")
				else:check(cc(s,{"identity":"imitation","sound":"rasping","motor":"wavering"}).ok,"combined claims")
				check(v.trade.asking_price==before if personality=="firm" and not urgent else v.trade.asking_price<before,"trust versus concession")
				check(n.facts.is_empty() and WealthyCustomers.trade(s._day.state,v).value==700,"lies do not reduce fair price")
				outcomes.append([v.trade.asking_price,v.trade.reserve_price,n.belief,n.rolls])
				var price:=v.trade.asking_price;GramophoneNegotiation.reprice(s._day.state,v);check(price==v.trade.asking_price,"no cumulative discount")
			check(outcomes[0]==outcomes[1],"order-independent prices and fixed rolls")
	var s:=gramophone();var v:CustomerVisit=s._day.state.visits[0];var n:=GramophoneNegotiation.data(s._day.state,v)
	for part in n.rolls:n.rolls[part]=99
	begin(s);ca(s,{"op":"listen"})
	var rep:int=s._day.state.social.reputation
	check(cc(s,{"identity":"imitation"}).ok and s._day.state.social.reputation==rep-2,"caught false accusation")
	check(cc(s,{"motor":"stopping"}).ok and s._day.state.social.reputation==rep-2,"penalty once")
	for cid in WealthyCustomers.NAMES:
		s=gramophone("imitation","rasping","stopping","intact",cid,"pawn");v=s._day.state.visits[0]
		n=GramophoneNegotiation.data(s._day.state,v);n.personality="easy"
		for part in n.rolls:n.rolls[part]=0
		begin(s);ca(s,{"op":"listen"})
		cc(s,{"identity":"imitation","sound":"rasping","motor":"stopping"})
		var funding:=228 if cid=="customer_wealthy_factory" else 263 if cid=="customer_wealthy_comprador" else 0
		check(WealthyCustomers.trade(s._day.state,v).funding==funding and v.trade.reserve_price>=funding,"holder funding")

func atomic_gramophone() -> void:
	for payload in [{"op":"wind"},{"op":"listen"},{"op":"record","value":"reference"},{"op":"seal"}]:
		var s:=gramophone();begin(s);var before:=s.read_state();(s._save as CountingStore).fail=true
		check(not ca(s,payload).ok and before==s.read_state(),"save failure rollback "+payload.op)
	var s:=gramophone();var before:=s.read_state();(s._save as CountingStore).fail=true
	check(not cc(s,{"identity":"imitation"}).ok and before==s.read_state(),"speech save rollback")

func generation_gramophone() -> void:
	var s:=gramophone();var item:ItemInstance=s._day.state.visits[0].item;var counts:={"rasping":0,"muffled":0,"wavering":0,"stopping":0}
	for seed_value in 2000:
		s._day.state.run_seed=seed_value;item.goods.erase("gramophone_value");GramophoneEconomy.attach(s._day.state,item)
		var f:Dictionary=item.goods.gramophone_value
		if f.sound in counts:counts[f.sound]+=1
		if f.motor in counts:counts[f.motor]+=1
		var fixed:=item.goods.duplicate(true);GramophoneEconomy.attach(s._day.state,item);check(item.goods==fixed,"attach once")
	for part in counts:check(absf(counts[part]/2000.0-(.2 if part in ["rasping","wavering"] else .1))<.035,"independent distribution "+part)
	var old:=JsonContentProvider.new("res://data/camera_manifest.json").load_catalog()
	check(not GramophoneEconomy.enabled(old.catalog.get_definition("runs",old.catalog.default_run_id)),"legacy rules disabled")
	check(old.catalog.get_definition("items",GramophoneEconomy.ITEM).display_name=="进口座钟" and catalog.get_definition("items",GramophoneEconomy.ITEM).display_name=="胜利牌手摇留声机","new replacement / old embroidery retained")
	for cid in run_def.variety.luxury_carry_weights:check(run_def.variety.luxury_carry_weights[cid][GramophoneEconomy.ITEM]>0,"all holders may carry")

func knowledge_gramophone() -> void:
	var s:=gramophone();s._day.state.phase=&"pre_open";s._day.state.current_night_index=2;s._day.state.visits.clear();s._day.state.shop_growth.knowledge.clear()
	var cash:=s._day.state.cash;var prep:=PreparationService.count(s._day.state)
	check(s.growth_command("learn_knowledge","luxury_watch").ok,"gramophone guide learning")
	check(s._day.state.cash==cash and PreparationService.count(s._day.state)==prep+1,"once free preparation")
	check(not s.growth_command("learn_knowledge","luxury_watch").ok,"no duplicate learning")
