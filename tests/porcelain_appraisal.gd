extends "res://tests/pearl_appraisal.gd"

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/porcelain_manifest.json").load_catalog()
	for issue in loaded.issues:print(issue.format_message())
	check(loaded.is_success(),"v41 catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,41,store,catalog)

func porcelain(age:="ming",quality:="standard",damage:="intact",hidden:=false,cid:="customer_wealthy_factory",mode:="sell",sample:=0) -> RunSession:
	var s:=unit_visit(cid,PorcelainEconomy.ITEM,"sound",mode);equip(s,2)
	var v:CustomerVisit=s._day.state.visits[0]
	v.item.goods.precision={"damage":damage,"hidden":hidden}
	v.item.goods.porcelain_value={"era":age,"craft":quality,"sample":sample,"hidden":hidden,"actual":PorcelainEconomy.valuation(age,quality,damage)}
	PorcelainEconomy.prepare(s._day.state,v)
	var o:=PorcelainEconomy.owner(s._day.state,v);o.belief={"era":"yuan","craft":"fine"};o.rate=100;o.urgent=false
	PorcelainEconomy.reprice_initial(s._day.state,v);PorcelainNegotiation.prepare(s._day.state,v);MarketService.sync(s._day.state,run_def)
	return s

func pa(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.fan_command("luxury_porcelain",s._day.state.visits[0].item.instance_id,JSON.stringify(payload))

func pc(s:RunSession,payload:Dictionary) -> ActionResult:
	return s.counter_command("porcelain_claim",s._day.state.visits[0].visit_id,JSON.stringify(payload))

func begin(s:RunSession) -> void:
	check(s.fan_command("luxury_begin",s._day.state.visits[0].item.instance_id,"2").ok,"begin apparatus")

func run() -> void:
	if not setup():quit(1);return
	matrix();gates();negotiation();no_concession_replies();atomicity();generation();knowledge()
	print("PORCELAIN V41: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)

func matrix() -> void:
	for age in PorcelainEconomy.BASE:
		for quality in PorcelainEconomy.CRAFT:
			for damage in TieredAppraisal.RETAIN:
				for hidden in [false,true]:
					for sample in 2:
						var s:=porcelain(age,quality,damage,hidden,"customer_wealthy_antique","sell",sample);var v:CustomerVisit=s._day.state.visits[0];var id:=v.item.instance_id
						var fixed:=v.item.goods.duplicate(true)
						check(fixed.porcelain_value.actual==maxi(1,roundi(float({"yuan":900,"ming":600,"qing":300,"republic":90}[age])*float({"rough":.6,"standard":1.0,"fine":1.4}[quality])*float({"intact":1.0,"minor":.8,"major":.5}[damage]))),"72 combinations / two specimens fixed value")
						check(not fixed.porcelain_value.has("repair"),"no repair fact")
						check(s.counter_model().visual.estimate=="54–1260","initial range no hidden truth")
						check(s.fan_command("luxury_exterior",id).ok,"independent exterior")
						begin(s);pa(s,{"op":"light","light":"right"});pa(s,{"op":"zoom","zoom":true})
						for group in PorcelainAppraisal.GROUPS:
							check(pa(s,{"op":"group","group":group}).ok,"observe group")
							for angle in 4:check(pa(s,{"op":"turn","angle":angle}).ok,"turn fixed specimen")
							for reference in PorcelainEconomy.BASE:check(pa(s,{"op":"reference","era":reference}).ok,"free era reference")
						var record:=PorcelainAppraisal.row(s._day.state,id)
						check(record.light=="right" and record.zoom and record.viewed.size()==3,"light / zoom persistence and unique groups")
						check(PorcelainNegotiation.strength(s._day.state,v,"era")==2 and PorcelainNegotiation.strength(s._day.state,v,"craft")==2,"both evidence dimensions strong")
						check(pa(s,{"op":"draft","era":"qing","craft":"unsure"}).ok and pa(s,{"op":"seal"}).ok,"partial notes sealed")
						check(not pa(s,{"op":"draft","era":"yuan","craft":"fine"}).ok,"note immutable")
						check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes==15,"relook free")
						check(pc(s,{"era":"republic","craft":"rough","exterior":"observed"}).ok,"combined speech")
						check(record.era=="qing" and not pc(s,{"era":"yuan"}).ok,"speech separate / once")
						check(v.item.goods==fixed,"observation lies and prices never change facts")
						for buyer_id in run_def.buyer_ids:
							var buyer:BuyerDefinition=catalog.get_definition("buyers",buyer_id)
							check(s._commerce.base_quote(v.item,buyer)==maxi(1,roundi(fixed.porcelain_value.actual*buyer.value_multiplier)),"all buyer quotes use fixed value")
	check(PorcelainEconomy.valuation("qing","fine","intact")>PorcelainEconomy.valuation("ming","rough","intact"),"fine Qing above rough Ming")

func gates() -> void:
	for missing in ["bench","knowledge","time"]:
		var s:=porcelain();var v:CustomerVisit=s._day.state.visits[0]
		if missing=="bench":s._day.state.shop_growth.appraisal.bench_due=0;s._day.state.shop_growth.precision.due=0
		elif missing=="knowledge":s._day.state.shop_growth.knowledge.erase("luxury_porcelain")
		else:v.expires_at=9
		var before:=s.read_state();check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok and before==s.read_state(),"gate atomic "+missing)
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"basic remains available")
	var s:=porcelain();equip(s,3);s._day.state.shop_growth.precision.kits=[];var v:CustomerVisit=s._day.state.visits[0]
	begin(s);check(not s.fan_command("luxury_begin",v.item.instance_id,"3").ok,"no deep entry / no dedicated kit")
	check(pa(s,{"op":"seal"}).ok,"no complete examination needed")
	check(not pc(s,{"exterior":"observed"}).ok,"exterior needs actual check")

func negotiation() -> void:
	for tier in 3:
		var s:=porcelain();var v:CustomerVisit=s._day.state.visits[0]
		if tier>0:begin(s);pa(s,{"op":"group","group":"painting"})
		if tier==2:pa(s,{"op":"group","group":"foot"})
		for skill in 3:
			PorcelainEconomy.owner(s._day.state,v).skill=["expert","ordinary","novice"][skill]
			for correct in [true,false]:
				for part in ["era","craft"]:
					var word:String=("ming" if correct else "republic") if part=="era" else ("standard" if correct else "rough")
					check(PorcelainNegotiation.chance(s._day.state,v,part,word)==(WatchNegotiation.TRUE_CHANCES if correct else WatchNegotiation.FALSE_CHANCES)[tier][skill],"same belief probability matrix")
	for urgent in [false,true]:
		for personality in ["easy","careful","firm"]:
			var results:=[]
			for split in [false,true]:
				var s:=porcelain();var v:CustomerVisit=s._day.state.visits[0];var owner:=PorcelainEconomy.owner(s._day.state,v);owner.urgent=urgent
				PorcelainEconomy.reprice_initial(s._day.state,v);PorcelainNegotiation.prepare(s._day.state,v)
				var n:=PorcelainNegotiation.data(s._day.state,v);n.personality=personality;n.rolls.era=0;n.rolls.craft=0
				var initial:=v.trade.asking_price
				if split:check(pc(s,{"era":"republic"}).ok and pc(s,{"craft":"rough"}).ok,"split accepted lie")
				else:check(pc(s,{"era":"republic","craft":"rough"}).ok,"combined accepted lie")
				check(v.trade.asking_price==initial if personality=="firm" and not urgent else v.trade.asking_price<initial,"acceptance distinct from concession")
				check(n.facts.is_empty() and WealthyCustomers.trade(s._day.state,v).value==1260,"lie cannot reduce fair-price reference")
				results.append([v.trade.asking_price,v.trade.reserve_price,n.belief,n.rolls])
				var price:=v.trade.asking_price;PorcelainNegotiation.reprice(s._day.state,v);check(price==v.trade.asking_price,"no cumulative discount")
			check(results[0]==results[1],"fixed outcomes independent of grouping")
	var s:=porcelain();var v:CustomerVisit=s._day.state.visits[0];var n:=PorcelainNegotiation.data(s._day.state,v);n.rolls.era=99;n.rolls.craft=99
	var rep:int=s._day.state.social.reputation;check(pc(s,{"era":"republic"}).ok and s._day.state.social.reputation==rep-2,"false devaluation caught")
	check(pc(s,{"craft":"rough"}).ok and s._day.state.social.reputation==rep-2,"one reputation penalty")
	for cid in WealthyCustomers.NAMES:
		for mode in ["sell","pawn"]:
			var x:=porcelain("republic","rough","major",false,cid,mode);var visit:CustomerVisit=x._day.state.visits[0]
			var d:=PorcelainNegotiation.data(x._day.state,visit);d.personality="easy";d.rolls.era=0;d.rolls.craft=0
			check(pc(x,{"era":"republic","craft":"rough"}).ok,"holder accepts")
			var floor_price:int=0 if mode=="sell" else 293 if cid=="customer_wealthy_factory" else 338 if cid=="customer_wealthy_comprador" else 0
			check(WealthyCustomers.trade(x._day.state,visit).funding==floor_price and visit.trade.reserve_price>=floor_price,"293 / 338 funding floors")
	var cheap:=porcelain("yuan","fine");v=cheap._day.state.visits[0];var o:=PorcelainEconomy.owner(cheap._day.state,v);o.belief={"era":"republic","craft":"rough"};PorcelainEconomy.reprice_initial(cheap._day.state,v);PorcelainNegotiation.prepare(cheap._day.state,v)
	n=PorcelainNegotiation.data(cheap._day.state,v);n.rolls.era=0;n.rolls.craft=0;var low:=v.trade.asking_price
	check(pc(cheap,{"era":"yuan","craft":"fine"}).ok and v.trade.asking_price==low,"underestimated antique never automatically raised")

func no_concession_replies() -> void:
	for scenario in ["firm","already_rough","already_damage","previous_discount","funding","higher_belief","rejected"]:
		var s:=porcelain("ming","rough","minor",false,"customer_wealthy_factory","pawn" if scenario=="funding" else "sell")
		var state:=s._day.state;var v:CustomerVisit=state.visits[0];var o:=PorcelainEconomy.owner(state,v)
		if scenario=="already_rough":o.belief={"era":"ming","craft":"rough"}
		if scenario in ["funding","higher_belief"]:o.belief={"era":"republic","craft":"fine" if scenario=="funding" else "rough"}
		PorcelainEconomy.reprice_initial(state,v);PorcelainNegotiation.prepare(state,v)
		var n:=PorcelainNegotiation.data(state,v);n.personality="firm" if scenario=="firm" else "easy";n.rolls.craft=0;n.rolls.era=0
		if scenario=="previous_discount":v.trade.asking_price=50;v.trade.reserve_price=40
		if scenario=="rejected":n.rolls.craft=99
		var claims:={"craft":"rough"}
		if scenario=="already_damage":
			check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"exterior known for price reply")
			claims={"exterior":"observed"}
		if scenario=="higher_belief":claims={"era":"yuan","craft":"fine"}
		var before:=v.trade.asking_price;var fixed:=v.item.goods.duplicate(true)
		check(pc(s,claims).ok,"no concession speech "+scenario)
		var message:String=n.responses.back().message
		var expected:String={"firm":"少了便先留着","already_rough":"原就按粗工算了","already_damage":"这点外伤，开价时","previous_discount":"方才已经让过价了","funding":"至少得筹到 293 银元","higher_belief":"没有再往下折的道理","rejected":"单凭这些，我还信不过"}[scenario]
		check(expected in message,"specific no concession reason "+scenario)
		check(v.trade.asking_price==before and v.item.goods==fixed,"reply preserves price and actual goods "+scenario)
		if scenario=="rejected":check(not "货况我认" in message and not "客人点头" in message,"rejection does not claim agreement")

func atomicity() -> void:
	for operation in ["begin","group","reference","draft","seal","claim"]:
		var s:=porcelain();var v:CustomerVisit=s._day.state.visits[0]
		if operation!="begin":begin(s)
		var before:=s.read_state();(s._save as CountingStore).fail=true
		var result:ActionResult
		if operation=="begin":result=s.fan_command("luxury_begin",v.item.instance_id,"2")
		elif operation=="claim":result=pc(s,{"era":"republic"})
		else:result=pa(s,{"op":operation,"group":"foot","era":"qing","craft":"fine"})
		check(not result.ok and before==s.read_state(),"write rollback "+operation)
	var s:=porcelain();begin(s)
	for payload in [{"op":"group","group":"seam"},{"op":"turn","angle":4},{"op":"zoom","zoom":"true"},{"op":"draft","era":"modern","craft":"fine"}]:
		var before:=s.read_state();check(not pa(s,payload).ok and before==s.read_state(),"malformed request atomic")

func generation() -> void:
	var s:=porcelain();var state:=s._day.state;var item:ItemInstance=state.visits[0].item
	var counts:={"yuan":0,"ming":0,"rough":0,"standard":0,"fine":0,"hidden":0};var specimens:={}
	for seed_value in 3000:
		state.run_seed=seed_value;item.goods.erase("porcelain_value");item.selected_variant_id="sound";PorcelainEconomy.attach(state,item)
		var f:Dictionary=item.goods.porcelain_value;counts[f.era]+=1;counts[f.craft]+=1;counts.hidden+=int(f.hidden);specimens[f.sample]=true
		var fixed:=item.goods.duplicate(true);PorcelainEconomy.attach(state,item);check(fixed==item.goods,"facts attached once")
	check(absf(counts.yuan/3000.0-.2)<.035 and absf(counts.hidden/3000.0-.3)<.035,"independent era / difficulty distributions")
	for c in ["rough","fine"]:check(absf(counts[c]/3000.0-.2)<.035,"craft distribution")
	check(specimens.size()==2,"two specimens generated")
	for variant in ["mended","flawed"]:
		item.goods.erase("porcelain_value");item.selected_variant_id=variant;PorcelainEconomy.attach(state,item)
		check(item.goods.porcelain_value.era==("qing" if variant=="mended" else "republic"),"old variant maps only to era")
	var legacy:=JsonContentProvider.new("res://data/bangle_unified_manifest.json").load_catalog()
	check(not PorcelainEconomy.enabled(legacy.catalog.get_definition("runs",legacy.catalog.default_run_id)),"v40 disabled unchanged")

func knowledge() -> void:
	var s:=porcelain();s._day.state.phase=&"pre_open";s._day.state.current_night_index=2;s._day.state.visits.clear();s._day.state.shop_growth.knowledge.clear()
	var cash:=s._day.state.cash;var count:=PreparationService.count(s._day.state)
	check(s.growth_command("learn_knowledge","luxury_porcelain").ok,"learn guide")
	check(s._day.state.cash==cash and PreparationService.count(s._day.state)==count+1,"one preparation no fee")
	check(not s.growth_command("learn_knowledge","luxury_porcelain").ok,"cannot learn twice")
