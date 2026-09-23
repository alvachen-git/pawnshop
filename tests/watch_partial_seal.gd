extends "res://tests/watch_economy.gd"

func run() -> void:
	if not setup(): quit(1); return
	for mode in ["unchecked","flat_only","one_spot","running_only","wrong"]:
		var s := watch_fixture("sound","intact","positional")
		var v: CustomerVisit = s._day.state.visits[0]
		var id := v.item.instance_id
		check(s.fan_command("luxury_begin",id,"2").ok,"begin apparatus")
		if mode in ["flat_only","running_only","wrong"]:
			check(command(s,id,{"op":"wind"}).ok,"wind")
			check(command(s,id,{"op":"listen","clip":"wound/flat"}).ok,"flat")
			if mode != "flat_only":
				check(command(s,id,{"op":"pose","pose":"vertical"}).ok,"vertical pose")
				check(command(s,id,{"op":"listen","clip":"wound/vertical"}).ok,"vertical")
			check(command(s,id,{"op":"draft","identity":"unsure","condition":"unsure","running":"stable" if mode == "wrong" else "positional"}).ok,"partial draft")
		if mode == "one_spot":
			check(command(s,id,{"op":"open"}).ok,"open")
			var point := WatchAppraisal.spot(v.item,0)
			check(command(s,id,{"op":"inspect","point":[point.x,point.y]}).ok,"one mechanism spot")
		var minutes := s._day.state.game_minutes
		var actual: int = v.item.goods.watch_value.actual
		check(command(s,id,{"op":"seal"}).ok,"incomplete checks allow sealing: "+mode)
		check(TieredAppraisal.stage(s._day.state,id,2).committed,"committed: "+mode)
		check(s._day.state.game_minutes == minutes and v.item.goods.watch_value.actual == actual,"sealing free and no revaluation")
		check(not command(s,id,{"op":"draft","identity":"original","condition":"intact","running":"stable"}).ok,"cannot rewrite sealed record")
		if mode in ["flat_only","running_only","wrong"]:
			var patience := v.trade.patience
			check(s.counter_command("luxury_pressure",v.visit_id).ok,"proof remains a separate action")
			check(("running" in WatchEconomy.owner(s._day.state,v).accepted) == (mode == "running_only"),"only sufficiently supported correct judgment accepted")
			check(v.trade.patience == patience if mode == "running_only" else v.trade.patience < patience,"bad proof still costs patience")
		else: check(not s.counter_command("luxury_pressure",v.visit_id).ok,"unknown judgment does not invent evidence")
	var s := watch_fixture(); var v: CustomerVisit = s._day.state.visits[0]
	check(s.fan_command("luxury_begin",v.item.instance_id,"2").ok,"prepare rollback case")
	var before := s.read_state(); (s._save as CountingStore).fail = true
	check(not command(s,v.item.instance_id,{"op":"seal"}).ok,"failed save rejects seal")
	check(s.read_state() == before,"failed save restores unsealed record")
	print("WATCH PARTIAL SEAL: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
