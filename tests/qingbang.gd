extends SceneTree
var catalog: ContentCatalog
var run_def: RunDefinition
var passes := 0
var failures := 0

class Store extends GhostReplayStore:
	var fail := false
	func save_state(_s: RunState,_r: RunDefinition,_v: int) -> bool: return not fail

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error(label)
func fresh(seed_value := 42) -> RunSession:
	var store := Store.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,48,store,catalog)
func fixture(n := 5,relation := 0) -> RunSession:
	var s := fresh()
	var state := s._day.state
	state.current_night_index = n
	state.pending_event_id = ""
	state.social.introduced = true
	state.social.intro_step = 3
	state.social.qingbang.introduced = true
	state.social.qingbang.relation = relation
	state.visits.clear()
	state.ordinary_selections.clear()
	state.social.nights.append({"night":n,"military_checked":true,"closed":false,"reputation":0,"adjustment":0,"removed":[],"added":[]})
	return s
func stock(state: RunState,id: String,owned := "owned",item_id := "item_fountain_pen") -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = id; item.definition_id = item_id; item.selected_variant_id = "sound"
	item.ownership_state = owned; item.acquisition_price = 20
	state.inventory_instances.append(item)
	return item
func talk(s: RunSession) -> void:
	for i in 5:
		if not QingbangConversation.active(s._day.state): return
		var d: Dictionary = s._day.state.social.qingbang.dialogue
		check(s.counter_command("qingbang_talk",d.id,QingbangConversation.token(s._day.state)).ok,"conversation step")
func verify(s: RunSession,label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state,48)
	var restored := codec.decode(data,run_def,48,catalog,true)
	check(restored != null,"cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"identical " + label)
	var forged := data.duplicate(true)
	forged.social.qingbang.relation += 1
	check(codec.decode(forged,run_def,48,catalog,true) == null,"reject forged faction state")
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/qingbang_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"qingbang content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	for row in QingbangRules.config().supplies:
		var item := catalog.get_definition("items",row.item) as ItemDefinition
		check(item != null and item.find_variant(row.variant) != null,"supply valid " + row.id)
	boundaries()
	damage()
	supplies()
	natural()
	print("QINGBANG: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func boundaries() -> void:
	for pair in [[-100,100],[-50,100],[-49,90],[-11,90],[-10,80],[19,80],[20,65],[49,65],[50,50],[100,50]]:
		check(QingbangRules.fee(pair[0]) == pair[1],"fee boundary " + str(pair))
	var s := fixture()
	var state := s._day.state
	QingbangService.dawn(state,run_def)
	check(state.social.qingbang.pending.get("cost",0) == 80 and state.social.qingbang.next_fee == 13,"first fee due")
	talk(s)
	var before := s.read_state()
	(s._save as Store).fail = true
	check(not s.social_command("qingbang/refuse","qingbang/fee/5").ok and before == s.read_state(),"refusal save rollback")
	(s._save as Store).fail = false
	check(s.social_command("qingbang/refuse","qingbang/fee/5").ok,"refuse fee")
	state = s._day.state
	check(state.social.qingbang.relation == -20 and state.cash == 300,"refusal exact delta no cash")
	check(not s.social_command("qingbang/refuse","qingbang/fee/5").ok and state.social.qingbang.relation == -20,"duplicate refusal")
	state.phase = &"open"
	QingbangService.opening(s._day)
	check(state.social.qingbang.dialogue.is_empty(),"refusal night immune")
	QingbangRules.change(state,-1000,"test")
	check(state.social.qingbang.relation == -100,"lower clamp")
	QingbangRules.change(state,1000,"test")
	check(state.social.qingbang.relation == 100,"upper clamp")
	for n in [13,21]:
		s = fixture(n)
		QingbangService.dawn(s._day.state,run_def); talk(s)
		check(s.social_command("qingbang/pay","qingbang/fee/%d" % n).ok,"fee cycle")
		check(s._day.state.social.qingbang.next_fee == n + 8 and s._day.state.cash == 220,"fee amount and date")
	var raids := 0
	for seed_value in range(1,81):
		s = fixture(12,-11); state = s._day.state; state.run_seed = seed_value; state.phase = &"open"; state.social.qingbang.last_raid = 6
		QingbangService.opening(s._day)
		if not state.social.qingbang.dialogue.is_empty(): raids += 1
		for pair in [[11,-11],[12,-10]]:
			s = fixture(pair[0],pair[1]); state=s._day.state; state.run_seed=seed_value; state.phase=&"open"; state.social.qingbang.last_raid=6
			QingbangService.opening(s._day)
			check(state.social.qingbang.dialogue.is_empty(),"five full nights and strict threshold")
	check(raids > 0 and raids < 80,"risk resumes sixth night, probabilistic")

func damage() -> void:
	var s := fixture(6,-20)
	var state := s._day.state
	var a := stock(state,"own")
	var b := stock(state,"pawn","pledged")
	stock(state,"story","owned","item_weeping_mirror")
	stock(state,"gone","sold")
	var selected := QingbangDamage.pick(state,"test/raid")
	check(selected.size() == 2 and "own" in selected and "pawn" in selected,"damage pool excludes story and sold")
	check(selected == QingbangDamage.pick(state,"test/raid"),"seed stable targets")
	var ticket := PawnTicket.new()
	ticket.ticket_id="ticket/pawn";ticket.item_instance_id=b.instance_id;ticket.principal=20
	ticket.customer_id="customer_hawker";ticket.terms_id="sample_three_redeem";ticket.started_night=3;ticket.due_night=6;ticket.redemption_amount=22
	ticket.person={"id":"test/person","name":"测试当户"}
	state.pawn_tickets.append(ticket)
	QingbangDamage.apply(state,{"id":"test/raid","items":selected})
	check(a.ownership_state == "destroyed" and b.ownership_state == "destroyed","both destroyed")
	check(state.social.reputation == -5 and state.cash == 300,"raid social penalty no cash")
	QingbangDamage.apply(state,{"id":"test/raid","items":selected})
	check(state.social.reputation == -5 and state.ledger_entries.size() == 2,"raid once, loss accounting once")
	check(FinancialSummary.build(state).inventory_loss == 40 and FinancialSummary.build(state).pawn_principal == 0,"loss accounting")
	state.phase=&"open"
	PawnReturnService.prepare(state,catalog);PawnReturnService.arrive(state)
	var visit := PawnReturnService.current(state)
	check(not visit.is_empty(),"damaged pawn return exists")
	if not visit.is_empty():
		check(s.commerce_command("redeem",ticket.ticket_id).ok,"damaged return via public command")
		check(ticket.status == "destroyed" and state.cash == 300 and state.social.reputation <= -8 and state.social.reputation >= -11,"waive principal interest, complaint 3 to 6")
		check(not s.commerce_command("redeem",ticket.ticket_id).ok,"no double return")
	s=fixture(6,-20);state=s._day.state
	a=stock(state,"lonely")
	check(QingbangDamage.pick(state,"one").size()==1,"single item")
	a.ownership_state="sold"
	QingbangDamage.apply(state,{"id":"empty","items":[]})
	check(state.social.reputation == -5,"empty shop still loses reputation")
	s=fixture(6);state=s._day.state;b=stock(state,"absent","pledged")
	ticket=PawnTicket.new();ticket.ticket_id="absent";ticket.item_instance_id=b.instance_id;ticket.due_night=6;ticket.terms_id="sample_three_default"
	state.pawn_tickets.append(ticket)
	QingbangDamage.apply(state,{"id":"absent_raid","items":[b.instance_id]})
	state.phase=&"night_resolution"
	check(PawnController.new().disposal_reason(state,catalog,{}).is_empty(),"no disposal needed for destroyed collateral")
	PawnController.new().resolve_maturities(state,540,catalog,{})
	check(ticket.status=="destroyed" and b.ownership_state=="destroyed" and state.cash==300,"absent pawn no transfer income")

func supplies() -> void:
	for offered in QingbangRules.config().supplies:
		var s := fixture(6)
		var state := s._day.state
		state.social.qingbang.pending = {"kind":"supply","id":"test/supply","offer":offered.duplicate(true)}
		check(s.social_command("qingbang/select_supply","test/supply").ok,"select supply " + offered.id)
		state.phase=&"open";QingbangSupplies.spawn(state);CustomerManager.new().update(state)
		var v := CustomerManager.new().active(state)
		check(v != null and not ReputationService.eligible(state,v),"supply not ordinary reputation")
		if v == null: continue
		check(s.social_command("qingbang/check_supply",v.visit_id).ok,"prebuy investigation")
		var rep: int = state.social.reputation
		var result := s.counter_command("offer",v.visit_id,"",v.trade.asking_price)
		check(result.ok,"buy investigated supply " + result.message)
		check(state.social.qingbang.relation == 4 and state.social.reputation == rep,"buy reward no automatic reputation penalty")
		check(state.social.qingbang.claims.size() == (1 if offered.disputed else 0),"fixed truth creates appropriate claim")
		if offered.disputed:
			var id: String = v.item.instance_id
			state.social.qingbang.pending={"kind":"claim","id":id}
			check(s.social_command("qingbang/claim_return",id).ok,"return claimed supply")
			check(not s.social_command("qingbang/claim_return",id).ok,"claim once")
	var s := fixture()
	var state := s._day.state
	var item := stock(state,"inquiry")
	check(s.social_command("qingbang/inquire",item.instance_id).ok,"paid investigation")
	check(state.cash==290 and not s.social_command("qingbang/inquire",item.instance_id).ok,"no duplicate inquiry")
	item.ownership_state="sold";state.current_night_index=6
	QingbangSupplies.deliver_inquiries(state)
	check(s.social_command("qingbang/read_inquiry",item.instance_id).ok,"sold item still receives report")
	check(item.ownership_state=="sold" and state.inventory_instances.size()==1,"inquiry never recreates goods")
	check(not s.social_command("qingbang/read_inquiry",item.instance_id).ok,"read once")
	s=fixture(6,-100);state=s._day.state
	check(s.social_command("qingbang/gift").ok and PreparationService.count(state)==1 and state.social.qingbang.relation == -92,"negative relation repair and shared AP")
	for n in [7,8]:
		state.current_night_index=n
		check(not s.social_command("qingbang/gift").ok,"gift two full nights quiet")
	state.current_night_index=9
	check(s.social_command("qingbang/gift").ok,"gift resumes after two full nights")

func drain(s: RunSession,strategy := "pay") -> void:
	for step in 80:
		if QingbangConversation.active(s._day.state): talk(s); continue
		if MilitaryIntroduction.active(s._day.state):
			check(s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),str(s._day.state.social.intro_step)).ok,"Sun greeting")
			continue
		var q: Dictionary = s._day.state.social.qingbang
		if not q.pending.is_empty():
			var p: Dictionary = q.pending
			var command: String = {"fee":"pay" if strategy=="pay" else "refuse","supply":"decline_supply","claim":"claim_later"}.get(p.kind,"")
			check(s.social_command("qingbang/" + command,p.id).ok,"qingbang pending")
			continue
		var m: Dictionary = s._day.state.social.pending
		if not m.is_empty():
			var command: String = {"fee":"pay","closure":"pay","supply":"decline_supply","claim":"claim_later"}.get(m.kind,"")
			check(s.social_command(command).ok,"military pending")
			continue
		var event := s.event_model()
		if event.pending_id.is_empty(): return
		if event.buttons.is_empty(): check(false,"event choices missing"); return
		var result := s.event_command(event.pending_id,event.buttons[0].detail)
		check(result.ok,"story " + event.pending_id + " " + result.message)
		if not result.ok: return
	check(false,"drain bounded")

func stock_through_counter(s: RunSession,strategy: String) -> void:
	var bought := 0
	for attempt in 12:
		drain(s,strategy)
		var state := s._day.state
		if state.phase != &"open" or not PawnReturnService.current(state).is_empty(): return
		var v := CustomerManager.new().active(state)
		if v != null and QingbangDamage.ordinary(state,v.item) and s._counter.reason(s._day,"offer",v.visit_id,"",v.trade.asking_price).is_empty():
			check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"stock through real purchase")
			bought += 1
			if bought >= 2: return
		else:
			var bell := s.bell_model()
			if not bell.enabled: return
			check(s.bell_command(bell.mode,bell.target_id).ok,"wait or dismiss to stock")

func natural() -> void:
	var old_cash := run_def.initial_cash
	run_def._initial_cash=2500 # funded 24-night endurance; not a profitability claim
	for strategy in ["pay","refuse","repair"]:
		for seed_value in [42,1049,709]:
			var s := fresh(seed_value)
			check(FactionBookModels.roster(s._day.state).is_empty(),"unmet factions hidden")
			for n in range(1,25):
				drain(s,strategy)
				if n == 4: check(s._day.state.social.qingbang.introduced,"day four introduction")
				if strategy=="repair" and QingbangService.reason(s._day,"gift","").is_empty(): check(s.social_command("qingbang/gift").ok,"repair strategy")
				var opened := s.execute("open_shop")
				check(opened.ok,"natural open %d %s" % [n,opened.message])
				if not opened.ok: break
				drain(s,strategy)
				if n <= 4: stock_through_counter(s,strategy)
				check(s.execute("close_shop").ok,"natural close")
				drain(s,strategy)
				check(s.execute("wait_until_seal").ok,"natural seal")
				drain(s,strategy)
				check(s.execute("resolve_night").ok,"natural resolve")
				drain(s,strategy)
				check(s.execute("enter_room").ok,"natural room")
				drain(s,strategy)
				check(s.execute("sleep").ok,"natural sleep")
				drain(s,strategy)
				check(s.execute("finish_sleep").ok,"natural finish sleep")
				if n in [5,13,24]: verify(s,"%s/%d/%d" % [strategy,seed_value,n])
				check(s.execute("continue_run").ok,"natural continue")
				if s._day.state.current_night_index != n+1: break
			var q: Dictionary = s._day.state.social.qingbang
			check(s._day.state.current_night_index==25,"24-night journey completed")
			print("STRATEGY %s seed=%d cash=%d reputation=%d fees=%d raids=%d destroyed=%d" % [strategy,seed_value,s._day.state.cash,s._day.state.social.reputation,q.fees.size(),q.raids.size(),s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state=="destroyed").size()])
	run_def._initial_cash=old_cash
