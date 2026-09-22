extends "res://tests/shop_appraisal.gd"

const DIR := "res://.godot/qa/fan-bargaining/"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/fan_bargaining_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v28 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,28,store,catalog)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(codec.encode(s._day.state,28),run_def,28,catalog,true)
	check(restored != null,"v28 replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,28)))

func load_case(label := "ordinary") -> RunSession:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + label + ".json"))
	var s := fresh_growth(int(payload.run_seed))
	s._day.state = SaveCodec.new().decode(payload,run_def,28,catalog,true)
	return s

func claim(s: RunSession, choice := "sound") -> void:
	var visit := CustomerManager.new().active(s._day.state)
	var id := visit.item.instance_id
	for kind in ["brush","inscription"]:
		var detail := FanEvidence.payload(kind, Vector2(.72,.32) if kind == "brush" else Vector2(.74,.69),Vector2(.38,.245) if kind == "brush" else Vector2(.80,.355),"same")
		var result := s.fan_command("draft",id,detail)
		check(result.ok,"draft for pressure: " + result.message)
	var committed := s.fan_command("commit",id,choice)
	check(committed.ok,"private verdict: " + committed.message)

func invalid_pressure(s: RunSession, detail := "", amount := 0) -> void:
	var visit := CustomerManager.new().active(s._day.state)
	var before := s.read_state()
	var writes: int = s._save.writes
	check(not s.counter_command("fan_pressure",visit.visit_id,detail,amount).ok,"reject invalid pressure")
	check(before == s.read_state() and writes == s._save.writes,"invalid pressure neither records nor saves")

func run() -> void:
	if not setup(): quit(1); return
	create_fixtures()
	for kind in ["informed","ordinary","urgent"]: pressure_case(kind)
	matrix_checks()
	reaction_and_economy_checks()
	boundary_checks_new()
	storage_checks_new()
	legacy_check()
	print("FAN BARGAINING: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func reaction_and_economy_checks() -> void:
	for kind in ["informed","ordinary","urgent"]:
		var reference := {}
		for truth in ["sound","mended","flawed"]:
			var s := load_case(kind + "-ready")
			var visit := CustomerManager.new().active(s._day.state)
			visit.item.selected_variant_id = truth
			check(s.counter_command("fan_pressure",visit.visit_id).ok,"same reaction eligible across truths")
			var public := {"message":s.message,"asking":FanBargainingService.asking(s._day.state,visit),"patience":visit.trade.patience,"rounds":visit.trade.rounds_left}
			if reference.is_empty(): reference=public
			else: check(reference==public,"reaction cannot identify hidden truth " + kind)
		var outcomes := []
		for pressure in [false,true]:
			var s := load_case(kind + "-ready")
			var visit := CustomerManager.new().active(s._day.state)
			var start := s._day.state.game_minutes
			var cash := s._day.state.cash
			var price := visit.trade.reserve_price
			if pressure:
				check(s.counter_command("fan_pressure",visit.visit_id).ok,"economic pressure")
				price=int(FanBargainingService.attempt(s._day.state,visit).reserve)
			check(s.counter_command("offer",visit.visit_id,"",price).ok,"economic actual acquisition")
			check(cash-s._day.state.cash==price,"cash cost matches acquisition")
			var outcome := {"cost":price,"minutes":s._day.state.game_minutes-start,"value":GoodsExpertise.value(visit.item,catalog.get_definition("items",GoodsExpertise.FAN)),"events":FanBargainingService.data(s._day.state).reputation_events.size()}
			for step in 10:
				var other := CustomerManager.new().active(s._day.state)
				if other == null: break
				check(s.counter_command("reject",other.visit_id).ok,"finish waiting visitor before sale")
			var sold := s.commerce_command("sell",visit.item.instance_id,"buyer_recycler")
			check(sold.ok,"economic actual resale: " + sold.message)
			if sold.ok:
				outcome["sale_income"]=s._day.state.sale_records.back().price
				outcome["realized_profit"]=s._day.state.sale_records.back().realized_profit
				outcome["total_minutes"]=s._day.state.game_minutes-start
			outcomes.append(outcome)
		check(outcomes[0].value==outcomes[1].value,"public bargaining never changes downstream valuation")
		check(outcomes[1].minutes-outcomes[0].minutes==5,"actual comparative extra time")
		print("ECONOMY ACTUAL ",kind," baseline=",outcomes[0]," pressure=",outcomes[1])
	# Direct expert service and repeated expert requests never farm standing.
	var s := load_case()
	var visit := CustomerManager.new().active(s._day.state)
	check(s.counter_command("offer",visit.visit_id,"",visit.trade.reserve_price).ok,"buy without private appraisal")
	check(s.commerce_command("expert_fan",visit.item.instance_id).ok,"expert without private claim")
	check(FanAppraisalService.data(s._day.state).standing==0,"direct expert gives no standing")
	var before := s.read_state(); var writes: int=s._save.writes
	check(not s.commerce_command("expert_fan",visit.item.instance_id).ok and s.read_state()==before and s._save.writes==writes,"repeat expert no save or reward")

func create_fixtures() -> void:
	var selected := {}
	for seed_value in 500:
		var sample := fresh_growth(seed_value)
		for row in OpeningPreparation.plan(sample._day.state,run_def,catalog):
			if row.night != 5 or row.item_id != GoodsExpertise.FAN or row.variant_id != "sound" or "sell" not in row.transaction_modes: continue
			if row.get("familiar_reserved", false) or row.has("night_policy"): continue
			var kind: String = "informed" if row.customer_id == "customer_scholar" else ("urgent" if row.situation == "urgent" else "ordinary")
			if not selected.has(kind): selected[kind] = {"seed":seed_value,"visit_id":row.visit_id}
		if selected.size() == 3: break
	check(selected.size() == 3,"three natural pressure cases available")
	for kind in selected:
		var s := unlock(int(selected[kind].seed))
		act(s,"open_shop"); driver.drain(s)
		for step in 80:
			var visit := CustomerManager.new().active(s._day.state)
			if visit != null:
				if visit.visit_id == selected[kind].visit_id: break
				s.counter_command("reject",visit.visit_id)
			elif s.bell_model().enabled: s.bell_command("wait")
			else: break
			driver.drain(s)
		var visit := CustomerManager.new().active(s._day.state)
		check(visit != null and visit.visit_id == selected[kind].visit_id and visit.item.definition_id == GoodsExpertise.FAN,"natural target " + kind)
		fixture(s,kind)
		if kind == "ordinary": fixture(s,"fan-sound")

func pressure_case(kind: String) -> void:
	var s := load_case(kind)
	var visit := CustomerManager.new().active(s._day.state)
	invalid_pressure(s)
	claim(s)
	fixture(s,kind + "-ready")
	var minute := s._day.state.game_minutes
	var asking := visit.trade.asking_price
	var reserve := visit.trade.reserve_price
	var patience := visit.trade.patience
	var rounds := visit.trade.rounds_left
	var goods := visit.item.goods.duplicate(true)
	check(s.counter_command("fan_pressure",visit.visit_id).ok,"pressure " + kind)
	var row := FanBargainingService.attempt(s._day.state,visit)
	var percent: int = {"informed":0,"ordinary":20,"urgent":40}[kind]
	check(row.percent == percent and row.asking == maxi(1,roundi(asking * (100-percent) / 100.0)) and row.reserve == maxi(1,roundi(reserve * (100-percent) / 100.0)),"exact independent discounts " + kind)
	check(s._day.state.game_minutes == minute+5 and visit.trade.rounds_left == rounds-1,"one five-minute round")
	check(visit.trade.patience == patience - (1 if kind == "informed" else 0),"knowledge reaction")
	check(visit.item.goods == goods and visit.item.selected_variant_id == "sound","statement does not rewrite private claim or truth")
	check(visit.trade.asking_price == asking and visit.trade.reserve_price == reserve,"pawn original prices intact")
	invalid_pressure(s)
	var before := s.read_state()
	check(not s.counter_command("belittle",visit.visit_id).ok and before == s.read_state(),"cannot stack belittle after claim")
	fixture(s,kind + "-pressed")
	var price: int = row.reserve
	check(s.counter_command("offer",visit.visit_id,"",price).ok and visit.item.ownership_state == "owned","buy at current sale floor")
	check(FanBargainingService.data(s._day.state).reputation_events.size() == (0 if kind == "informed" else 1),"hidden true-item penalty only on discounted sale")
	FanBargainingService.bought(s._day,visit,price)
	check(FanBargainingService.data(s._day.state).reputation_events.size() <= 1,"no duplicate event")
	check(s.commerce_command("expert_fan",visit.item.instance_id).ok,"expert after private true claim")
	check(FanAppraisalService.data(s._day.state).standing == 1,"public false claim does not spoil true private judgement")
	fixture(s,kind + "-bought")
	print("ECONOMY ",kind," ask=",asking," base_floor=",reserve," pressure_floor=",price," saving=",reserve-price," extra_minutes=5 hidden_events=",FanBargainingService.data(s._day.state).reputation_events.size())

func matrix_checks() -> void:
	for truth in ["sound","mended","flawed"]:
		for verdict in ["sound","mended","flawed"]:
			var s := load_case()
			var visit := CustomerManager.new().active(s._day.state)
			visit.item.selected_variant_id = truth
			claim(s,verdict)
			var result := s.counter_command("fan_pressure",visit.visit_id)
			check(result.ok and not result.message.contains("商誉"),"no reputation feedback")
			var price: int = FanBargainingService.attempt(s._day.state,visit).reserve
			check(s.counter_command("offer",visit.visit_id,"",price).ok,"matrix sale")
			check(FanBargainingService.data(s._day.state).reputation_events.size() == (1 if truth == "sound" else 0),"penalty follows truth and public claim, not private verdict")
			check(s.commerce_command("expert_fan",visit.item.instance_id).ok,"matrix expert")
			check(FanAppraisalService.data(s._day.state).standing == ((1 if truth == "sound" else -2) if verdict == "sound" else 0),"only private true promise affects appraisal standing")
	# High-price purchases, rejected bargaining, pawn and failed talks create no penalty.
	for outcome in ["high","reject","pawn"]:
		var s := load_case("urgent")
		var visit := CustomerManager.new().active(s._day.state)
		claim(s)
		check(s.counter_command("fan_pressure",visit.visit_id).ok,"pressure before " + outcome)
		if outcome == "high": check(s.counter_command("offer",visit.visit_id,"",visit.trade.asking_price).ok,"pay original asking")
		elif outcome == "reject": check(s.counter_command("reject",visit.visit_id).ok,"leave without purchase")
		else:
			var customer := catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
			var terms := catalog.get_definition("pawn_terms",VarietyService.terms_for(visit,customer)) as PawnTermsDefinition
			check(terms != null,"pawn terms available")
			if terms != null:
				var floor_price := maxi(1,roundi(visit.trade.reserve_price * terms.loan_ratio))
				check(s.counter_model().trade.pawn_asking == maxi(1,roundi(visit.trade.asking_price*terms.loan_ratio)),"pawn display original")
				check(s.counter_command("pawn",visit.visit_id,"",floor_price).ok and visit.item.ownership_state == "pledged","pawn original floor")
		check(FanBargainingService.data(s._day.state).reputation_events.is_empty(),"no penalty " + outcome)

func boundary_checks_new() -> void:
	for remaining in [4,5,6]:
		var s := load_case(); claim(s)
		var visit := CustomerManager.new().active(s._day.state)
		visit.expires_at = s._day.state.game_minutes + remaining
		if remaining <= 5: invalid_pressure(s)
		else: check(s.counter_command("fan_pressure",visit.visit_id).ok,"before exact deadline")
	var s := load_case(); claim(s)
	var visit := CustomerManager.new().active(s._day.state)
	invalid_pressure(s,"extra"); invalid_pressure(s,"",1)
	s._day.state.game_minutes=535;visit.expires_at=600;invalid_pressure(s)
	s=load_case();claim(s);visit=CustomerManager.new().active(s._day.state)
	s._day.state.pending_event_id="pending";invalid_pressure(s);s._day.state.pending_event_id=""
	s._day.state.risk_pending=visit.item.instance_id;invalid_pressure(s);s._day.state.risk_pending=""
	visit.trade.rounds_left=0;invalid_pressure(s);visit.trade.rounds_left=2
	visit.trade.patience=0;invalid_pressure(s);visit.trade.patience=2
	visit.night_policy="one_quote";invalid_pressure(s);visit.night_policy=""
	check(s.counter_command("belittle",visit.visit_id).ok,"belittle first")
	invalid_pressure(s)
	s=load_case();claim(s);visit=CustomerManager.new().active(s._day.state)
	visit.trade.asking_price=2;visit.trade.reserve_price=1
	check(s.counter_command("fan_pressure",visit.visit_id).ok,"small price")
	check(FanBargainingService.attempt(s._day.state,visit).reserve == 1,"floor at one")
	for remaining in [534,535,536]:
		s=load_case("ordinary-ready");visit=CustomerManager.new().active(s._day.state)
		s._day.state.game_minutes=remaining;visit.expires_at=600
		if remaining>=535: invalid_pressure(s)
		else: check(s.counter_command("fan_pressure",visit.visit_id).ok,"03:00 strictly before boundary")
	for exclusion in ["gone","special","pawn_only","rounds_last"]:
		s=load_case("ordinary-ready");visit=CustomerManager.new().active(s._day.state)
		if exclusion=="gone":
			s.counter_command("reject",visit.visit_id)
			var before:=s.read_state();var writes:int=s._save.writes
			check(not s.counter_command("fan_pressure",visit.visit_id).ok and s.read_state()==before and s._save.writes==writes,"departed seller invalid")
		elif exclusion=="special": visit.purpose="husband_meeting";invalid_pressure(s)
		elif exclusion=="pawn_only": visit.transaction_modes=["pawn"];invalid_pressure(s)
		else:
			visit.trade.rounds_left=1
			check(s.counter_command("fan_pressure",visit.visit_id).ok and visit.status=="rounds_exhausted","final round leaves")
			check(FanBargainingService.data(s._day.state).reputation_events.is_empty(),"no sale no hidden event")
	s=load_case("informed");claim(s);visit=CustomerManager.new().active(s._day.state)
	visit.situation_id="urgent";visit.trade.patience=1
	check(s.counter_command("fan_pressure",visit.visit_id).ok and visit.status=="patience_exhausted","informed urgent resists and may leave")

func storage_checks_new() -> void:
	var s := load_case("ordinary-ready")
	var manager := SaveManager.new("user://tests/fan_bargaining/auto.json")
	manager.catalog=catalog;manager.library=SaveLibrary.new("user://tests/fan_bargaining/library.json")
	check(manager.save_state(s._day.state,run_def,28),"real library save")
	s._save=manager
	var visit := CustomerManager.new().active(s._day.state)
	for command in ["fan_pressure","offer"]:
		var before := s.read_state()
		var bytes := FileAccess.get_file_as_bytes(manager.library.path)
		manager.library.fail_write=true
		var price: int = 0 if command=="fan_pressure" else FanBargainingService.attempt(s._day.state,visit).reserve
		check(not s.counter_command(command,visit.visit_id,"",price).ok,"write failure " + command)
		check(s.read_state()==before and bytes==FileAccess.get_file_as_bytes(manager.library.path),"atomic price/time/cash/inventory/reputation rollback")
		manager.library.fail_write=false
		visit=CustomerManager.new().active(s._day.state)
		check(s.counter_command(command,visit.visit_id,"",price).ok,"retry " + command)
	fixture(s,"saved-sale")
	var expert_before:=s.read_state()
	var expert_bytes:=FileAccess.get_file_as_bytes(manager.library.path)
	manager.library.fail_write=true
	check(not s.commerce_command("expert_fan",visit.item.instance_id).ok,"expert save failure")
	check(s.read_state()==expert_before and expert_bytes==FileAccess.get_file_as_bytes(manager.library.path),"expert rollback includes standing and review marker")
	manager.library.fail_write=false
	for field in ["reputation_events","attempts"]:
		var payload := SaveCodec.new().encode(s._day.state,28)
		payload.shop_growth.fan_bargaining[field] = [] if field=="reputation_events" else {}
		check(SaveCodec.new().decode(payload,run_def,28,catalog,true)==null,"forged hidden ledger or discount rejected")
	var loaded := manager.load_state(run_def,28)
	check(loaded!=null,"real library cold restore")
	if loaded!=null: check(GhostSaveCodec.same(loaded.to_read_model(),s.read_state()),"restored discounted sale exact")

func legacy_check() -> void:
	var old_catalog := JsonContentProvider.new("res://data/shop_appraisal_manifest.json").load_catalog().catalog
	var old_run := old_catalog.get_definition("runs",old_catalog.default_run_id) as RunDefinition
	var old_store := CountingStore.new()
	old_store.origin={"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
	var old_session:=RunSession.new(old_run,27,old_store,old_catalog)
	var payload:=SaveCodec.new().encode(old_session._day.state,27)
	if FileAccess.file_exists("res://.godot/qa/shop-appraisal/desk-saved.json"):
		payload=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/desk-saved.json"))
	var state := SaveCodec.new().decode(payload,old_run,27,old_catalog,true)
	check(state!=null and not FanBargainingService.enabled(old_run),"v27 retains rule gate and reads historical save")
