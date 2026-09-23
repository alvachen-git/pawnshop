extends "res://tests/watch_negotiation.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/pearl_market_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
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
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay "+label)

func pearl(variant := "sound", damage := "intact", hidden := false, cid := "customer_wealthy_opera", mode := "sell") -> RunSession:
	var s := unit_visit(cid,PearlEconomy.ITEM,variant,mode); equip(s,2)
	var v: CustomerVisit = s._day.state.visits[0]
	v.item.goods.precision = {"damage":damage,"hidden":hidden}; v.item.goods.erase("pearl_value")
	PearlEconomy.prepare(s._day.state,v)
	MarketService.sync(s._day.state,run_def)
	return s

func bead_action(s: RunSession, payload: Dictionary) -> ActionResult:
	return s.fan_command("luxury_pearl",s._day.state.visits[0].item.instance_id,JSON.stringify(payload))

func claim(s: RunSession, payload: Dictionary) -> ActionResult:
	return s.counter_command("pearl_claim",s._day.state.visits[0].visit_id,JSON.stringify(payload))

func run() -> void:
	if not setup(): quit(1); return
	carry_checks()
	composition_checks()
	transaction_checks()
	selection_setup_checks()
	knowledge_checks()
	print("PEARL V38: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func selection_setup_checks() -> void:
	var s := pearl(); var v: CustomerVisit = s._day.state.visits[0]; var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"batch inspection begins")
	check(bead_action(s,{"op":"light","index":0,"light":"right"}).ok,"batch light")
	var facts := v.item.goods.duplicate(true)
	for i in 4:
		check(bead_action(s,{"op":"select","index":i,"angle":2,"hole":true}).ok,"batch select at retained angle and hole")
	var row := PearlAppraisal.row(s._day.state,id)
	check(row.light=="right" and row.holes.size()==4 and row.angles=={"0":2,"1":2,"2":2,"3":2},"each viewed bead gets the retained setup")
	check(bead_action(s,{"op":"select","index":3,"angle":2,"hole":true}).ok and row.holes.size()==4,"reselect does not duplicate evidence")
	check(bead_action(s,{"op":"select","index":4,"angle":1,"hole":false}).ok and 4 not in row.holes,"surface mode does not claim hole evidence")
	check(bead_action(s,{"op":"select","index":5}).ok and not row.angles.has("5") and 5 not in row.holes,"legacy select retains original semantics")
	check(s._day.state.game_minutes==10 and v.item.goods==facts,"batch viewing remains free and does not change pearls")
	for payload in [{"op":"select","index":6,"angle":3},{"op":"select","index":6,"hole":"true"}]:
		var before := s.read_state()
		check(not bead_action(s,payload).ok and before==s.read_state(),"invalid setup cannot mutate evidence")
	var before := s.read_state(); (s._save as CountingStore).fail=true
	check(not bead_action(s,{"op":"select","index":6,"angle":1,"hole":true}).ok and before==s.read_state(),"selection angle and hole roll back together on disk failure")

func carry_checks() -> void:
	var state := RunState.create(run_def); state.ghost_catalog = catalog
	var legacy := JsonContentProvider.new("res://data/named_wealthy_manifest.json").load_catalog()
	var old_run: RunDefinition = legacy.catalog.get_definition("runs",legacy.catalog.default_run_id)
	for cid in WealthyCustomers.NAMES:
		var c: CustomerDefinition = catalog.get_definition("customers",cid)
		var counts := {}
		for seed_value in 10000:
			var picked := LuxuryCarry.pick(run_def,c,seed_value,"test-slot")
			counts[picked] = counts.get(picked,0)+1
		check(counts.size() == 10,"all ten goods supported "+cid)
		for iid in run_def.variety.luxury_carry_weights[cid]:
			check(absf(float(counts[iid])/100.0-float(run_def.variety.luxury_carry_weights[cid][iid]))<1.5,"carrying distribution "+cid+iid)
			var s := unit_visit(cid,iid,"sound"); var v: CustomerVisit = s._day.state.visits[0]
			var item_def: ItemDefinition = catalog.get_definition("items",iid)
			check(v.trade.patience == c.patience and v.trade.rounds_left == c.max_quote_rounds,"actual holder patience")
			check(WealthyCustomers.trade(s._day.state,v).funding == roundi(item_def.base_value*.5*float(run_def.variety.luxury.profiles[cid].funding_percent)/100),"item specific funding")
			if iid == WatchAppraisal.ITEM:
				equip(s,2); var facts := v.item.goods.duplicate(true)
				check(s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"watch holder apparatus")
				check(v.item.goods == facts,"watch holder fixed value")
				var o := WatchEconomy.owner(s._day.state,v); o.belief = "sound"; o.rate = 100; o.urgent = false
				v.item.goods.precision.damage = "intact"; WatchEconomy.reprice(s._day.state,v,true)
				check(v.trade.asking_price == roundi(250*float(run_def.variety.luxury.profiles[cid].asking_percent)/100),"holder ask multiplier")
		for seed_value in 30:
			state.run_seed = seed_value
			var slot := {"visit_id":"shared/4/test","night":4,"arrival":30}
			var now := WealthyCustomers.make_row(state,run_def,catalog,slot,cid,[])
			var old := WealthyCustomers.make_row(state,old_run,legacy.catalog,slot,cid,[])
			check(now == WealthyCustomers.make_row(state,run_def,catalog,slot,cid,[]),"deterministic carrying")
			for field in ["variant_id","transaction_modes","terms_id"]: check(now[field] == old[field],"carrying preserves condition, mode, redemption RNG")

func composition_checks() -> void:
	var seen := {}; var positions := {}; var counts := {}
	for seed_value in 300:
		var state := RunState.create(run_def); state.ghost_catalog = catalog; state.run_seed = seed_value
		for variant in ["sound","mended","flawed"]:
			for damage in ["intact","minor","major"]:
				for hidden in [false,true]:
					var item := ItemInstance.new(); item.definition_id = PearlEconomy.ITEM; item.instance_id = "composition/test"; item.selected_variant_id = variant
					item.goods.precision = {"damage":damage,"hidden":hidden}; PearlEconomy.attach(state,item)
					var p: Dictionary = item.goods.pearl_value; var weight := 0
					for b in p.beads: weight += b.weight
					check(weight == 52 and p.beads.size() == 32,"32 fixed beads weight52")
					check(p.actual == PearlEconomy.value(p.beads,damage),"composition fixed value")
					check(p.actual == roundi(440*float(TieredAppraisal.RETAIN[damage])/100) if variant == "sound" else p.actual == roundi(60*float(TieredAppraisal.RETAIN[damage])/100) if variant == "flawed" else p.actual>30,"condition damage values")
					var before := item.goods.duplicate(true); PearlEconomy.attach(state,item); check(before == item.goods,"no reroll on attach")
					seen[p.kind] = true
					var changes: Array = p.beads.filter(func(b: Dictionary) -> bool: return b.quality != "fine")
					if p.kind in ["lower","mixed"]:
						counts[p.kind+str(changes.size())] = true
						for b in changes: positions[int(b.index)] = true
	check(seen.size()==4 and positions.size()==32 and counts.size()==8,"four families, every replacement count and location")
	var s := pearl(); var beads: Array = s._day.state.visits[0].item.goods.pearl_value.beads.duplicate(true)
	beads[0].quality="imitation"; var small := PearlEconomy.value(beads,"intact"); beads[0].quality="fine"; beads[14].quality="imitation"
	check(PearlEconomy.value(beads,"intact") < small,"large bead replacement loses more value")

func transaction_checks() -> void:
	for variant in ["sound","mended","flawed"]:
		for damage in ["intact","minor","major"]:
			for hidden in [false,true]:
				var s := pearl(variant,damage,hidden); var v: CustomerVisit = s._day.state.visits[0]; var facts := v.item.goods.duplicate(true); var id := v.item.instance_id
				check(s.counter_model().visual.estimate == "60–440","conservative initial range")
				check(s.fan_command("luxury_exterior",id).ok,"basic exterior")
				check(s.fan_command("luxury_begin",id,"2").ok,"apparatus")
				check(s._day.state.game_minutes == 15,"starts charge5+10")
				for i in 3:
					check(bead_action(s,{"op":"hole","index":i}).ok,"inspect hole")
					check(bead_action(s,{"op":"turn","index":i,"angle":2}).ok,"turn")
					check(bead_action(s,{"op":"light","index":i,"light":"left"}).ok,"light")
				for pair in [[0,1],[1,0],[0,2]]: check(bead_action(s,{"op":"compare","index":pair[0],"other":pair[1]}).ok,"compare")
				check(PearlAppraisal.row(s._day.state,id).pairs.size()==2 and PearlNegotiation.strength(s._day.state,v,"material")==2,"unique evidence only")
				check(bead_action(s,{"op":"draft","material":"all","repair":"unsure"}).ok,"private guess")
				check(bead_action(s,{"op":"seal"}).ok,"partial seal")
				check(not bead_action(s,{"op":"draft","material":"none","repair":"intact"}).ok,"sealed immutable")
				check(s.fan_command("luxury_begin",id,"2").ok and s._day.state.game_minutes == 15,"free revisit")
				var n := PearlNegotiation.data(s._day.state,v)
				for part in n.rolls: n.rolls[part] = 0
				check(claim(s,{"material":"few","repair":"altered","exterior":"observed"}).ok,"whole string claims")
				check(PearlAppraisal.row(s._day.state,id).material=="all" and n.claims.material=="few","private notes not overwritten by claims")
				check(not claim(s,{"material":"none"}).ok,"single chance")
				check(v.item.goods == facts,"inspection and belief cannot change object")
				for buyer_id in run_def.buyer_ids:
					var buyer: BuyerDefinition = catalog.get_definition("buyers",buyer_id)
					check(s._commerce.base_quote(v.item,buyer)==maxi(1,roundi(facts.pearl_value.actual*buyer.value_multiplier)),"resale fixed actual")
	for personality in ["easy","careful","firm"]:
		var s := pearl(); var v: CustomerVisit=s._day.state.visits[0]; var n:=PearlNegotiation.data(s._day.state,v)
		n.personality=personality; n.rolls.material=0; var before:=v.trade.asking_price
		check(claim(s,{"material":"all"}).ok,"unexamined claim can persuade")
		check(v.trade.asking_price < before if personality != "firm" else v.trade.asking_price == before,"concession behavior "+personality)
		var price:=v.trade.asking_price; PearlNegotiation.reprice(s._day.state,v); check(price==v.trade.asking_price,"no stacking reprices")
	for action in ["begin","seal","claim"]:
		var s:=pearl(); var v:CustomerVisit=s._day.state.visits[0]
		if action=="seal": s.fan_command("luxury_begin",v.item.instance_id,"2")
		var baseline:=s.read_state(); (s._save as CountingStore).fail=true
		var result: ActionResult = s.fan_command("luxury_begin",v.item.instance_id,"2") if action=="begin" else bead_action(s,{"op":"seal"}) if action=="seal" else claim(s,{"material":"all"})
		check(not result.ok and baseline==s.read_state(),"disk failure rollback "+action)
	var s:=pearl(); var v:CustomerVisit=s._day.state.visits[0]; v.expires_at=10; var baseline:=s.read_state()
	check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok and baseline==s.read_state(),"insufficient time no charge")
	s=pearl(); v=s._day.state.visits[0]; s._day.state.shop_growth.precision.kits.erase("jewel")
	check(s.fan_command("luxury_exterior",v.item.instance_id).ok and not s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"no tools exterior only")
	s=pearl(); v=s._day.state.visits[0]; s._day.state.shop_growth.knowledge.erase("luxury_jade")
	check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"knowledge gate")
	s=pearl(); v=s._day.state.visits[0]; var n:=PearlNegotiation.data(s._day.state,v); n.rolls.material=99; n.rolls.repair=99
	var rep:int=s._day.state.social.reputation; var patience:=v.trade.patience
	check(claim(s,{"material":"all","repair":"altered"}).ok,"caught false claims")
	check(s._day.state.social.reputation==rep-2 and v.trade.patience==patience-2,"one reputation and patience event")

func knowledge_checks() -> void:
	var s:=second_night(); var before:=PreparationService.count(s._day.state); var cash:=s._day.state.cash
	check(s.growth_command("learn_knowledge","luxury_jade").ok,"fifth cabinet study")
	check(PreparationService.count(s._day.state)==before+1 and s._day.state.cash==cash,"study one free preparation")
	check(not s.growth_command("learn_knowledge","luxury_jade").ok,"no duplicate study")
	verify(s,"guide and opening")
