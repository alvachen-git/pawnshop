extends "res://tests/qingbang.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/qingbang_manifest.json").load_catalog()
	check(loaded.is_success(),"edge content")
	if not loaded.is_success(): quit(1);return
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id)
	fees_and_rollback()
	grouped_loss()
	claim_paths()
	print("QINGBANG EDGES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)

func fees_and_rollback() -> void:
	var s:=fixture(5)
	var state:=s._day.state
	state.social.pending={"kind":"fee","amount":15}
	QingbangService.dawn(state,run_def)
	check(state.social.qingbang.pending.is_empty() and state.social.qingbang.next_fee==5,"other faction defers fee")
	state.social.pending={};state.current_night_index=6
	QingbangService.dawn(state,run_def);talk(s)
	check(state.social.qingbang.next_fee==14,"deferred actual arrival plus eight")
	state.social.qingbang.relation=-100
	check(state.social.qingbang.pending.cost==80,"quote frozen after relation change")
	state.cash=79
	var before:=s.read_state()
	check(not s.social_command("qingbang/pay",state.social.qingbang.pending.id).ok and before==s.read_state(),"insufficient funds atomic")
	check(s.social_command("qingbang/refuse",state.social.qingbang.pending.id).ok,"can refuse without cash")
	s=fixture(6,-20);state=s._day.state;state.phase=&"open"
	stock(state,"rollback")
	state.social.qingbang.dialogue={"id":"raid/rollback","kind":"raid","step":0,"items":["rollback"]}
	MarketService.sync(state,run_def)
	before=s.read_state();(s._save as Store).fail=true
	check(not s.counter_command("qingbang_talk","raid/rollback",QingbangConversation.token(state)).ok and before==s.read_state(),"raid storage failure restores inventory and goodwill")
	(s._save as Store).fail=false;state=s._day.state
	check(s.counter_command("qingbang_talk","raid/rollback",QingbangConversation.token(state)).ok,"raid retry")
	check(not s.counter_command("qingbang_talk","raid/rollback","raid/rollback/0").ok,"stale raid response rejected")
	check(state.social.military==0,"raid does not change military")
	check(not SocialReadModels.faction_history(state,"military").contains("报废"),"gang history isolated")

func grouped_loss() -> void:
	var s:=fixture(6,-20)
	var state:=s._day.state
	for i in 2:
		var id:="group/%d" % i
		stock(state,id,"pledged")
		var ticket:=PawnTicket.new()
		ticket.ticket_id=id;ticket.item_instance_id=id;ticket.principal=20;ticket.redemption_amount=22
		ticket.customer_id="customer_hawker";ticket.terms_id="sample_three_redeem";ticket.started_night=3;ticket.due_night=6
		ticket.person={"id":"same/person","name":"同一当户"}
		state.pawn_tickets.append(ticket)
	QingbangDamage.apply(state,{"id":"group/raid","items":["group/0","group/1"]})
	state.phase=&"open";PawnReturnService.prepare(state,catalog);PawnReturnService.arrive(state)
	var visit:=PawnReturnService.current(state)
	check(not visit.is_empty(),"grouped owner arrives")
	if not visit.is_empty():
		check(s.commerce_command(visit.command,visit.ticket_id).ok,"grouped complaint public command")
		check(state.pawn_tickets.all(func(t: PawnTicket)->bool:return t.status=="destroyed"),"all same-owner lost tickets close together")
		check(state.social.qingbang.complaints.size()==1 and state.cash==300,"only one complaint and no money")
		var rep: int=state.social.reputation
		PawnReturnService.arrive(state)
		check(PawnReturnService.current(state).is_empty() and state.social.reputation==rep,"no second encounter or penalty")
	state=fixture(6)._day.state
	for i in 3: stock(state,"coat/%d" % i,"owned","item_cotton_coat")
	state.social.contract={"number":1,"quantity":3,"reward":50,"delta":6}
	var delivery:=JSON.stringify({"order":1,"ids":["coat/0","coat/1","coat/2"]})
	check(CoatProcurement.delivery_reason(state,delivery).is_empty(),"coats selectable before raid")
	QingbangDamage.apply(state,{"id":"coats/raid","items":["coat/0","coat/1"]})
	check(CoatProcurement.stock(state).size()==1 and not CoatProcurement.delivery_reason(state,delivery).is_empty(),"stale bulk delivery cannot consume destroyed coats")

func claim_paths() -> void:
	for action in ["claim_compensate","claim_intervene","claim_later"]:
		var s:=fixture(6,20)
		var state:=s._day.state
		var offer: Dictionary=QingbangRules.config().supplies[1].duplicate(true)
		state.social.qingbang.pending={"kind":"supply","id":"test/source","offer":offer}
		check(s.social_command("qingbang/select_supply","test/source").ok,"claim setup")
		state.phase=&"open";QingbangSupplies.spawn(state);CustomerManager.new().update(state)
		var v:=CustomerManager.new().active(state)
		check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"claim purchase")
		var id:=v.item.instance_id
		state.social.qingbang.pending={"kind":"claim","id":id}
		if action=="claim_intervene":
			state.social.qingbang.relation=19
			check(not s.social_command("qingbang/"+action,id).ok,"intervention lower boundary")
			state.social.qingbang.relation=20
		var cash:=state.cash
		check(s.social_command("qingbang/"+action,id).ok,"claim action "+action)
		check(state.social.military==0,"claim factions independent")
		if action=="claim_compensate": check(state.cash==cash-12 and state.social.reputation==2,"half-price settlement public feedback")
		if action=="claim_intervene": check(state.cash==cash and state.social.reputation==-4,"public coercion goodwill consequence")
		if action=="claim_later":
			state.social.qingbang.pending={"kind":"claim","id":id}
			check(s.social_command("qingbang/"+action,id).ok and state.social.reputation==-4,"second postponement closes complaint")
		check(not s.social_command("qingbang/"+action,id).ok,"claim action idempotent")
