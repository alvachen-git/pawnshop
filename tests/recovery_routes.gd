extends "res://tests/reckoning_routes.gd"

var search_night := 0
var finish_night := 0
func test_manifest() -> String:
	return "res://data/first_debt_recovery_manifest.json"

func run() -> void:
	var loaded := JsonContentProvider.new(test_manifest()).load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v31 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	for which in ["return", "pay", "sell_pay", "decline", "holding_pay", "natural", "natural_pay"]:
		if not OS.get_cmdline_user_args().is_empty() and which not in OS.get_cmdline_user_args(): continue
		route = which; begin = 25 if which == "late25" else 11
		run_def._initial_cash = 300 if route.begins_with("natural") else 2000
		search_night = 0; finish_night = 0
		journey()
		if failures: break
	print("RECOVERY ROUTES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func calm(s: RunSession) -> void:
	driver.drain(s)
	if PhoenixRecovery.hint_due(s._day.state):
		fixture(s, "hint"); verify(s, "hint"); fd(s, PhoenixRecovery.HINT, "heard")
	if SocialRules.blocked(s._day.state):
		var kind: String = s._day.state.social.pending.kind
		check(s.social_command("decline_supply" if kind == "supply" else "close" if kind == "closure" else "pay").ok, "resolve military " + kind)
	driver.drain(s)

func journey() -> void:
	var store := GhostReplayStore.new(); store.origin = {"seed": 42, "run_token": "0123456789abcdef0123456789abcdef"}
	var s := RunSession.new(run_def, catalog.content_version, store, catalog)
	for n in range(1, 31 if route.begins_with("natural") else begin + 10):
		calm(s)
		if FirstDebt.flag(s._day.state, "fd_search_promised") and DragonSearch.preparation(s._day.state, "dragon_search").is_empty():
			fixture(s, "search-ready")
			var cash := s._day.state.cash
			var count := PreparationService.count(s._day.state)
			act(s, "prep_dragon_search")
			check(PreparationService.count(s._day.state) == count + 1 and s._day.state.cash == cash, "search shares one free preparation")
			check(not s.execute("prep_dragon_search").ok, "no repeat search")
			search_night = n
			fixture(s, "search-sent"); verify(s, "search-sent")
		if FirstDebt.flag(s._day.state, "fd_search_message") and not FirstDebt.item_exists(s._day.state, FirstDebt.DRAGON) and not FirstDebt.settled(s._day.state):
			fixture(s, "invite-ready")
			if DragonSearch.prep_reason(s._day.state, "dragon_invite").is_empty():
				act(s, "prep_dragon_invite")
				fixture(s, "invited"); verify(s, "invited")
		if not FirstDebt.last(s._day.state, "fd_search_motive").is_empty() and not FirstDebt.flag(s._day.state, "fd_followed") and DragonSearch.prep_reason(s._day.state, "chen_invite").is_empty():
			act(s, "prep_chen_invite")
		if n >= 13 and route != "decline" and PhoenixRecovery.available(s._day.state) and PhoenixRecovery.prep_reason(s._day.state).is_empty():
			fixture(s, "phoenix-prep")
			var old_count := PreparationService.count(s._day.state)
			act(s, "prep_phoenix_invite")
			check(PreparationService.count(s._day.state) == old_count + 1, "phoenix invitation costs one preparation")
			check(not s.execute("prep_phoenix_invite").ok, "duplicate phoenix invitation rejected")
			fixture(s, "phoenix-invited"); verify(s, "phoenix-invited")
		act(s, "open_shop"); calm(s)
		for step in 180:
			if route == "miss" and n == search_night + 1: break
			if FirstDebt.chen_recognition_due(s._day.state): fd(s, "fd_chen_recognize", "ask"); continue
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.customer_id in ["fd_seller", "fd_chen"]: fixture(s, "seller" if v.customer_id == "fd_seller" else "chen")
				if v.customer_id == "fd_seller" and n == 11 and route != "decline":
					fixture(s, "first-seller")
					check(s.counter_command("reject", v.visit_id).ok, "first phoenix declined without reading documents")
					check(not FirstDebt.flag(s._day.state, "fd_receipt_read"), "decline does not grant document")
				elif v.customer_id == "fd_seller" and n >= begin:
					if not FirstDebt.flag(s._day.state, "fd_receipt_read"): fd(s, "fd_receipt", "read")
					if not FirstDebt.flag(s._day.state, "fd_mark_read"): fd(s, "fd_mark", "read")
					if route == "decline": check(s.counter_command("reject", v.visit_id).ok, "read documents without buying")
					elif s._day.state.cash >= 135 or not route.begins_with("natural"):
						check(s.counter_command("offer", v.visit_id, "", 100).ok, "buy recalled phoenix")
						check(not PhoenixRecovery.available(s._day.state), "owned phoenix cannot be invited again")
					else: check(s.counter_command("reject", v.visit_id).ok, "preserve nightly fees and rebook later")
				else:
					if not (route.begins_with("natural") and earn(s, v)): check(s.counter_command("reject", v.visit_id).ok, "ordinary transaction ends")
				calm(s)
			else:
				if progress(s): continue
				if route.begins_with("natural") and sell_goods(s): continue
				if not s.bell_model().enabled: break
				check(s.bell_command("wait").ok, "wait customer or appointment")
		if s._day.state.phase == &"open": act(s, "close_shop")
		if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
		act(s, "resolve_night")
		if n == search_night:
			check(s._day.state.pending_event_id == "ds_search_message", "search letter same night after accounts")
			fixture(s, "letter"); verify(s, "letter")
		calm(s)
		if not s._day.state.risk_pending.is_empty(): s.risk_command("retreat", s._day.state.risk_pending)
		calm(s); act(s, "enter_room"); calm(s)
		act(s, "sleep"); calm(s); act(s, "finish_sleep")
		act(s, "continue_run")
		print("NIGHT ", n, " CASH ", s._day.state.cash)
		if failures: return
		if FirstDebt.flag(s._day.state, "fd_followed"): break
	check(FirstDebt.settled(s._day.state), "route completes " + route)
	check(FirstDebt.flag(s._day.state, "fd_followed"), "followup " + route)
	if begin == 11 and route != "defer" and not route.begins_with("natural"): check(finish_night <= 17, "finish by night17")
	verify(s, route)

func compensation_ready(_s: RunSession) -> bool:
	return true

func progress(s: RunSession) -> bool:
	var st := s._day.state
	var n := st.current_night_index
	if n == begin - 1 and FirstDebt.saw_seller(st) and int(FirstDebt.last(st, "fd_seller").get("night", -1)) != n:
		fd(s, "fd_seller", "ask"); return true
	if n < begin: return false
	if DragonSearch.ready(s._day, s._counter):
		if not DragonSearch.quoted(st):
			fixture(s, "lu"); fd(s, "fd_dragon_quote", "fair" if st.social.reputation >= 0 else "dear")
			fixture(s, "quoted"); verify(s, "quoted")
		else:
			var cash := st.cash
			var quote := DragonSearch.price(st)
			if route.begins_with("natural") and cash < quote + 30:
				fd(s, "fd_dragon_deal", "later"); return true
			fd(s, "fd_dragon_deal", "buy")
			check(st.cash == cash - quote and FirstDebt.owned(st, FirstDebt.DRAGON) != null, "one cash posting and dragon")
			check(not s.event_command("fd_dragon_deal", "buy").ok, "no duplicate buy")
			fixture(s, "bought"); verify(s, "bought")
		return true
	var steps: Array = [["fd_ticket", "read"], ["fd_chen_request", "ask"], ["fd_family", "read"], ["fd_customer_ticket", "read"], ["fd_truth", "tell"]]
	if route not in ["pay", "sell_pay", "decline", "natural_pay"]: steps.append(["fd_search_motive", "later" if route == "defer" and FirstDebt.last(st, "fd_search_motive").is_empty() else "help"])
	if route in ["sell_pay", "sold_search"] and FirstDebt.owned(st, FirstDebt.PHOENIX) != null:
		var item := FirstDebt.owned(st, FirstDebt.PHOENIX)
		if s._commerce.trip_reason(s._day, catalog.get_definition("buyers", "buyer_lu")).is_empty():
			check(s.sell_batch("buyer_lu", [item.instance_id]).ok, "sell phoenix while investigation retained"); return true
	if route in ["pay", "sell_pay", "sold_search", "decline", "holding_pay", "natural_pay"]: steps.append(["fd_compensation", "offer"])
	steps.append(["fd_settle", "pay" if route in ["pay", "sell_pay", "sold_search", "decline", "holding_pay", "natural_pay"] else "return"])
	steps.append(["fd_followup", "listen"])
	for pair in steps:
		if pair[0] == "fd_compensation" and not compensation_ready(s): continue
		if route == "natural_pay" and pair[0] == "fd_settle" and st.cash < 340: continue
		if route in ["sold_search", "holding_pay"] and pair[0] in ["fd_compensation", "fd_settle"] and FirstDebt.owned(st, FirstDebt.DRAGON) == null: continue
		if not FirstDebt.last(st, pair[0]).is_empty() and not (pair[0] == "fd_search_motive" and not FirstDebt.flag(st, "fd_search_promised")): continue
		var e := catalog.get_definition("events", pair[0]) as EventDefinition
		if not CounterDomainValidator._contains_all(st.narrative_flags, e.required_flags): continue
		if not FirstDebt.reason(s._day, s._counter, pair[0], pair[1]).is_empty(): continue
		fixture(s, "before-" + str(pair[0])); fd(s, pair[0], pair[1]); fixture(s, "after-" + str(pair[0]))
		if pair[0] == "fd_settle": finish_night = n; print("SETTLED ", route, " NIGHT ", n)
		return true
	return false

func fixture(s: RunSession, stage: String) -> void:

	var directory := "res://.godot/qa/v%d%s/" % [catalog.content_version, "" if route == "return" else "-" + route]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(directory + stage + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, catalog.content_version)))

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	check(codec.decode(codec.encode(s._day.state, catalog.content_version), run_def, catalog.content_version, catalog, true) != null, "v31 replay " + label + " " + codec.error_message)
