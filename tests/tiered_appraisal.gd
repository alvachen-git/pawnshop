extends "res://tests/wealthy_customers.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/tiered_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v32 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,32,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var data := codec.encode(s._day.state,32)
	var restored := codec.decode(data,run_def,32,catalog,true)
	check(restored != null,"v32 replay " + label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay " + label)

func equip(s: RunSession, tier := 3) -> void:
	s._day.state.shop_growth["precision"] = {"due":1 if tier == 3 else 0,"kits":TieredAppraisal.KITS.keys()}
	s._day.state.shop_growth["knowledge"] = {}
	for topic in ShopKnowledgeService.TOPICS: s._day.state.shop_growth.knowledge[topic] = {"night":2}
	s._day.state.shop_growth.appraisal.tools = true

func seal_stage(s: RunSession, v: CustomerVisit, tier: int, wrong := false) -> void:
	var id := v.item.instance_id
	check(s.fan_command("luxury_begin",id,str(tier)).ok,"start stage")
	for index in 2:
		var point := [0.25 if index == 0 else 0.75,0.5]
		for side in ["object","reference"]: check(s.fan_command("luxury_mark",id,JSON.stringify({"tier":tier,"index":index,"side":side,"point":point})).ok,"circle draft saves immediately")
		check(s.fan_command("luxury_pair",id,JSON.stringify({"tier":tier,"index":index,"note":TieredAppraisal.expected(v.item,tier)[index],"object":point,"reference":point})).ok,"pair point")
	var book := LuxuryAppraisalService.info(s._day.state,v.item)
	check(s.fan_command("luxury_select",id,JSON.stringify({"tier":tier,"identity":"unsure" if wrong else book.identity[v.item.selected_variant_id],"condition":book.condition[v.item.selected_variant_id]})).ok,"select")
	check(s.fan_command("luxury_seal",id,str(tier)).ok,"seal")

func run() -> void:
	if not setup(): quit(1); return
	var combinations := 0
	for cid in run_def.variety.luxury.profiles:
		for iid in (catalog.get_definition("customers",cid) as CustomerDefinition).item_pool:
			for variant in ["sound","mended","flawed"]:
				for damage in ["intact","minor","major"]:
					for hidden in [false,true]:
						var s := unit_visit(cid,iid,variant); var v: CustomerVisit = s._day.state.visits[0]
						v.item.goods.precision = {"damage":damage,"hidden":hidden}; equip(s)
						var definition := catalog.get_definition("items",iid) as ItemDefinition
						var value := maxi(1,roundi(definition.find_variant(variant).true_value*TieredAppraisal.RETAIN[damage]/100.0))
						check(GoodsExpertise.value(v.item,definition) == value,"sale value includes exterior")
						check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"basic check")
						check(s._day.state.game_minutes == 5,"basic costs five")
						check(s.fan_command("luxury_exterior",v.item.instance_id).ok and s._day.state.game_minutes == 5,"basic repeat free")
						seal_stage(s,v,2)
						check(s._day.state.game_minutes == 15,"level two costs ten including free notes")
						check(TieredAppraisal.correct(s._day.state,v.item,2) == not hidden,"hidden ambiguity even for originals")
						check(not s.fan_command("luxury_pair",v.item.instance_id,'{"tier":2,"index":0,"note":"same","object":[0.25,0.5],"reference":[0.25,0.5]}').ok,"sealed stage immutable")
						seal_stage(s,v,3)
						check(s._day.state.game_minutes == 25 and TieredAppraisal.correct(s._day.state,v.item,3),"deep adds ten and provides evidence")
						check(s.fan_command("luxury_begin",v.item.instance_id,"3").ok and s._day.state.game_minutes == 25,"deep repeat free")
						check(s.counter_command("luxury_pressure",v.visit_id).ok,"combined evidence")
						check(WealthyCustomers.trade(s._day.state,v).value == value,"combined evidence recomputes value")
						check(v.trade.reserve_price >= WealthyCustomers.trade(s._day.state,v).funding,"funding floor retained")
						check(not s.counter_command("luxury_pressure",v.visit_id).ok,"no duplicate evidence")
						var saved := RunSnapshot.copy(s._day.state)
						check(GhostSaveCodec.same(saved.to_read_model(),JSON.parse_string(JSON.stringify(s.read_state()))),"all 180 snapshots survive JSON precision")
						var traits: Dictionary = v.item.goods.precision.duplicate(true)
						TieredAppraisal.attach(saved,saved.visits[0].item,v.visit_id)
						check(saved.visits[0].item.goods.precision == traits,"restore never redraws exterior or difficulty")
						combinations += 1
	check(combinations == 180,"all 180 combinations")
	boundaries()
	distribution_precision()
	natural_facilities()
	pawn_lifecycle()
	extra_edges()
	print("TIERED V32: %d combinations, %d passes, %d failures" % [combinations,passes,failures])
	quit(0 if failures == 0 else 1)

func boundaries() -> void:
	var s := unit_visit("customer_wealthy_antique","item_luxury_porcelain_vase","mended")
	var v: CustomerVisit = s._day.state.visits[0]
	v.item.goods.precision = {"damage":"minor","hidden":true}
	s._day.state.shop_growth.bench = false; s._day.state.shop_growth.appraisal.bench_due = 0
	check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"no equipment basic")
	check(not s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"equipment gate")
	check(s.counter_command("luxury_pressure",v.visit_id).ok,"basic evidence alone")
	check(WealthyCustomers.trade(s._day.state,v).value == 480,"600 minor becomes 480")
	s._day.state.shop_growth.bench = true; s._day.state.shop_growth.appraisal.bench_due = 1; equip(s)
	seal_stage(s,v,3)
	check(s._day.state.game_minutes == 30,"direct deep costs twenty after basic and pressure")
	check(s.counter_command("luxury_pressure",v.visit_id).ok,"new deep evidence")
	check(WealthyCustomers.trade(s._day.state,v).value == 240,"repair 300 * .8, not repeated discount")
	var prior := s.read_state(); (s._save as CountingStore).fail = true
	check(not s.fan_command("luxury_exterior",v.item.instance_id).ok or s.read_state().cash == prior.cash,"no repeat charge")
	s = unit_visit("customer_wealthy_factory","item_luxury_gold_watch","flawed"); v = s._day.state.visits[0]; equip(s)
	MarketService.sync(s._day.state,run_def) # Keep the constructed night's market consistent before snapshotting.
	var before := s.read_state(); (s._save as CountingStore).fail = true
	var failed := s.fan_command("luxury_begin",v.item.instance_id,"3")
	check(not failed.ok and before == s.read_state(),"failed write restores time and evidence")
	(s._save as CountingStore).fail = false
	s._day.state.game_minutes = v.expires_at-20
	before = s.read_state()
	check(not s.fan_command("luxury_begin",v.item.instance_id,"3").ok and before == s.read_state(),"deadline equal rejected without time")

func distribution_precision() -> void:
	var counts := {"intact":0,"minor":0,"major":0}; var hidden := 0
	var state := RunState.create(run_def); state.ghost_catalog = catalog
	for seed_value in 10000:
		state.run_seed = seed_value*7919
		var item := ItemInstance.new(); item.definition_id = "item_luxury_gold_watch"
		TieredAppraisal.attach(state,item,"fixed/visit")
		counts[item.goods.precision.damage] += 1
		if item.goods.precision.hidden: hidden += 1
	check(abs(counts.intact-6000)<200 and abs(counts.minor-3000)<200 and abs(counts.major-1000)<200,"damage distribution")
	check(abs(hidden-3000)<200,"hidden distribution independent")

func natural_facilities() -> void:
	var s := second_night()
	verify(s,"genuine second night")
	check(s.growth_command("build","bench").ok,"natural first bench")
	check(s.growth_command("bench_two").ok,"natural second bench commission")
	verify(s,"construction saves")
	# Construction and purchases are separately exercised at exact boundaries.
	var unit := fresh_growth(); var state := unit._day.state
	state.phase = &"pre_open"; state.current_night_index = 4; state.pending_event_id = ""; state.social.pending.clear(); state.social.intro_step = -1
	state.shop_growth.bench = true; state.shop_growth.appraisal.bench_due = 4; state.cash = 1000
	check(unit.growth_command("bench_three").ok and FanAppraisalService.bench_level(state) == 2,"level three two-night construction")
	check(not unit.growth_command("bench_three").ok,"no repeated building charge")
	state.current_night_index = 6
	check(FanAppraisalService.bench_level(state) == 3,"level three completion")
	check(unit.growth_command("precision_kit","display").ok and FanAppraisalService.data(state).tools,"shared fan tools")
	check(not unit.growth_command("fan_tools").ok,"no repurchase via legacy alias")
	check(unit.growth_command("precision_kit","optics").ok,"deep optics")
	check(not unit.growth_command("precision_kit","metal").ok,"preparation cap")

func extra_edges() -> void:
	var original := run_def._variety.duplicate(true)
	run_def._variety.tiered_appraisal.erase("item_luxury_silver_service")
	check(not LuxuryContentValidator.validate(catalog).is_empty(),"missing tenth item rejected")
	run_def._variety = original.duplicate(true)
	run_def._variety.tiered_appraisal.item_luxury_embroidery.deep_kit = "missing"
	check(not LuxuryContentValidator.validate(catalog).is_empty(),"unknown kit rejected")
	run_def._variety = original
	for cid in run_def.variety.luxury.profiles:
		var customer := catalog.get_definition("customers",cid) as CustomerDefinition
		var s := unit_visit(cid,customer.item_pool[0],"flawed"); var v := s._day.state.visits[0]; equip(s)
		v.item.goods.precision = {"damage":"intact","hidden":false}
		check(s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"wrong-proof setup")
		for index in 2:
			check(s.fan_command("luxury_pair",v.item.instance_id,JSON.stringify({"tier":2,"index":index,"note":"same","object":[.25 if index == 0 else .75,.5],"reference":[.25 if index == 0 else .75,.5]})).ok,"wrong draft allowed")
		check(s.fan_command("luxury_select",v.item.instance_id,'{"tier":2,"identity":"original","condition":"intact"}').ok,"wrong conclusion allowed")
		check(s.fan_command("luxury_seal",v.item.instance_id,"2").ok,"no instant correctness feedback")
		var before: int = WealthyCustomers.trade(s._day.state,v).reference
		check(s.counter_command("luxury_pressure",v.visit_id).ok,"wrong argument heard")
		check(v.trade.patience == customer.patience-customer.terms.false_pressure_cost and before == WealthyCustomers.trade(s._day.state,v).reference,"each profession penalizes wrong evidence, no hidden-price deduction")
		check(not s.counter_command("luxury_pressure",v.visit_id).ok,"failed evidence cannot be retried")
		# Fresh unit: right ordinary evidence, then deeper confirmation adds no new discount.
		s = unit_visit(cid,customer.item_pool[0],"mended"); v = s._day.state.visits[0]; equip(s)
		v.item.goods.precision = {"damage":"minor","hidden":false}
		seal_stage(s,v,2)
		check(s.counter_command("luxury_pressure",v.visit_id).ok,"normal second tier enough")
		before = WealthyCustomers.trade(s._day.state,v).value
		seal_stage(s,v,3)
		check(not s.counter_command("luxury_pressure",v.visit_id).ok and WealthyCustomers.trade(s._day.state,v).value == before,"deep confirmation cannot double discount")
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"late exterior")
		check(s.counter_command("luxury_pressure",v.visit_id).ok,"late exterior is new evidence")
		check(WealthyCustomers.trade(s._day.state,v).value == roundi(before*.8),"exterior after identity uses actual proven base")
	var s := unit_visit("customer_wealthy_factory","item_luxury_gold_watch","sound"); var v := s._day.state.visits[0]; equip(s)
	s._day.state.shop_growth.knowledge.clear()
	check(TieredAppraisal.reason(s._day,"luxury_begin",v.item.instance_id,"3").contains("钟表知识"),"knowledge needed at both levels")
	equip(s); s._day.state.shop_growth.precision.kits.erase("clock")
	check(TieredAppraisal.reason(s._day,"luxury_begin",v.item.instance_id,"3").contains("钟表开验具"),"deep kit cannot replace base kit")
	equip(s); check(s.fan_command("luxury_begin",v.item.instance_id,"3").ok,"direct deep")
	check(s._day.state.game_minutes == 20 and not TieredAppraisal.stage(s._day.state,v.item.instance_id,2).is_empty(),"direct deep pays twenty and includes lower tier")
	for detail in ['{"tier":2,"index":0,"note":"same","object":[-1,.5],"reference":[.25,.5]}','{"tier":2.5}','{"tier":2,"index":7}','{"tier":2,"index":0,"note":"same","object":[1.1,0.5],"reference":[0.25,0.5]}']:
		var before := s.read_state()
		check(not s.fan_command("luxury_pair",v.item.instance_id,detail).ok and s.read_state() == before,"invalid circle payload is atomic")
	# A tier-three bench retains fan knowledge/tool checks and ordinary efficiency.
	check(FanAppraisalService.bench_level(s._day.state) == 3,"tier-three includes previous tiers")
	var state := s._day.state
	state.phase = &"pre_open"; state.pending_event_id = ""; state.social.pending.clear(); state.current_night_index = 6
	state.shop_growth.precision.kits.erase("metal"); MarketService.sync(state,run_def)
	var before := s.read_state(); (s._save as CountingStore).fail = true
	check(not s.growth_command("precision_kit","metal").ok and s.read_state() == before,"failed purchase rolls back cash kit ledger preparation")
	(s._save as CountingStore).fail = false; state = s._day.state; state.cash = 39; before = s.read_state()
	check(not s.growth_command("precision_kit","metal").ok and before == s.read_state(),"insufficient kit money makes no change")
	s = unit_visit("customer_wealthy_antique","item_luxury_porcelain_vase","mended"); v = s._day.state.visits[0]; equip(s)
	v.item.goods.precision = {"damage":"minor","hidden":false}
	seal_stage(s,v,2); check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"pressure rollback setup")
	before = s.read_state(); (s._save as CountingStore).fail = true
	check(not s.counter_command("luxury_pressure",v.visit_id).ok and s.read_state() == before,"failed evidence publication restores quote time patience and used facts")
