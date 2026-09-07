extends RefCounted

var check: Callable
var catalog: ContentCatalog

func action(s: RunSession, command: String) -> void:
	var result := s.execute(command)
	check.call(result.ok, command + ": " + result.message)

func drain(s: RunSession) -> void:
	for step in 60:
		var model := s.event_model()
		if model.pending_id.is_empty(): return
		check.call(not model.buttons.is_empty(), "event has choices")
		if model.buttons.is_empty(): return
		var result := s.event_command(model.pending_id, model.buttons[0].detail)
		check.call(result.ok, "event " + model.pending_id + ": " + result.message)
		if not result.ok: return
	check.call(false, "event chain terminates")

func resume(s: RunSession) -> void:
	var before := s.read_state()
	var result := s.load_checkpoint()
	var after := s.read_state()
	if s._save.library != null and before.phase not in ["dead", "bankrupt", "run_ended"]:
		check.call(before.run_token != after.run_token, "library load creates a new attempt")
		before.erase("run_token"); after.erase("run_token")
	check.call(result.ok and before == after, "exact checkpoint: " + result.message)

func open(s: RunSession) -> void:
	drain(s)
	if s._day.state.current_night_index >= 4 and not OpeningPreparation.enabled(s.definition):
		if s._day.state.current_night_index == 4:
			action(s, "prep_investigate")
			action(s, "prep_contact")
		action(s, "prep_finish")
	action(s, "open_shop")
	drain(s)
	var returning := PawnReturnService.current(s._day.state)
	if not returning.is_empty():
		check.call(s._day.state.current_night_index == 6, "redeem on sixth night")
		check.call(s.counter_command("redeem", returning.id).ok, "redeem original pawn")

func work(s: RunSession, route: String) -> void:
	var n := s._day.state.current_night_index
	for step in 150:
		if s._day.state.game_minutes >= 480: return
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if v.item.definition_id == "intro_silver_hairpin":
				check.call(v.trade.rounds_left >= 4 and v.trade.patience >= 4, "tutorial attempts preserved")
				if route == "reject": check.call(s.counter_command("reject", v.visit_id).ok, "reject first sale")
				elif route == "timeout":
					while v.status == "active": action(s, "short_task")
				else:
					check.call(s.counter_command("offer", v.visit_id, "", v.trade.reserve_price).ok, "buy first hairpin")
					drain(s)
			elif v.item.definition_id == "item_weeping_mirror":
				if route in ["reject", "timeout"]: check.call(s.counter_command("reject", v.visit_id).ok, "refuse mirror")
				else:
					check.call(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "buy mirror")
					if route == "covered": check.call(s.risk_command("cover", v.item.instance_id).ok, "cover once")
			elif n == 3 and v.visit_id.ends_with("/n3_visit5") and route not in ["reject", "timeout", "covered", "sell_early"]:
				var before := v.item.to_data().duplicate(true)
				var reserve := v.trade.reserve_price
				check.call(s.mirror_command("midnight_old_ticket", "peek").ok, "peek old ticket")
				check.call(before == v.item.to_data() and reserve == v.trade.reserve_price, "mirror grants no evidence/value/discount")
				check.call(not s.counter_command("pressure", v.visit_id, "flaw").ok, "mirror cannot justify pressure")
				check.call(s.mirror_command("midnight_old_ticket", "stop" if route == "stop" else "pursue").ok, "resolve old ticket choice")
				check.call(s.counter_command("appraise", v.visit_id, "observe").ok, "watch observe")
				check.call(s.counter_command("appraise", v.visit_id, "inspect").ok and "flaw" in v.item.revealed_clue_ids, "normal inspection reveals flaw")
				check.call(s.counter_command("reject", v.visit_id).ok, "leave watch")
			elif row.get("seven_role", "") == "pawn":
				check.call(s.counter_command("pawn", v.visit_id, "", 40).ok, "third night pawn")
			elif row.get("seven_role", "") in ["pen4", "pen5"]:
				check.call(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "acquire appointment pen")
			else: check.call(s.counter_command("reject", v.visit_id).ok, "ordinary reject")
		else:
			var mirror := s._day.state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.definition_id == "item_weeping_mirror" and item.ownership_state == "owned")
			if n == 3 and route in ["sell_early", "sell_pursued"] and not mirror.is_empty() and s._commerce.trip_reason(s._day, catalog.get_definition("buyers", "buyer_mirror")).is_empty():
				check.call(s.sell_batch("buyer_mirror", [mirror[0].instance_id]).ok, "sell mirror")
			elif n == 6 and s._commerce.trip_reason(s._day, catalog.get_definition("buyers", PreparationService.BUYER)).is_empty():
				var pens := s._day.state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.definition_id == "item_fountain_pen" and item.ownership_state == "owned")
				if not pens.is_empty(): check.call(s.sell_batch(PreparationService.BUYER, pens.map(func(item: ItemInstance) -> String: return item.instance_id)).ok, "sixth night appointment sale")
				else: action(s, "short_task")
			else: action(s, "short_task")
	check.call(false, "work loop bounded")

func finish(s: RunSession, route: String) -> void:
	if route != "uncovered":
		for item in s._day.state.inventory_instances:
			if item.definition_id == "item_weeping_mirror" and item.ownership_state == "owned" and not s._risk.covered(s._day.state, item.instance_id):
				check.call(s.risk_command("cover", item.instance_id).ok, "cover before sealing")
	action(s, "close_shop")
	action(s, "wait_until_seal")
	action(s, "resolve_night")
	resume(s)
	if not s._day.state.risk_pending.is_empty():
		check.call(s.risk_command("retreat", s._day.state.risk_pending).ok, "storage survival")
		resume(s)
	action(s, "enter_room")
	drain(s)
	resume(s)
	action(s, "sleep")
	drain(s)
	resume(s)
	if not s._day.state.risk_pending.is_empty():
		check.call(s._day.state.current_night_index == 3, "pursuit confined to third night")
		check.call(s.risk_command("defy" if route == "death" else "retreat", s._day.state.risk_pending).ok, "personal consequence")
		resume(s)
		if route == "death": return
	action(s, "finish_sleep")
	resume(s)
	action(s, "continue_run")
	resume(s)
