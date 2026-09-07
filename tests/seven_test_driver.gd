class_name SevenTestDriver
extends RefCounted

var check: Callable

func action(s: RunSession, command: String) -> bool:
	var result := s.execute(command)
	check.call(result.ok, command + ": " + result.message)
	return result.ok

func open(s: RunSession) -> void:
	if s._day.state.current_night_index >= 4 and not PreparationService.used(s._day.state, "finish", s._day.state.current_night_index): action(s, "prep_finish")
	action(s, "open_shop")
	while not PawnReturnService.current(s._day.state).is_empty():
		var r := PawnReturnService.current(s._day.state)
		check.call(s.counter_command("redeem", r.id).ok, "redeem original ticket")

func work(s: RunSession, buy := true) -> void:
	for guard in 120:
		if s._day.state.game_minutes >= 480: return
		var v := s._counter.customers.active(s._day.state)
		if v != null:
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			var role: String = row.get("seven_role", "")
			if role == "pawn" and buy: check.call(s.counter_command("pawn", v.visit_id, "", 40).ok, "pawn third night")
			elif role in ["pen4", "pen5"] and buy: check.call(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "buy chain pen")
			else: check.call(s.counter_command("reject", v.visit_id).ok, "send customer away")
		else:
			var stock := s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state == "owned")
			if buy and not stock.is_empty() and s._commerce.trip_reason(s._day, s._counter.catalog.get_definition("buyers", PreparationService.BUYER)).is_empty():
				check.call(s.sell_batch(PreparationService.BUYER, stock.map(func(i: ItemInstance) -> String: return i.instance_id)).ok, "appointment batch sale")
			else: action(s, "short_task")
	check.call(false, "bounded trading loop")

func finish(s: RunSession, next := true) -> void:
	if s._day.state.phase == &"open": action(s, "close_shop")
	if s._day.state.phase == &"closed_processing": action(s, "wait_until_seal")
	for command in ["resolve_night", "enter_room", "sleep", "finish_sleep"]: action(s, command)
	if next: action(s, "continue_run")
