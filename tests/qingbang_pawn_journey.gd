extends "res://tests/qingbang.gd"

func run() -> void:
	var loaded:=JsonContentProvider.new("res://data/qingbang_manifest.json").load_catalog()
	check(loaded.is_success(),"pawn journey content")
	if not loaded.is_success():quit(1);return
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id)
	var original:=run_def.initial_cash
	run_def._initial_cash=2500
	var losses:=0
	for seed_value in [42,1049,709]:
		var s:=fresh(seed_value)
		for n in range(1,15):
			drain(s,"refuse")
			check(s.execute("open_shop").ok,"pawn journey opens")
			drain(s,"refuse")
			if n in [3,4,5,7,8,9,10]: take_pawns(s)
			drain(s,"refuse")
			check(s.execute("close_shop").ok,"pawn journey closes")
			drain(s,"refuse")
			check(s.execute("wait_until_seal").ok,"pawn journey seals")
			drain(s,"refuse")
			for row in s.pawn_disposal_model(): check(s.choose_pawn_disposal(row.id,"keep").ok,"ordinary maturity choice")
			check(s.execute("resolve_night").ok,"pawn journey resolves")
			drain(s,"refuse")
			check(s.execute("enter_room").ok,"pawn journey room")
			drain(s,"refuse")
			check(s.execute("sleep").ok,"pawn journey sleep")
			drain(s,"refuse")
			check(s.execute("finish_sleep").ok,"pawn journey sleep ends")
			if n in [6,10,14]: verify(s,"pawn journey %d/%d" % [seed_value,n])
			check(s.execute("continue_run").ok,"pawn journey next")
		var state:=s._day.state
		var lost_pawns:=state.pawn_tickets.filter(func(t: PawnTicket)->bool:return t.status=="destroyed").size()
		losses+=lost_pawns
		print("PAWN STRATEGY seed=%d tickets=%d raids=%d lost_pawns=%d complaints=%d" % [seed_value,state.pawn_tickets.size(),state.social.qingbang.raids.size(),lost_pawns,state.social.qingbang.complaints.size()])
	check(losses>0,"natural raids destroy pledged items and persist settlement")
	run_def._initial_cash=original
	print("QINGBANG PAWN JOURNEY: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)

func drain(s: RunSession,strategy := "pay") -> void:
	for i in 20:
		if QingbangConversation.active(s._day.state): talk(s);continue
		var visit:=PawnReturnService.current(s._day.state)
		if visit.is_empty(): break
		if not s._day.state.pending_event_id.is_empty(): break
		var result:=s.commerce_command(visit.command,visit.ticket_id)
		check(result.ok,"return or destroyed-pawn meeting")
		if not result.ok: break
	super.drain(s,strategy)

func take_pawns(s: RunSession) -> void:
	var count:=0
	for i in 12:
		drain(s,"refuse")
		var state:=s._day.state
		if state.phase!=&"open": return
		var v:=CustomerManager.new().active(state)
		var model:=s.counter_model()
		if v!=null and QingbangDamage.ordinary(state,v.item) and model.trade.can_pawn:
			check(s.counter_command("pawn",v.visit_id,"low",model.trade.pawn_asking).ok,"ordinary real pawn")
			count+=1
			if count==2:return
		else:
			var bell:=s.bell_model()
			if not bell.enabled:return
			check(s.bell_command(bell.mode,bell.target_id).ok,"seek pawn visitor")
