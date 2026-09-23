extends "res://tests/watch_economy.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_negotiation_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v35 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,35,store,catalog)

func fixture35(variant := "sound", damage := "intact", operation := "stable", mode := "sell", personality := "easy", urgent := false) -> RunSession:
	var s := watch_fixture(variant,damage,operation,mode); var v: CustomerVisit = s._day.state.visits[0]
	var o := WatchEconomy.owner(s._day.state,v); o.belief = "sound"; o.rate = 100; o.urgent = urgent; o.skill = "ordinary"
	WatchEconomy.reprice(s._day.state,v,true); WatchNegotiation.prepare(s._day.state,v)
	var d := WatchNegotiation.data(s._day.state,v); d.personality = personality
	for part in d.rolls: d.rolls[part] = 0
	return s

func hear(s: RunSession, tier := 0) -> void:
	var v: CustomerVisit = s._day.state.visits[0]; var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,"2").ok,"apparatus available")
	if tier > 0: check(command(s,id,{"op":"wind"}).ok,"wind")
	for pose in (["flat","vertical"] if tier == 2 else ["flat"]):
		check(command(s,id,{"op":"pose","pose":pose}).ok,"pose")
		check(command(s,id,{"op":"listen_start","clip":WatchAppraisal.key(WatchAppraisal.row(s._day.state,id))}).ok,"click records immediately")
	check(WatchAppraisal.row(s._day.state,id).listened.is_empty(),"completion not required or recorded")

func say(s: RunSession, claims: Dictionary) -> ActionResult:
	return s.counter_command("watch_claim",s._day.state.visits[0].visit_id,JSON.stringify(claims))

func run() -> void:
	if not setup(): quit(1); return
	# Every truth / damage / operation combination preserves value under persuasion.
	for variant in ["sound","mended","flawed"]:
		for damage in ["intact","minor","major"]:
			for operation in ["stable","positional","stopping"]:
				var s := fixture35(variant,damage,operation); var v: CustomerVisit = s._day.state.visits[0]
				var facts := v.item.goods.duplicate(true); var price := v.trade.asking_price
				hear(s)
				check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"exterior")
				check(say(s,{"identity":"imitation","repair":"altered","running":"stopping","exterior":"observed"}).ok,"four combined claims")
				check(v.item.goods == facts and v.trade.asking_price <= price,"belief cannot change facts or raise price")
				check(WatchNegotiation.data(s._day.state,v).claims.size() == 4,"all opportunities consumed")
				for buyer_id in run_def.buyer_ids:
					var buyer := catalog.get_definition("buyers",buyer_id) as BuyerDefinition
					check(s._commerce.base_quote(v.item,buyer) == maxi(1,roundi(facts.watch_value.actual*buyer.value_multiplier)),"resale uses immutable actual value")
	# Enumerate the full probability table and both sides of each threshold.
	for skill_index in 3:
		for tier in 3:
			for truthful in [false,true]:
				var expected: int = ([[60,70,80],[85,90,95],[100,100,100]] if truthful else [[20,55,85],[10,35,65],[5,20,40]])[tier][skill_index]
				for roll in [expected-1,expected]:
					if roll > 99: continue
					var s := fixture35(); var v: CustomerVisit = s._day.state.visits[0]
					hear(s,tier); var w := WatchAppraisal.row(s._day.state,v.item.instance_id)
					w.spots = [] if tier == 0 else [0] if tier == 1 else [0,1]
					WatchEconomy.owner(s._day.state,v).skill = ["expert","ordinary","novice"][skill_index]
					var d := WatchNegotiation.data(s._day.state,v)
					var claims := {"identity":"original" if truthful else "imitation","repair":"intact" if truthful else "altered","running":"stable" if truthful else "stopping"}
					for part in claims:
						d.rolls[part] = roll
						check(WatchNegotiation.chance(s._day.state,v,part,claims[part]) == expected,"full probability table")
					var patience := v.trade.patience; var rep: int = s._day.state.social.reputation
					check(say(s,claims).ok,"threshold submission")
					for part in claims: check(d.responses.back().parts[part].accepted == (roll < expected),"fixed threshold outcome")
					check(v.trade.patience == patience-(1 if roll >= expected else 0),"one patience loss per submission")
					check(s._day.state.social.reputation == rep- (2 if not truthful and roll >= expected else 0),"only caught false statement penalized")
	for personality in ["easy","careful","firm"]:
		for urgent in [false,true]:
			var s := fixture35("sound","intact","positional","sell",personality,urgent); var v: CustomerVisit = s._day.state.visits[0]
			var before := v.trade.asking_price; hear(s)
			check(say(s,{"running":"positional"}).ok,"believe fault")
			var target := roundi(280*1.1*(.85 if urgent else 1.0))
			var fraction: float = {"easy":1.0,"careful":.75 if urgent else .5,"firm":.25 if urgent else 0.0}[personality]
			check(v.trade.asking_price == roundi(before-(before-target)*fraction),"anchored concession "+personality)
			if not urgent: check(v.trade.asking_price == {"easy":308,"careful":347,"firm":385}[personality],"specified rounding examples")
	# Combined and split claims share fixed acceptance and the same final price.
	var outcomes := []
	for order in [["identity","repair","running"],["running","repair","identity"],["combined"]]:
		var s := fixture35("mended","minor","stopping","sell","careful"); hear(s)
		var claims := {"identity":"imitation","repair":"altered","running":"stopping"}
		for part in order: check(say(s,claims if part == "combined" else {part:claims[part]}).ok,"order independent submission")
		var v: CustomerVisit = s._day.state.visits[0]; var d := WatchNegotiation.data(s._day.state,v)
		outcomes.append([d.belief,d.claims,v.trade.asking_price,v.trade.reserve_price])
	check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2],"split combined and reversed order agree")
	var exterior_session := fixture35("sound","minor"); var exterior_visit: CustomerVisit = exterior_session._day.state.visits[0]
	var exterior_price := exterior_visit.trade.asking_price
	check(exterior_session.fan_command("luxury_exterior",exterior_visit.item.instance_id).ok,"exterior only check")
	var minutes := exterior_session._day.state.game_minutes; var rounds := exterior_visit.trade.rounds_left
	check(say(exterior_session,{"exterior":"observed"}).ok and exterior_visit.trade.asking_price == exterior_price,"already priced exterior is not discounted twice")
	check(exterior_session._day.state.game_minutes == minutes+5 and exterior_visit.trade.rounds_left == rounds-1,"submission five minutes and one round")
	check(ReputationService.basis(exterior_session._day.state,exterior_visit) == 280,"real acknowledged exterior updates public basis")
	var s := fixture35(); var v: CustomerVisit = s._day.state.visits[0]
	check(not say(s,{}).ok and not say(s,{"running":"stopping"}).ok and not say(s,{"exterior":"observed"}).ok,"empty and unavailable claims rejected")
	check(not s.counter_command("watch_bluff",v.visit_id).ok and not s.counter_command("luxury_pressure",v.visit_id).ok,"old routes unavailable only in new version")
	hear(s); var w := WatchAppraisal.row(s._day.state,v.item.instance_id)
	var clip_count: int = w.started.size(); check(command(s,v.item.instance_id,{"op":"listen_start","clip":WatchAppraisal.key(w)}).ok and w.started.size() == clip_count,"duplicate listen no extra evidence")
	check(command(s,v.item.instance_id,{"op":"draft","identity":"original","condition":"unsure","running":"stable"}).ok,"private draft")
	check(command(s,v.item.instance_id,{"op":"seal"}).ok,"partial seal")
	check(say(s,{"running":"stopping"}).ok,"public change of story")
	var d := WatchNegotiation.data(s._day.state,v)
	check(d.belief.running == "stopping" and w.running == "stable" and v.item.goods.watch_value.actual == 500,"false belief separate from notes and truth")
	s._negotiation_reactions = NegotiationReactions.new()
	check(s.counter_model().trade.reactions.size() == 1 and s.counter_model().trade.reactions[0].message == d.responses.back().message,"stored reactions visible without live presentation history")
	check(ReputationService.basis(s._day.state,v) == 350 and s.counter_model().trade.visual.estimate == "25–500","false belief cannot change public price basis or estimate")
	var baseline := s.read_state(); check(not say(s,{"running":"stable"}).ok and baseline == s.read_state(),"same topic cannot retry even after changed story")
	check(not command(s,v.item.instance_id,{"op":"draft","identity":"imitation","condition":"altered","running":"stopping"}).ok,"sealed notes immutable")
	var copied := RunSnapshot.copy(s._day.state)
	check(WatchNegotiation.data(copied,copied.visits[0]) == d,"snapshot stores beliefs rolls and spent chances")
	# Dishonesty penalty only once, and shared daily cap.
	s = fixture35(); v = s._day.state.visits[0]; d = WatchNegotiation.data(s._day.state,v); d.rolls.identity = 99; d.rolls.repair = 99
	var reputation: int = s._day.state.social.reputation
	check(say(s,{"identity":"imitation"}).ok and say(s,{"repair":"altered"}).ok,"two separate rejections")
	check(s._day.state.social.reputation == reputation-2,"one penalty per visitor")
	s = fixture35(); v = s._day.state.visits[0]; WatchNegotiation.data(s._day.state,v).rolls.identity = 99
	s._day.state.social.trades.append({"visit_id":"earlier","night":s._day.state.current_night_index,"delta":-5}); reputation = s._day.state.social.reputation
	check(say(s,{"identity":"imitation"}).ok and s._day.state.social.reputation == reputation-1,"daily penalty cap")
	# Low initial belief is not automatically raised by correct identification.
	s = fixture35(); v = s._day.state.visits[0]; WatchEconomy.owner(s._day.state,v).belief = "flawed"
	WatchEconomy.reprice(s._day.state,v,true); WatchNegotiation.prepare(s._day.state,v); WatchNegotiation.data(s._day.state,v).rolls.identity = 0
	var low := v.trade.asking_price; check(say(s,{"identity":"original"}).ok and v.trade.asking_price == low,"correct claim cannot raise initial low price")
	# Explicitly acknowledged facts contradict a later assertion.
	s = fixture35(); v = s._day.state.visits[0]; WatchNegotiation.data(s._day.state,v).facts.identity = "original"
	check(say(s,{"identity":"imitation"}).ok and not WatchNegotiation.data(s._day.state,v).responses.back().parts.identity.accepted,"known fact always blocks contradictory story")
	s = fixture35("flawed","major","stopping","pawn"); v = s._day.state.visits[0]; hear(s)
	check(say(s,{"identity":"imitation","running":"stopping"}).ok and v.trade.reserve_price == 163 and v.trade.asking_price == 163,"pawn funding floor")
	check(s.counter_command("pawn",v.visit_id,"",100).ok and v.item.ownership_state != "pledged","cannot borrow beneath floor")
	# Transactions roll back complete state on disk error; invalid deadlines consume nothing.
	for action in ["listen","claim"]:
		s = fixture35(); v = s._day.state.visits[0]; hear(s); MarketService.sync(s._day.state,run_def)
		baseline = s.read_state(); (s._save as CountingStore).fail = true
		var result := command(s,v.item.instance_id,{"op":"listen_start","clip":"arrival/flat"}) if action == "listen" else say(s,{"identity":"imitation"})
		check(not result.ok and baseline == s.read_state(),"failed-save entire rollback "+action)
	s = fixture35(); v = s._day.state.visits[0]; v.expires_at = 4; baseline = s.read_state()
	check(not say(s,{"identity":"imitation"}).ok and baseline == s.read_state(),"time failure preserves opportunity")
	# Other nine goods retain their old evidence route.
	for cid in run_def.variety.luxury.profiles:
		for iid in (catalog.get_definition("customers",cid) as CustomerDefinition).item_pool:
			if iid == WatchAppraisal.ITEM: continue
			s = unit_visit(cid,iid,"mended"); equip(s); v = s._day.state.visits[0]
			check(not WatchNegotiation.handles(s._day.state,v.item),"other goods excluded")
			seal_stage(s,v,3); check(s.counter_command("luxury_pressure",v.visit_id).ok,"other goods original evidence")
	# Independent keyed generation is stable and has expected personality frequencies.
	s = fixture35(); v = s._day.state.visits[0]; var counts := {"easy":0,"careful":0,"firm":0}
	for seed_value in 10000:
		s._day.state.run_seed = seed_value; WatchNegotiation.prepare(s._day.state,v)
		d = WatchNegotiation.data(s._day.state,v); counts[d.personality] += 1
		if seed_value < 20:
			var saved := d.duplicate(true); WatchNegotiation.prepare(s._day.state,v); check(saved == WatchNegotiation.data(s._day.state,v),"fixed random regeneration")
	for part in counts: check(absf(counts[part]/10000.0-{"easy":.35,"careful":.45,"firm":.2}[part]) < .025,"personality frequency "+part)
	print("WATCH NEGOTIATION: %d passes, %d failures; personalities %s" % [passes,failures,counts])
	quit(0 if failures == 0 else 1)
