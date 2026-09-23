extends "res://tests/unified_social.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/wealthy_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v31 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,31,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var restored := codec.decode(codec.encode(s._day.state,31),run_def,31,catalog,true)
	check(restored != null,"v31 replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/wealthy")
	var file := FileAccess.open("res://.godot/qa/wealthy/" + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,31)))

func run() -> void:
	if not setup(): quit(1); return
	distribution()
	protected_visitors()
	condition_distribution()
	content_guards()
	all_goods()
	personality_and_cash()
	pawn_lifecycle()
	ad_boundaries()
	milestones()
	natural_play()
	print("WEALTHY V31: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func content_guards() -> void:
	var original := run_def._variety.duplicate(true)
	run_def._variety.luxury.profiles.customer_wealthy_silk.weights = [65,25,9]
	check(not LuxuryContentValidator.validate(catalog).is_empty(),"invalid condition probability rejected")
	run_def._variety = original.duplicate(true)
	run_def._variety.luxury.items.item_luxury_embroidery.references = []
	check(not LuxuryContentValidator.validate(catalog).is_empty(),"missing comparison evidence rejected")
	run_def._variety = original

func condition_distribution() -> void:
	var state := RunState.create(run_def); state.ghost_catalog = catalog
	var old := {"visit_id":"wealthy_ten/5/frequency","night":5,"arrival":100}
	for cid in run_def.variety.luxury.profiles:
		var counts := {"sound":0,"mended":0,"flawed":0}
		var pawns := 0; var redeems := 0; var first_item := 0
		var c := catalog.get_definition("customers",cid) as CustomerDefinition
		for seed_value in 3000:
			state.run_seed = seed_value*3571
			var row := WealthyCustomers.make_row(state,run_def,catalog,old,cid,[])
			counts[row.variant_id] += 1
			if row.transaction_modes == ["pawn"]: pawns += 1
			if row.terms_id == PawnRedemptionPolicy.REDEEM: redeems += 1
			if row.item_id == c.item_pool[0]: first_item += 1
		var p: Dictionary = run_def.variety.luxury.profiles[cid]
		for index in 3: check(absf(float(counts[["sound","mended","flawed"][index]])/30.0-float(p.weights[index])) < 3.0,"condition weight " + cid)
		check(absf(pawns/30.0-float(p.pawn_percent)) < 3.0,"pawn vs sale weight " + cid)
		check(absf(redeems/30.0-c.pawn_redemption_chance) < 3.0,"redemption weight " + cid)
		check(absf(first_item/30.0-50) < 3.0,"two items equiprobable " + cid)

func distribution() -> void:
	var profiles: Dictionary = run_def.variety.luxury.profiles
	check(profiles.size() == 5 and run_def.variety.luxury.items.size() == 10,"five professions ten goods")
	for reputation in [-100,0,1,9,10,19,20,39,40,59,60,79,80,100]:
		var counts := [0,0,0]
		var compradores := 0
		for seed_value in 10000:
			var selected := WealthyCustomers.draw(seed_value*7919,4,reputation,profiles)
			counts[selected.size()] += 1
			if WealthyCustomers.COMPRADOR in selected: compradores += 1
			if selected.size() == 2 and selected[0] == selected[1]: check(false,"no duplicate class")
		var policy := WealthyCustomers.tier(reputation)
		for index in 3: check(absf(counts[index]/100.0-float(policy[index+1])) < 2.0,"frequency %d count%d: %s" % [reputation,index,counts])
		var expected := (100-float(policy[1]))*float(policy[4])/100.0
		check(absf(compradores/100.0-expected) < 1.5,"comprador unconditional " + str(reputation))
	var state := RunState.create(run_def)
	state.ghost_catalog = catalog; state.run_seed = 11; state.current_night_index = 5; state.social.reputation = 100
	var plan := OpeningPreparation.plan(state,run_def,catalog)
	var now := plan.filter(func(r: Dictionary) -> bool: return r.night == 5)
	check(now.filter(func(r: Dictionary) -> bool: return r.get("wealthy",false)).size() <= 2,"overlay cap")
	var before := plan.duplicate(true)
	state.social.reputation = -100
	check(before == OpeningPreparation.plan(state,run_def,catalog),"snapshot never rerolls after reputation change")
	for row in now:
		if row.get("wealthy",false): check(not row.has("seven_role") and row.item_id != CoatProcurement.ITEM,"protected roles and coat override")

func unit_visit(customer_id: String, item_id: String, variant: String, mode := "pawn") -> RunSession:
	var s := fresh_growth()
	var state := s._day.state
	state.phase = &"open"; state.current_night_index = 4; state.game_minutes = 0; state.cash = 10000
	state.pending_event_id = ""; state.social.pending.clear(); state.social.intro_step = -1
	state.visits.clear(); state.pawn_returns.clear()
	state.shop_growth.bench = true; state.shop_growth.appraisal.bench_due = 4
	var c := catalog.get_definition("customers",customer_id) as CustomerDefinition
	var v := CustomerVisit.new()
	v.visit_id = "wealthy_ten/4/unit"; v.customer_id = c.id; v.status = "active"; v.arrival = 0; v.expires_at = c.terms.wait_minutes
	v.item = ItemInstance.new(); v.item.instance_id = "item/" + v.visit_id; v.item.definition_id = item_id; v.item.selected_variant_id = variant
	v.transaction_modes.assign([mode]); v.voice = c.persona; v.pawn_terms_id = "sample_three_redeem"
	v.trade.patience = c.patience; v.trade.rounds_left = c.max_quote_rounds
	state.visits.append(v); state.ordinary_selections.append({"visit_id":v.visit_id,"context_id":"wealthy/unit"})
	WealthyCustomers.prepare(state,v)
	return s

func protected_visitors() -> void:
	var state := RunState.create(run_def); state.ghost_catalog = catalog; state.current_night_index = 5
	state.social.nights.append({"night":5,"reputation":100})
	while WealthyCustomers.draw(state.run_seed,5,100,run_def.variety.luxury.profiles).size() != 2: state.run_seed += 1
	var ordinary := {"visit_id":"regular","night":5,"arrival":0,"context_id":"ordinary","person":{"name":"待选客人"}}
	var invited_row := ordinary.duplicate(true); invited_row.visit_id = "old-appointment"; invited_row.person.name = "预约客人"
	state.preparation_history.append({"night":4,"action":"target","visit_ids":["old-appointment"]})
	var story := ordinary.duplicate(true); story.visit_id = "story"; story.seven_role = "story"; story.person.name = "故事客人"
	var familiar := ordinary.duplicate(true); familiar.visit_id = "familiar"; familiar.familiar_reserved = true; familiar.person.name = "熟客"
	var returns := ordinary.duplicate(true); returns.visit_id = "early"; returns.early_redemption = true; returns.person.name = "赎当客人"
	var rows: Array[Dictionary] = [ordinary,invited_row,story,familiar,returns]
	var overlaid := WealthyCustomers.overlay(state,run_def,catalog,rows)
	check(overlaid.filter(func(r: Dictionary) -> bool: return r.get("wealthy",false)).size() == 1,"two selected wealthy visitors reduced to one available seat")
	for row in [invited_row,story,familiar,returns]: check(row in overlaid,"special and deferred appointments protected " + row.visit_id)
	state.cash = 0; state.shop_growth.bench = false
	check(overlaid == WealthyCustomers.overlay(state,run_def,catalog,rows),"no hidden wealth or facility filter")

func complete_appraisal(s: RunSession, v: CustomerVisit, correct := true) -> void:
	var id := v.item.instance_id
	var book := LuxuryAppraisalService.info(s._day.state,v.item)
	s._day.state.shop_growth["knowledge"] = {book.topic:{"night":2}}
	for index in 2:
		check(LuxuryAppraisalService.perform(s._day,"luxury_check",id,str(index)).ok,"physical check")
		check(LuxuryAppraisalService.perform(s._day,"luxury_match",id,"%d/%s" % [index,LuxuryAppraisalService.expected_matches(v.item)[index]]).ok,"reference match")
	check(LuxuryAppraisalService.perform(s._day,"luxury_identity",id,book.identity[v.item.selected_variant_id] if correct else "imitation").ok,"identity draft")
	check(LuxuryAppraisalService.perform(s._day,"luxury_condition",id,book.condition[v.item.selected_variant_id]).ok,"condition draft")
	check(LuxuryAppraisalService.perform(s._day,"luxury_commit",id).ok,"commit separate verdicts")

func all_goods() -> void:
	for cid in run_def.variety.luxury.profiles:
		var customer := catalog.get_definition("customers",cid) as CustomerDefinition
		for iid in customer.item_pool:
			for variant in ["sound","mended","flawed"]:
				for mode in ["pawn","sell"]:
					var s := unit_visit(cid,iid,variant,mode)
					var v := s._day.state.visits[0]
					var item := catalog.get_definition("items",iid) as ItemDefinition
					var reference := WealthyCustomers.reference_price(int(item.base_value),mode)
					check(ReputationService.basis(s._day.state,v) == reference,"fair basis excludes markup and hidden truth")
					s._day.state.shop_growth.appraisal.bench_due = 0
					check(not LuxuryAppraisalService.reason(s._day,"luxury_check",v.item.instance_id,"0").is_empty(),"level one blocked")
					s._day.state.shop_growth.appraisal.bench_due = 4
					check(not LuxuryAppraisalService.reason(s._day,"luxury_commit",v.item.instance_id).is_empty(),"knowledge and checks required")
					complete_appraisal(s,v)
					check(s._day.state.game_minutes == 20 and v.trade.rounds_left == customer.max_quote_rounds,"two checks cost only 20 minutes")
					check(LuxuryAppraisalService.perform(s._day,"luxury_check",v.item.instance_id,"0").ok and s._day.state.game_minutes == 20,"free reread")
					check(s._counter.execute(s._day,"luxury_pressure",v.visit_id).ok,"correct evidence negotiation")
					check(ReputationService.basis(s._day.state,v) == WealthyCustomers.reference_price(item.find_variant(variant).true_value,mode),"observed condition reprices fair basis")
					check(v.trade.reserve_price >= int(WealthyCustomers.trade(s._day.state,v).funding),"funding floor survives evidence")
					var amount := v.trade.reserve_price
					var cash := s._day.state.cash
					check(s._counter.execute(s._day,"pawn" if mode == "pawn" else "offer",v.visit_id,"",amount).ok,"settle at reserve")
					check(s._day.state.cash == cash-amount,"actual principal paid once")
					check(WealthyCustomers.data(s._day.state).transactions.size() == 1,"successful acquisition counted")
					if mode == "pawn":
						var ticket := s._day.state.pawn_tickets[0]
						check(ticket.due_night == 7 and ticket.redemption_amount == amount+ceili(amount*.1),"three nights ten percent")
						check(not s._commerce.sale_reason(s._day,v.item,catalog.get_definition("buyers",run_def.buyer_ids[0])).is_empty(),"pledged never saleable")
					else: check(GoodsExpertise.value(v.item,item) == item.find_variant(variant).true_value,"resale uses actual condition")
	var bad := unit_visit("customer_wealthy_opera","item_luxury_pearl_necklace","sound")
	var visitor := bad._day.state.visits[0]
	complete_appraisal(bad,visitor,false)
	var reserve := visitor.trade.reserve_price
	bad._counter.execute(bad._day,"luxury_pressure",visitor.visit_id)
	check(visitor.trade.patience == 1 and visitor.trade.reserve_price == reserve,"wrong proof costs opera patience without discount")
	check(not bad._counter.reason(bad._day,"luxury_pressure",visitor.visit_id).is_empty(),"proof cannot be retried")

func ad_boundaries() -> void:
	var blocked := second_night()
	blocked._day.state.social.reputation = 80
	check(not OpeningPreparation.reason(blocked._day.state,"advertise").is_empty(),"advertising unavailable at eighty")
	for pair in [[79,3,80],[82,3,82],[80,-1,79],[0,-1,-1],[78,3,80]]:
		var s := fresh_growth(); var state := s._day.state
		state.social.reputation = pair[0]
		WealthyCustomers.data(state).advertisements.append({"night":1,"roll":pair[1],"settled":false,"delta":0})
		ReputationGrowth.settle(state)
		check(state.social.reputation == pair[2],"advertising cap " + str(pair))
		ReputationGrowth.settle(state)
		check(state.social.reputation == pair[2],"ad once only")

func personality_and_cash() -> void:
	for cid in run_def.variety.luxury.profiles:
		var c := catalog.get_definition("customers",cid) as CustomerDefinition
		var s := unit_visit(cid,c.item_pool[0],"sound")
		var v := s._day.state.visits[0]
		var price := v.trade.asking_price; var floor_price := v.trade.reserve_price
		var cash := s._day.state.cash
		check(s._counter.execute(s._day,"pawn",v.visit_id,"",1).ok,"valid rejected quote " + cid)
		check(v.trade.patience == c.patience-1 and v.trade.rounds_left == c.max_quote_rounds-1 and s._day.state.game_minutes == 5,"rejected quote consumes time round and one patience " + cid)
		check(v.trade.reserve_price == floor_price and v.trade.asking_price == maxi(floor_price,price-roundi(WealthyCustomers.trade(s._day.state,v).reference*.05)) and s._day.state.cash == cash,"counteroffer reduces asking only " + cid)
		s = unit_visit(cid,c.item_pool[0],"sound"); v = s._day.state.visits[0]
		complete_appraisal(s,v,false)
		floor_price = v.trade.reserve_price
		check(s._counter.execute(s._day,"luxury_pressure",v.visit_id).ok,"incorrect evidence can be submitted " + cid)
		check(v.trade.patience == c.patience-c.terms.false_pressure_cost and v.trade.reserve_price == floor_price,"profession-specific wrong evidence penalty " + cid)
		s = unit_visit(cid,c.item_pool[0],"flawed"); v = s._day.state.visits[0]
		var before := s.read_state()
		s._day.state.cash = v.trade.reserve_price-1
		var poor := s.read_state()
		check(not s._counter.execute(s._day,"pawn",v.visit_id,"",v.trade.reserve_price).ok and poor == s.read_state(),"insufficient principal never submits a quote " + cid)
		check(s._counter.execute(s._day,"reject",v.visit_id).ok and s._day.state.social.reputation == int(before.social.reputation),"plain refusal never damages reputation " + cid)
	for cid in ["customer_wealthy_factory",WealthyCustomers.COMPRADOR]:
		var c := catalog.get_definition("customers",cid) as CustomerDefinition
		var s := unit_visit(cid,c.item_pool[0],"flawed"); var v := s._day.state.visits[0]
		complete_appraisal(s,v)
		s._counter.execute(s._day,"luxury_pressure",v.visit_id)
		var t := WealthyCustomers.trade(s._day.state,v)
		check(t.funding > t.reference and v.trade.reserve_price == t.funding,"proven imitation still has funding floor " + cid)
		s._counter.execute(s._day,"pawn",v.visit_id,"",int(t.reference))
		check(s._day.state.pawn_tickets.is_empty(),"correct appraisal cannot force an unaffordable funding demand " + cid)

func pawn_lifecycle() -> void:
	var pawns := PawnController.new()
	for final_night in [8,9,10]:
		var s := unit_visit("customer_wealthy_antique","item_luxury_porcelain_vase","mended")
		var state := s._day.state; var v := state.visits[0]
		state.current_night_index = final_night
		v.pawn_terms_id = PawnRedemptionPolicy.DEFAULT
		check(s._counter.execute(s._day,"pawn",v.visit_id,"",v.trade.reserve_price).ok,"late wealthy loan")
		var ticket := state.pawn_tickets[0]
		check(ticket.due_night == final_night+3,"late ticket retains real three-night term")
		state.current_night_index = 10
		check(pawns.maturities(state).is_empty() and v.item.ownership_state == "pledged","ten-night ending never accelerates maturity")
	var s := unit_visit("customer_wealthy_antique","item_luxury_porcelain_vase","mended")
	var state := s._day.state; var v := state.visits[0]
	v.pawn_terms_id = PawnRedemptionPolicy.DEFAULT
	check(s._counter.execute(s._day,"pawn",v.visit_id,"",v.trade.reserve_price).ok,"defaultable wealthy loan")
	var ticket := state.pawn_tickets[0]
	state.current_night_index = 7
	check(PawnReturnService.plan([ticket.to_data()],7,catalog).is_empty(),"absent wealthy owner does not receive a return slot")
	state.phase = &"night_resolution"
	var choices := {ticket.ticket_id:"keep"}
	check(pawns.disposal_reason(state,catalog,choices).is_empty(),"default only processed on true due night")
	var cash := state.cash
	pawns.resolve_maturities(state,run_def.night_minutes,catalog,choices)
	check(ticket.status == "defaulted" and v.item.ownership_state == "owned" and state.cash == cash,"keeping defaulted collateral does not create cash")
	state.phase = &"open"; state.game_minutes = 0
	var sold := false
	for bid in run_def.buyer_ids:
		var buyer := catalog.get_definition("buyers",bid) as BuyerDefinition
		if not s._commerce.sale_reason(s._day,v.item,buyer).is_empty(): continue
		var amount := s._commerce.quote(v.item,buyer)
		if s._commerce.execute(s._day,"sell",v.item.instance_id,bid).ok:
			check(state.cash == cash+amount and v.item.ownership_state == "sold","defaulted luxury sale pays existing buyer valuation")
			sold = true; break
	check(sold,"defaulted luxury connects to an existing buyer")

func milestones() -> void:
	var s := unit_visit("customer_wealthy_silk","item_luxury_embroidery","sound","sell")
	var state := s._day.state; var v := state.visits[0]
	for n in 20:
		v.visit_id = "milestone/%d" % n
		EconomyManager.new().commit(state,-10,v.item.instance_id,"purchase/"+v.visit_id,"acquisition")
		ReputationGrowth.acquired(state,v,"bought")
		ReputationGrowth.acquired(state,v,"bought")
		check(state.social.reputation == (n+1)/10,"milestone threshold " + str(n+1))
	check(WealthyCustomers.data(state).transactions.size() == 20,"duplicate acquisitions excluded")
	ReputationGrowth.acquired(state,v,"redeemed")
	check(WealthyCustomers.data(state).transactions.size() == 20,"redemption excluded")

func natural_play() -> void:
	var s := second_night()
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.execute("prep_advertise").ok and before == s.read_state(),"advertising save failure atomic")
	(s._save as CountingStore).fail = false
	check(s.execute("prep_advertise").ok,"natural ad purchase")
	check(s._day.state.cash == int(before.cash)-30 and PreparationService.count(s._day.state) == 1,"ad cost and preparation")
	check(not s.execute("prep_advertise").ok,"ad once per night")
	check(s.growth_command("learn_knowledge","luxury_watch").ok,"clock knowledge shares preparation")
	check(not s.growth_command("learn_knowledge","luxury_metal").ok,"no third preparation")
	verify(s,"advertisement pending and learned knowledge")
	act(s,"open_shop"); driver.drain(s)
	act(s,"close_shop")
	check(WealthyCustomers.data(s._day.state).advertisements[0].settled,"closing publishes ad outcome")
	fixture(s,"advertisement-closed")
	var tampered := SaveCodec.new().encode(s._day.state,31)
	tampered.shop_growth.luxury.advertisements[0].roll = 99
	check(SaveCodec.new().decode(tampered,run_def,31,catalog,true) == null,"forged advertising rejected")
