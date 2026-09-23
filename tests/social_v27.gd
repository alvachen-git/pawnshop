extends "res://tests/social_relations.gd"

func run() -> void:
	if not setup(): quit(1); return
	price_boundaries()
	military_boundaries()
	coats_rules()
	plaque_rules()
	seeded_coats()
	new_replays()
	preserved_events()
	reply_feedback()
	coat_trade_paths()
	legacy_unchanged()
	print("SOCIAL V27: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state,27)
	var restored := codec.decode(data,s.definition,27,catalog,true)
	check(restored != null,"v27 replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"v27 exact " + label)

func detail_for(s: RunSession, ids: Array) -> String:
	return JSON.stringify({"order":s._day.state.social.contract.get("number", -1), "ids":ids})

func add_coat(s: RunSession, id: String, ownership := "owned") -> ItemInstance:
	var coat := ItemInstance.new()
	coat.instance_id = id; coat.definition_id = CoatProcurement.ITEM
	coat.selected_variant_id = "worn" if id.ends_with("2") else "sound"
	coat.ownership_state = ownership; coat.acquisition_price = 10
	s._day.state.inventory_instances.append(coat)
	return coat

func coats_rules() -> void:
	var s := second_night()
	check(not s._day.state.social.has("favor"), "favor state removed")
	check(SocialRules.config().contracts.size() == 1, "only coat contract")
	check(s.social_command("accept_contract").ok, "coat order accepted")
	var contract: Dictionary = s._day.state.social.contract
	check(contract.quantity == 3 and contract.reward == 50 and contract.delta == 6 and contract.due == 0, "coat terms")
	verify(s, "accept unlimited order")
	var ids: Array = []
	for i in 4: ids.append(add_coat(s, "unit/coat%d" % i).instance_id)
	for selected in [ids.slice(0,2), [ids[0],ids[0],ids[1]], ids]:
		var before := s.read_state()
		check(not s.social_command("deliver", detail_for(s,selected)).ok and s.read_state() == before, "invalid batch atomic")
	s._day.state.inventory_instances.back().ownership_state = "pledged"
	var before := s.read_state()
	check(not s.social_command("deliver", detail_for(s,[ids[0],ids[1],ids[3]])).ok and s.read_state() == before, "pledged excluded atomically")
	var payload := detail_for(s,ids.slice(0,3))
	var cash := s._day.state.cash
	check(s.social_command("deliver",payload).ok, "three coats handed over")
	check(s._day.state.cash == cash + 50 and s._day.state.social.military == 6, "one batch reward")
	check(CoatProcurement.stock(s._day.state).is_empty(), "selected coats sold, pledged remains")
	before = s.read_state()
	check(not s.social_command("deliver",payload).ok and s.read_state() == before, "duplicate batch rejected")
	check(s.social_command("accept_contract").ok, "immediate repeat order")
	check(not s.social_command("deliver",payload).ok, "old order payload rejected")
	s._day.state.current_night_index = 10
	MilitaryService.settle(s._day.state)
	check(not s._day.state.social.contract.is_empty() and s._day.state.social.contract.due == 0, "no expiry after many nights")
	s._day.state.social.pending = {"kind":"closure", "cost":35, "night":10}
	check(not s.social_command("favor").ok, "no favor closure route")
	check(s.social_command("close").ok, "closure accepted")
	check(s._day.state.social.contract.due == 0 and not s.social_command("deliver",payload).ok, "closed order preserved without deadline")
	for score in [-100, 80, 100]:
		s = second_night(); s._day.state.social.military = score
		check(s.social_command("accept_contract").ok and s._day.state.social.contract.id == "coats", "same recovery order at " + str(score))
		check(s.social_command("cancel_contract").ok and s._day.state.social.military == maxi(-100,score-10), "cancel penalty")
		check(s.social_command("decline_contract").ok and s._day.state.social.military == maxi(-100,score-10), "decline neutral")

func active_ordinary(s: RunSession) -> CustomerVisit:
	driver.drain(s)
	if s._day.state.phase == &"pre_open": act(s,"open_shop")
	for i in 80:
		driver.drain(s)
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			if ReputationService.eligible(s._day.state,v): return v
			s.counter_command("reject",v.visit_id)
		else:
			if s._day.state.game_minutes >= 460: break
			s.bell_command("wait")
	return null

func plaque_rules() -> void:
	var s := second_night()
	SocialRules.change(s._day.state,"military",29,"test")
	check(not s._day.state.social.plaque_awarded,"29 no plaque")
	SocialRules.change(s._day.state,"military",1,"test")
	check(s._day.state.social.plaque_awarded,"30 grants plaque")
	var notice_count: int = s._day.state.social.notices.size()
	SocialRules.change(s._day.state,"military",5,"test")
	check(s._day.state.social.notices.size() == notice_count,"no repeat grant")
	SocialRules.change(s._day.state,"military",-200,"test")
	check(s._day.state.social.plaque_awarded,"plaque permanent below zero")
	var v := active_ordinary(s)
	check(v != null,"ordinary test caller")
	if v == null: return
	v.trade.opening_price = 101; v.trade.asking_price = 101; v.trade.reserve_price = 71
	var minute := s._day.state.game_minutes; var rounds := v.trade.rounds_left
	var base := ReputationService.basis(s._day.state,v)
	check(s.counter_command("intimidate",v.visit_id).ok,"intimidation command")
	check(v.trade.asking_price == 91 and v.trade.reserve_price == 64,"ceil both prices independently")
	check(s._day.state.social.reputation == -1 and v.trade.rounds_left == rounds and s._day.state.game_minutes == minute,"behavior cost only")
	check(ReputationService.basis(s._day.state,v) == base,"intimidation does not change reputation basis")
	var before := s.read_state()
	check(not s.counter_command("intimidate",v.visit_id).ok and before == s.read_state(),"no repeat intimidation")
	v.trade.social_offer_mode = "pawn"
	check(not s.counter_command("intimidate",v.visit_id).ok,"switching to pawn cannot repeat")
	var customer := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
	var terms := catalog.get_definition("pawn_terms",VarietyService.terms_for(v,customer)) as PawnTermsDefinition
	check(ReputationService.basis(s._day.state,v) == maxi(1,roundi(base*terms.loan_ratio)),"pawn original basis")
	check(s.counter_command("offer",v.visit_id,"",122).ok,"generous payment after threat")
	check(s._day.state.social.reputation == 1 and v.voice.completed.contains("厚道"),"high payment feedback reconciled with threat")
	for purpose in ["display_buyer","husband_meeting"]:
		v.purpose = purpose
		check(not MilitaryPlaque.reason(s._day.state,v).is_empty(),"special purpose excluded")
	v.purpose = ""; v.night_policy = "one_quote"
	check(not MilitaryPlaque.reason(s._day.state,v).is_empty(),"night rule excluded")
	s = second_night(); SocialRules.change(s._day.state,"military",100,"test")
	check(s._day.state.social.plaque_awarded,"cross threshold grants")
	v = active_ordinary(s)
	if v != null:
		v.trade.asking_price = 1; v.trade.reserve_price = 1
		check(s.counter_command("intimidate",v.visit_id).ok and v.trade.asking_price == 1 and v.trade.reserve_price == 1,"minimum one yuan")
		check(s.counter_command("reject",v.visit_id).ok and s._day.state.social.reputation == -1,"no sale still pays behavior cost")

func seeded_coats() -> void:
	var seen := 0
	var total := 0
	for seed_value in 100:
		var s := fresh_growth(seed_value)
		var before := JSON.stringify(s.read_state())
		var a := OpeningPreparation.plan(s._day.state,run_def,catalog)
		var b := OpeningPreparation.plan(s._day.state,run_def,catalog)
		check(a == b and before == JSON.stringify(s.read_state()),"repeat plan read deterministic " + str(seed_value))
		for row in a:
			if row.item_id == CoatProcurement.ITEM:
				seen += 1
				check(ReputationService.ordinary(row) and not row.has("seven_role") and row.variant_id in ["sound","worn"],"coats only ordinary replaceable positions")
			if ReputationService.ordinary(row) and not row.has("seven_role"): total += 1
	check(seen > 0 and float(seen)/total > .15 and float(seen)/total < .25,"seed distribution near 20 percent")
	print("COAT DISTRIBUTION: %d / %d" % [seen,total])

# All fixtures and replay checks below are produced through real journaled play.
func delivery_session() -> RunSession:
	var picked := -1
	for seed_value in 1500:
		var probe := fresh_growth(seed_value)
		var plan := OpeningPreparation.plan(probe._day.state,run_def,catalog)
		if plan.filter(func(row: Dictionary) -> bool: return row.night == 1 and row.item_id == CoatProcurement.ITEM and "sell" in row.transaction_modes).size() >= 3:
			picked = seed_value; break
	check(picked >= 0,"seed with three naturally offered coats")
	var s := fresh_growth(maxi(0,picked))
	driver.drain(s); act(s,"open_shop"); driver.drain(s)
	for step in 100:
		driver.drain(s)
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			if v.item.definition_id == CoatProcurement.ITEM:
				if CoatProcurement.stock(s._day.state).is_empty(): fixture(s,"cotton")
				check(s.counter_command("offer",v.visit_id,"",v.trade.reserve_price).ok,"buy real cotton coat")
			else: check(s.counter_command("reject",v.visit_id).ok,"pass non-coat visitor")
		else:
			if s._day.state.game_minutes >= 450: break
			s.bell_command("wait")
	finish_night(s); driver.drain(s)
	if s._day.state.social.pending.get("kind","") == "supply": s.social_command("decline_supply")
	check(CoatProcurement.stock(s._day.state).size() >= 3,"three acquired coats in stock")
	check(s.social_command("accept_contract").ok,"fixture accepted coat order")
	return s

func new_replays() -> void:
	var original := run_def
	run_def = catalog.get_definition("runs","social_preview_delivery")
	var s := delivery_session()
	verify(s,"three acquired coats and order")
	var ids: Array = CoatProcurement.stock(s._day.state).slice(0,3).map(func(item: ItemInstance) -> String:return item.instance_id)
	check(s.social_command("deliver",detail_for(s,ids)).ok,"real batch command")
	check(s._day.state.social.military == 30 and s._day.state.social.plaque_awarded,"real delivery grants plaque")
	verify(s,"batch and plaque awarded")
	check(s.social_command("accept_contract").ok,"real repeat")
	act(s,"open_shop")
	var v := active_ordinary(s)
	if v != null:
		check(s.counter_command("intimidate",v.visit_id).ok,"real intimidation")
		verify(s,"active negotiation threat")
		var encoded := SaveCodec.new().encode(s._day.state,27)
		var restored := SaveCodec.new().decode(encoded,run_def,27,catalog,true)
		check(restored != null and MilitaryPlaque.used(restored,CustomerManager.new().active(restored)),"reload keeps threat used")
		for key in ["plaque_awarded","intimidations"]:
			var forged := encoded.duplicate(true)
			forged.social[key] = false if key == "plaque_awarded" else []
			check(SaveCodec.new().decode(forged,run_def,27,catalog,true) == null,"forged reward rejected " + key)
		var store: CountingStore = s._save
		check(s.social_command("cancel_contract").ok,"cancel in business")
		check(s.social_command("accept_contract").ok,"accept during business")
		store.fail = true
		var before := s.read_state()
		check(not s.social_command("cancel_contract").ok and s.read_state() == before,"save failure rollback")
	run_def = original

func fixture_session(stage: String) -> RunSession:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/social-relations/" + stage + ".json"))
	var definition := catalog.get_definition("runs",data.run_definition_id) as RunDefinition
	var store := CountingStore.new(); store.origin = data.ghost_origin.duplicate(true)
	var s := RunSession.new(definition,27,store,catalog)
	s._day.state = SaveCodec.new().decode(data,definition,27,catalog,true)
	return s

func preserved_events() -> void:
	for command in ["pay","close"]:
		var s := fixture_session("closure")
		var cost: int = s._day.state.social.pending.cost
		var cash := s._day.state.cash
		check(not s.social_command("favor").ok,"historical favor command rejected")
		check(s.social_command(command).ok,"closure route " + command)
		check(SocialRules.closed(s._day.state) == (command == "close"),"closure restriction")
		check(s._day.state.cash == cash - (cost if command == "pay" else 0),"closure cash")
		verify(s,"closure " + command)
	for command in ["claim_return","claim_compensate","claim_military"]:
		var s := fixture_session("claim")
		check(s.social_command(command).ok,"claim route " + command)
		verify(s,command)
	var s := fixture_session("claim")
	s._day.state.social.military = 19
	check(not s.social_command("claim_military").ok,"claim assistance unavailable at 19")
	s._day.state.social.military = 20
	check(s.social_command("claim_military").ok,"claim assistance at 20 without favor")
	s = fixture_session("supply")
	var score: int = s._day.state.social.military
	check(s.social_command("decline_supply").ok and s._day.state.social.military == score,"decline supply neutral")
	verify(s,"decline special goods")

func reply_feedback() -> void:
	var op := {"before":{"counter":{"visual":{"customer_name":"测试客人","asking":90,"intimidated":true,"original_purchase_basis":100,"original_pawn_basis":60,"social_feedback":true},"trade":{"pawn_asking":54}}}}
	for entry in [["acquisition",90,"intimidated"],["acquisition",120,"generous_after_threat"],["pawn_loan",54,"intimidated"],["pawn_loan",72,"generous_after_threat"]]:
		var reply := CustomerReplyModel.build({"kind":entry[0],"amount":-entry[1]},op)
		check(reply.style == entry[2],"receipt threat feedback reconciles " + str(entry[1]))

func coat_trade_paths() -> void:
	var s := fixture_session("cotton")
	var v := s._counter.customers.active(s._day.state)
	check(v != null and v.item.definition_id == CoatProcurement.ITEM,"live coat fixture")
	if v == null: return
	check(s.counter_command("appraise",v.visit_id,"observe").ok,"coat observe")
	check(s.counter_command("appraise",v.visit_id,"inspect").ok,"coat inspect")
	check(v.item.selected_variant_id in v.item.revealed_clue_ids,"coat condition actually revealed")
	check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"coat ordinary purchase")
	verify(s,"coat appraisal and acquisition")
	for i in 20:
		driver.drain(s)
		var active := s._counter.customers.active(s._day.state)
		if active == null: break
		check(s.counter_command("reject",active.visit_id).ok,"clear counter before resale")
	var cash := s._day.state.cash
	check(s.sell_batch("buyer_recycler",[v.item.instance_id]).ok,"coat ordinary resale")
	check(v.item.ownership_state == "sold" and s._day.state.cash > cash,"resale ownership and income")
	verify(s,"coat resale")
	s = second_night()
	v = active_ordinary(s)
	if v == null: return
	v.item.definition_id = CoatProcurement.ITEM; v.item.selected_variant_id = "worn"
	v.customer_id = "customer_citizen"; v.transaction_modes.assign(["sell","pawn"])
	var customer := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
	var terms := catalog.get_definition("pawn_terms",VarietyService.terms_for(v,customer)) as PawnTermsDefinition
	SocialRules.change(s._day.state,"military",30,"test")
	# Pricing already consumed its nightly negative allowance; intimidation is separate.
	s._day.state.social.trades.append({"night":2,"delta":-6,"visit_id":"cap/fixture"})
	v.trade.opening_price = 15; v.trade.asking_price = 15; v.trade.reserve_price = 10
	check(s.counter_command("intimidate",v.visit_id).ok and s._day.state.social.reputation == -1,"fear still costs after price cap")
	var amount := maxi(1,roundi(9*terms.loan_ratio))
	check(s.counter_command("pawn",v.visit_id,"",amount).ok,"cotton pawn uses once-discounted threshold")
	check(v.item.ownership_state == "pledged" and v.item not in CoatProcurement.stock(s._day.state),"pawned cotton never procurement stock")
	check(s._day.state.social.reputation == -1,"price cap does not suppress or repeat fear charge")
