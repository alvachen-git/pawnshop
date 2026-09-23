extends "res://tests/watch_appraisal.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_market_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v34 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,34,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,34),run_def,34,catalog,true)
	check(restored != null,"v34 replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay "+label)

func watch_fixture(variant := "sound", damage := "intact", operation := "stable", mode := "sell") -> RunSession:
	var s := unit_visit("customer_wealthy_factory",WatchAppraisal.ITEM,variant,mode); equip(s,2)
	var v: CustomerVisit = s._day.state.visits[0]
	v.item.goods.precision.damage = damage
	v.item.goods.watch_value.operation = operation; v.item.goods.watch_value.actual = WatchEconomy.valuation(variant,damage,operation)
	v.expires_at = 200; v.trade.rounds_left = 10; v.trade.patience = 20
	return s

func evidence(s: RunSession, identity := true, running := true, wrong_identity := false) -> void:
	var v: CustomerVisit = s._day.state.visits[0]; var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"paid start")
	if identity:
		check(command(s,id,{"op":"open"}).ok,"open")
		for i in 2:
			var point := WatchAppraisal.spot(v.item,i)
			check(command(s,id,{"op":"inspect","point":[point.x,point.y]}).ok,"mechanism")
	if running:
		check(command(s,id,{"op":"wind"}).ok,"wind")
		for pose in ["flat","vertical"]:
			check(command(s,id,{"op":"pose","pose":pose}).ok,"pose")
			check(command(s,id,{"op":"listen","clip":"wound/"+pose}).ok,"listen")
		check(WatchAppraisal.row(s._day.state,id).marks.is_empty(),"v34 evidence without manual marks")
	var book := LuxuryAppraisalService.info(s._day.state,v.item)
	var old := TieredAppraisal.stage(s._day.state,id,2)
	var row := WatchAppraisal.row(s._day.state,id)
	check(command(s,id,{"op":"draft","identity":("imitation" if wrong_identity else book.identity[v.item.selected_variant_id]) if identity else old.identity,"condition":book.condition[v.item.selected_variant_id] if identity else old.condition,"running":v.item.goods.watch_value.operation if running else row.running}).ok,"draft independent evidence")

func run() -> void:
	if not setup(): quit(1); return
	var combos := 0
	for variant in ["sound","mended","flawed"]:
		for damage in ["intact","minor","major"]:
			for operation in ["stable","positional","stopping"]:
				var s := watch_fixture(variant,damage,operation); var state := s._day.state; var v: CustomerVisit = state.visits[0]
				var definition := catalog.get_definition("items",WatchAppraisal.ITEM) as ItemDefinition
				var value := GoodsExpertise.value(v.item,definition); var facts: Dictionary = v.item.goods.watch_value.duplicate(true)
				var expected := roundi(float({"sound":500,"mended":350,"flawed":100}[variant])*float({"intact":1.0,"minor":.8,"major":.5}[damage])*float({"stable":1.0,"positional":.8,"stopping":.5}[operation]))
				check(value == expected,"independent value "+variant+damage+operation)
				check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"exterior")
				evidence(s)
				check(s.counter_command("luxury_pressure",v.visit_id).ok,"combined evidence")
				check(WatchEconomy.owner(state,v).accepted.size() == 3,"three accepted components")
				check(not s.counter_command("luxury_pressure",v.visit_id).ok,"evidence cannot repeat")
				check(GoodsExpertise.value(v.item,definition) == value and facts == v.item.goods.watch_value,"inspection never changes actual value")
				var copy := RunSnapshot.copy(state)
				check(copy.visits[0].item.goods.watch_value == facts,"snapshot retains facts")
				for buyer_id in run_def.buyer_ids:
					var buyer := catalog.get_definition("buyers",buyer_id) as BuyerDefinition
					check(s._commerce.base_quote(v.item,buyer) == maxi(1,roundi(value*buyer.value_multiplier)),"buyer actual value")
				combos += 1
	var s := watch_fixture("sound","minor","positional"); var v: CustomerVisit = s._day.state.visits[0]
	evidence(s,true,false,true)
	check(s.counter_command("luxury_pressure",v.visit_id).ok,"wrong identity only")
	check(WatchEconomy.owner(s._day.state,v).accepted.is_empty(),"wrong proof not accepted")
	evidence(s,false,true)
	check(s.counter_command("luxury_pressure",v.visit_id).ok,"later independent running")
	check(WatchEconomy.owner(s._day.state,v).accepted == ["running"],"running independent of wrong identity")
	check(not command(s,v.item.instance_id,{"op":"draft","identity":"original","condition":"intact","running":"positional"}).ok,"used wrong judgment cannot be retried")
	for incomplete in [true,false]:
		s = watch_fixture("sound","intact","positional"); v = s._day.state.visits[0]
		evidence(s,false,true)
		var listening := WatchAppraisal.row(s._day.state,v.item.instance_id)
		if incomplete: listening.listened.erase("wound/vertical")
		else: check(command(s,v.item.instance_id,{"op":"draft","identity":"unsure","condition":"unsure","running":"stable"}).ok,"wrong running judgment recorded")
		var patience := v.trade.patience
		check(s.counter_command("luxury_pressure",v.visit_id).ok,"incomplete or wrong audio proof handled")
		check(WatchEconomy.owner(s._day.state,v).accepted.is_empty() and v.trade.patience < patience,"removing marks does not accept unlistened or wrong judgments")
	for variant in ["sound","flawed"]:
		for roll in [0,99]:
			s = watch_fixture(variant); v = s._day.state.visits[0]
			var o := WatchEconomy.owner(s._day.state,v); o.bluff_roll = roll; o.skill = "novice"
			var before: int = s._day.state.social.reputation; var old_price := v.trade.asking_price
			check(s.counter_command("watch_bluff",v.visit_id).ok,"bluff command")
			check(s._day.state.social.reputation == before+(-2 if roll == 0 and variant == "sound" else 0),"only spotted false claim punished")
			check(v.trade.asking_price == (old_price if roll == 0 else maxi(v.trade.reserve_price,roundi(old_price*.85))),"bluff concession")
			check(not s.counter_command("watch_bluff",v.visit_id).ok,"one bluff")
	s = watch_fixture(); v = s._day.state.visits[0]; MarketService.sync(s._day.state,run_def); var baseline := s.read_state(); (s._save as CountingStore).fail = true
	check(not s.counter_command("watch_bluff",v.visit_id).ok and baseline == s.read_state(),"bluff disk failure rollback")
	(s._save as CountingStore).fail = false
	# Normal low offers and voluntary cheap sales must not trigger the old punishment.
	s = watch_fixture(); v = s._day.state.visits[0]
	var o := WatchEconomy.owner(s._day.state,v); o.belief = "flawed"; o.rate = 60; o.urgent = false
	WatchEconomy.reprice(s._day.state,v,true)
	var price := v.trade.reserve_price; var reputation: int = s._day.state.social.reputation
	check(price < 100,"uninformed owner can sell true watch cheaply")
	check(s.counter_command("offer",v.visit_id,"",price).ok and v.item.ownership_state == "owned","cheap genuine acquisition")
	check(s._day.state.social.reputation == reputation,"cheap sale no reputation penalty")
	check(WatchEconomy.owner(s._day.state,v).accepted.is_empty() and v.item.goods.watch_value.actual == 500,"cheap quote never changes value or claims evidence")
	var buyer_id := ""
	for key in run_def.buyer_ids:
		var buyer := catalog.get_definition("buyers",key) as BuyerDefinition
		if s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): buyer_id = key; break
	check(not buyer_id.is_empty(),"available watch resale buyer")
	if not buyer_id.is_empty():
		var quote := s._commerce.quote(v.item,catalog.get_definition("buyers",buyer_id))
		check(s.commerce_command("sell",v.item.instance_id,buyer_id).ok,"actual batch-route resale")
		check(v.item.ownership_state == "sold" and s._day.state.ledger_entries.back().realized_profit == quote-price,"resale realizes true proceeds less cost")
	for redeem in [false,true]:
		s = watch_fixture("mended","minor","stopping","pawn"); v = s._day.state.visits[0]
		v.pawn_terms_id = "sample_three_redeem" if redeem else "sample_three_default"
		var actual: int = v.item.goods.watch_value.actual
		check(s.counter_command("pawn",v.visit_id,"",v.trade.reserve_price).ok,"issue real watch ticket")
		var ticket := s._day.state.pawn_tickets.back() as PawnTicket
		check(ticket.due_night == 7 and ticket.redemption_amount == ticket.principal+ceili(ticket.principal*.1),"three night and ten percent fee")
		for key in run_def.buyer_ids:
			check(not s._commerce.item_reason(s._day,v.item,catalog.get_definition("buyers",key)).is_empty(),"pledged watch cannot sell")
		s._day.state.current_night_index = 7; s._day.state.game_minutes = 0
		if redeem:
			PawnReturnService.prepare(s._day.state,catalog); PawnReturnService.arrive(s._day.state)
			var cash_before: int = s._day.state.cash
			check(s.counter_command("redeem",PawnReturnService.current(s._day.state).id).ok,"real redemption visitor")
			check(s._day.state.cash == cash_before+ticket.redemption_amount and ticket.status == "redeemed","redemption ledger settled")
		else:
			PawnController.new().resolve_maturities(s._day.state,run_def.night_minutes,catalog,{ticket.ticket_id:"keep"})
			check(ticket.status == "defaulted" and v.item.ownership_state == "owned","due absent collateral becomes owned")
			check(GoodsExpertise.value(v.item,catalog.get_definition("items",WatchAppraisal.ITEM)) == actual,"default retains fixed actual value")
			var display := CustomerVisit.new(); display.visit_id = "display/watch"; display.purpose = "display_buyer"; display.item = v.item
			s._day.state.shop_growth.opportunities.append({"night":7,"offer_factor":90,"cap_factor":110,"status":"scheduled"})
			ShopGrowthService.activate(s._day.state,display)
			check(ShopGrowthService.opportunity(s._day.state).offer == roundi(actual*.9),"display sale uses same actual value")
	s = watch_fixture(); v = s._day.state.visits[0]; reputation = s._day.state.social.reputation
	v.trade.patience = 1
	check(s.counter_command("offer",v.visit_id,"",1).ok and s._day.state.social.reputation == reputation,"low refused offer no reputation penalty")
	s = watch_fixture(); v = s._day.state.visits[0]; o = WatchEconomy.owner(s._day.state,v)
	evidence(s,true,false); check(s.counter_command("luxury_pressure",v.visit_id).ok,"shared genuine evidence")
	o.bluff_roll = 99; o.skill = "novice"; reputation = s._day.state.social.reputation
	check(s.counter_command("watch_bluff",v.visit_id).ok and o.bluff_spotted and s._day.state.social.reputation == reputation-2,"shared facts force detection")
	s = watch_fixture(); v = s._day.state.visits[0]; o = WatchEconomy.owner(s._day.state,v)
	o.bluff_roll = 0
	s._day.state.social.trades.append({"visit_id":"prior","night":s._day.state.current_night_index,"delta":-5})
	reputation = s._day.state.social.reputation
	check(s.counter_command("watch_bluff",v.visit_id).ok and s._day.state.social.reputation == reputation-1,"daily negative cap shared")
	s = watch_fixture(); v = s._day.state.visits[0]; v.expires_at = 5
	baseline = s.read_state()
	check(not s.counter_command("watch_bluff",v.visit_id).ok and s._day.state.game_minutes == 0 and not WatchEconomy.owner(s._day.state,v).bluff_used,"deadline prevents spending and consumes no bluff")
	s = watch_fixture("flawed","major","stopping","pawn"); v = s._day.state.visits[0]
	evidence(s); check(s.counter_command("luxury_pressure",v.visit_id).ok,"fault proof on worthless collateral")
	check(v.trade.reserve_price >= 163,"funding floor remains")
	check(s.counter_command("pawn",v.visit_id,"",100).ok and v.item.ownership_state != "pledged","cannot meet funding floor")
	check(ShopKnowledgeService.topic_info(run_def,"luxury_watch").cabinet == 2,"guide second cabinet")
	check(ShopKnowledgeService.topic_info(run_def,"luxury_textile").cabinet == 4,"textile fourth cabinet")
	for seed_value in 50:
		for suffix in ["/customer","/wealthy/customer_wealthy_factory/mode","/pawn-redemption"]:
			check(VarietyService.rng(seed_value,"watch_market_ten/4/visit"+suffix).randi() == VarietyService.rng(seed_value,"watch_ten/4/visit"+suffix).randi(),"legacy random namespace preserved")
	var counts := {"stable":0,"positional":0,"stopping":0}; var skills := {"expert":0,"ordinary":0,"novice":0}; var urgency := 0
	s = watch_fixture(); v = s._day.state.visits[0]
	for seed_value in 10000:
		s._day.state.run_seed = seed_value; v.item.goods.erase("watch_value"); WatchEconomy.attach(s._day.state,v.item); WatchEconomy.prepare(s._day.state,v)
		counts[v.item.goods.watch_value.operation] += 1
		o = WatchEconomy.owner(s._day.state,v); skills[o.skill] += 1; urgency += 1 if o.urgent else 0
	for key in counts: check(absf(counts[key]/10000.0-float({"stable":.7,"positional":.2,"stopping":.1}[key])) < .025,"operation distribution "+key)
	for key in skills: check(absf(skills[key]/10000.0-float({"expert":.3,"ordinary":.5,"novice":.2}[key])) < .025,"owner distribution "+key)
	check(absf(urgency/10000.0-.3) < .025,"urgency distribution")
	print("WATCH ECONOMY: %d combinations; %d passes, %d failures; distribution %s" % [combos,passes,failures,str(counts)])
	quit(0 if failures == 0 else 1)
