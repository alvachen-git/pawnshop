extends "res://tests/run_first_debt.gd"

var route := ""
var begin := 11
func run() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	check(loaded.is_success(), "catalog")
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._initial_cash = 2000
	driver.check = check; driver.catalog = catalog
	for which in ["return", "pay", "lie", "sell_pay", "decline", "late18", "late25", "late50", "natural", "natural_pay", "natural_late25"]:
		if not OS.get_cmdline_user_args().is_empty() and which not in OS.get_cmdline_user_args(): continue
		print("ROUTE ", which)
		route = which
		run_def._initial_cash = 300 if which.begins_with("natural") else 2000
		begin = 25 if which == "natural_late25" else int(which.trim_prefix("late")) if which.begins_with("late") else 11
		journey()
		if failures: break
	print("FIRST DEBT ROUTES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func journey() -> void:
	var store := GhostReplayStore.new(); store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var s := RunSession.new(run_def, 29, store, catalog)
	for n in range(1, begin + (9 if route.begins_with("natural") else 5)):
		driver.drain(s); act(s, "open_shop"); driver.drain(s)
		check(s._day.state.visits.filter(func(v: CustomerVisit) -> bool: return not v.visit_id.contains("husband")).size() >= 6, "ordinary six retained")
		for step in 130:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if route.begins_with("natural") and v.customer_id == "fd_seller": fixture(s, "seller")
				if route.begins_with("natural") and v.customer_id == "fd_chen": fixture(s, "chen")
				if v.customer_id == "fd_seller" and n >= begin:
					if not FirstDebt.flag(s._day.state, "fd_receipt_read"): fd(s, "fd_receipt", "read")
					if not FirstDebt.flag(s._day.state, "fd_mark_read"): fd(s, "fd_mark", "read")
					if route != "decline": check(s.counter_command("offer", v.visit_id, "", 100).ok, "buy phoenix100")
					else: s.counter_command("reject", v.visit_id)
				else:
					if not (route.begins_with("natural") and earn(s, v)): s.counter_command("reject", v.visit_id)
				driver.drain(s)
			else:
				if progress(s): continue
				if route.begins_with("natural") and sell_goods(s): continue
				if not s.bell_model().enabled: break
				s.bell_command("wait")
		if s._day.state.phase == &"open": act(s, "close_shop")
		if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
		act(s, "resolve_night"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		driver.drain(s); act(s, "enter_room"); driver.drain(s)
		act(s, "sleep"); driver.drain(s); act(s, "finish_sleep")
		if n == 18 and route == "natural": fixture(s, "summary18")
		act(s, "continue_run")
		if failures: return
	check(FirstDebt.settled(s._day.state), "completed " + route)
	check(FirstDebt.flag(s._day.state, "fd_followed"), "next night followup " + route)
	verify(s, route)

func progress(s: RunSession) -> bool:
	var st := s._day.state
	var n := st.current_night_index
	if n == begin - 1 and FirstDebt.saw_seller(st) and int(FirstDebt.last(st, "fd_seller").get("night", -1)) != n:
		fd(s, "fd_seller", "ask"); return true
	if n < begin: return false
	var steps: Array = [["fd_ticket", "read"], ["fd_lu", "ask"], ["fd_chen_request", "ask"], ["fd_family", "read"], ["fd_customer_ticket", "read"]]
	if route == "lie": steps.append(["fd_truth", "lie"]); steps.append(["fd_amend", "tell"])
	else: steps.append(["fd_truth", "tell"])
	if route not in ["pay", "lie", "decline", "natural_pay"]: steps.append(["fd_dragon", "buy"])
	if route == "sell_pay" and FirstDebt.owned(st, FirstDebt.DRAGON) != null:
		var a := FirstDebt.owned(st, FirstDebt.PHOENIX); var b := FirstDebt.owned(st, FirstDebt.DRAGON)
		if a != null and s._commerce.trip_reason(s._day, catalog.get_definition("buyers", "buyer_lu")).is_empty():
			var cash := st.cash
			check(s.sell_batch("buyer_lu", [a.instance_id, b.instance_id]).ok, "pair sale")
			check(st.cash == cash + 320, "fixed pair320")
			return true
	if route in ["pay", "lie", "sell_pay", "decline", "natural_pay"]: steps.append(["fd_compensation", "offer"])
	steps.append(["fd_settle", "pay" if route in ["pay", "lie", "sell_pay", "decline", "natural_pay"] else "return"])
	steps.append(["fd_followup", "listen"])
	for pair in steps:
		if not FirstDebt.last(st, pair[0]).is_empty(): continue
		if pair[0] == "fd_settle" and route == "natural_pay" and st.cash < 340: continue
		if pair[0] == "fd_settle" and route == "sell_pay" and FirstDebt.owned(st, FirstDebt.PHOENIX) != null: continue
		var e := catalog.get_definition("events", pair[0]) as EventDefinition
		if not CounterDomainValidator._contains_all(st.narrative_flags, e.required_flags): continue
		if not FirstDebt.reason(s._day, s._counter, pair[0], pair[1]).is_empty(): continue
		if route.begins_with("natural") or route == "return": fixture(s, "before-" + str(pair[0]))
		fd(s, pair[0], pair[1])
		if route.begins_with("natural") or route == "return": fixture(s, "after-" + str(pair[0]))
		return true
	return false

func earn(s: RunSession, v: CustomerVisit) -> bool:
	if v.item.definition_id.begins_with("fd_"): return false
	var item := catalog.get_definition("items", v.item.definition_id) as ItemDefinition
	if item.item_type != "normal" or not v.night_policy.is_empty() or v.trade.reserve_price > s._day.state.cash - 35: return false
	var buyer := catalog.get_definition("buyers", "buyer_lu") as BuyerDefinition
	if v.trade.reserve_price > s._day.state.cash - 60: return false
	if s._commerce.quote(v.item, buyer) < v.trade.reserve_price + 12: return false
	return s.counter_command("offer", v.visit_id, "", v.trade.reserve_price).ok

func sell_goods(s: RunSession) -> bool:
	for id in run_def.buyer_ids:
		var buyer := catalog.get_definition("buyers", id) as BuyerDefinition
		if not s._commerce.trip_reason(s._day, buyer).is_empty(): continue
		var stock: Array = []
		for item in s._day.state.inventory_instances:
			if (item.definition_id.begins_with("fd_") and not FirstDebt.settled(s._day.state)) or not s._commerce.item_reason(s._day, item, buyer).is_empty(): continue
			if s._commerce.quote(item, buyer) > item.acquisition_price: stock.append(item.instance_id)
		if not stock.is_empty(): return s.sell_batch(id, stock).ok
	return false

func fixture(s: RunSession, stage: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/v29/"))
	var file := FileAccess.open("res://.godot/qa/v29/" + ("funded-" if route == "return" else "pay-" if route == "natural_pay" else "late25-" if route == "natural_late25" else "") + stage + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 29)))

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(s._day.state, 29), run_def, 29, catalog, true) != null, "v29 replay " + label + codec.error_message)
