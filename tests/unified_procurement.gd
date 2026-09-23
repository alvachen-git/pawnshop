extends "res://tests/unified_facilities.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s: RunSession
	for seed_value in 1500:
		var probe := fresh_growth(seed_value)
		var plan := OpeningPreparation.plan(probe._day.state,run_def,catalog)
		if plan.filter(func(row: Dictionary) -> bool: return row.night == 1 and row.item_id == CoatProcurement.ITEM and "sell" in row.transaction_modes).size() < 3: continue
		driver.drain(probe); act(probe,"open_shop"); driver.drain(probe)
		for step in 100:
			driver.drain(probe)
			var visit := probe._counter.customers.active(probe._day.state)
			if visit != null:
				if visit.item.definition_id == CoatProcurement.ITEM:
					check(probe.counter_command("offer",visit.visit_id,"",visit.trade.reserve_price).ok,"buy natural coat in complete game")
				else: check(probe.counter_command("reject",visit.visit_id).ok,"ordinary business continues")
			else:
				if probe._day.state.game_minutes >= 450: break
				check(probe.bell_command("wait").ok,"wait for next real coat seller")
		if CoatProcurement.stock(probe._day.state).size() >= 3:
			s = probe; break
	check(s != null,"three naturally acquired coats in combined distribution")
	if s == null: quit(1); return
	finish_night(s); driver.drain(s)
	check(s.social_command("accept_contract").ok,"accept actual unified order")
	var ids: Array = CoatProcurement.stock(s._day.state).slice(0,3).map(func(item: ItemInstance) -> String:return item.instance_id)
	var detail := JSON.stringify({"order":s._day.state.social.contract.number,"ids":ids})
	var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.social_command("deliver",detail).ok and s.read_state() == before,"delivery disk failure restores stock cash reward journal")
	(s._save as CountingStore).fail = false
	var delivered := s.social_command("deliver",detail)
	check(delivered.ok,"deliver three natural coats: " + delivered.message + " stock=" + str(CoatProcurement.stock(s._day.state).size()))
	check(s._day.state.cash == before.cash + 50 and s._day.state.social.military == 6,"single 50-yuan reward and relation gain")
	before = s.read_state()
	check(not s.social_command("deliver",detail).ok and s.read_state() == before,"repeated delivery cannot duplicate reward")
	verify(s,"real unified procurement")
	print("UNIFIED PROCUREMENT: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
