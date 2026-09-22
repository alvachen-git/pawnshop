extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v22 catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	for seed_value in 128:
		var rows := VarietyService.plan(run_def, catalog, seed_value)
		check(rows.size() == 42 and rows[19].customer_id == GhostGuests.CLOSED, "reserved guest and six seats")
		check(rows == VarietyService.plan(run_def, catalog, seed_value), "stable seed")
	for route in ["accept", "reject", "inspect", "no_pawn", "sold", "pursue", "death", "unused", "missed"]:
		journey(route)
	print("LIVING MIRROR TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func session(seed_value := 42) -> RunSession:
	var store := GhostReplayStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 22, store, catalog)

func act(s: RunSession, cmd: String) -> void:
	var result := s.execute(cmd)
	check(result.ok, cmd + ": " + result.message)

func study(s: RunSession, id: String, choice := "read") -> void:
	var result := s.study_command(id, choice)
	check(result.ok, id + ": " + result.message)

func journey(route: String) -> void:
	var s := session()
	var saw_swap := false
	for n in range(1, 8):
		driver.drain(s)
		if n == 7 and route == "accept":
			check(s._day.state.person_deaths.size() == 1, "notice at seventh opening")
			check(s.seven_notice().contains("替物"), "specific death notice")
		act(s, "open_shop")
		driver.drain(s)
		var held := LivingMirror.held(s._day.state)
		if held != null and s._risk.covered(s._day.state, held.instance_id): check(s.risk_command("uncover", held.instance_id).ok, "uncover each trading night")
		for step in 180:
			if s._day.state.game_minutes >= 480: break
			if route == "missed" and n == 3 and s._day.state.game_minutes >= 240:
				act(s, "close_shop"); break
			var returning := PawnReturnService.current(s._day.state)
			if not returning.is_empty():
				var mirror := LivingMirror.held(s._day.state)
				if mirror != null and route != "unused":
					if s._risk.covered(s._day.state, mirror.instance_id): check(s.risk_command("uncover", mirror.instance_id).ok, "uncover for return")
					check(s.inspect_customer(returning.id).ok, "ordinary return can be mirrored")
					check(s._day.state.soul_history.back().result == "living", "return is living")
				check(s.counter_command(returning.command, returning.id).ok, "complete return")
				continue
			var v := s._counter.customers.active(s._day.state)
			if v == null:
				if s.bell_model().enabled: check(s.bell_command("wait").ok, "wait")
				else: act(s, "short_task")
				continue
			var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
			if v.item.definition_id == "intro_silver_hairpin":
				check(s.counter_command("offer", v.visit_id, "", v.trade.reserve_price).ok, "opening acquisition")
				driver.drain(s)
			elif v.item.definition_id == "item_weeping_mirror":
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "acquire mirror")
				study(s, "wm_notes")
			elif v.customer_id == GhostGuests.SWAP:
				saw_swap = true
				check(route != "no_pawn", "only when collateral exists")
				if LivingMirror.held(s._day.state) != null and route != "unused":
					check(s.inspect_customer(v.visit_id).ok, "mirror swap visitor")
					check(s._day.state.soul_history.back().result == "ghost", "swap visitor has no reflection")
				var before := s.read_state()
				s.counter_model(); s.risk_model(); s.counter_model()
				check(GhostSaveCodec.same(before, s.read_state()), "views do not reroll target")
				var cash := s._day.state.cash
				var result := s.counter_command("swap_accept" if route in ["accept", "sold"] else "swap_reject", v.visit_id)
				check(result.ok, "exchange decision " + result.message)
				check(s._day.state.cash == cash + (80 if route in ["accept", "sold"] else 0), "exact eighty once")
				check(not s.counter_command("swap_accept", v.visit_id).ok, "no duplicate exchange")
				var codec := SaveCodec.new()
				# UI read models must also support exchanged-out originals and substitute receipts.
				s.counter_model()
			elif v.customer_id == GhostGuests.CLOSED:
				if route not in ["sold", "unused"]:
					for repeat in 3: check(s.inspect_customer(v.visit_id).ok, "unlimited same guest")
					check(s._day.state.soul_history.back().result == "ghost", "closed bundle ghost")
				check(s.counter_command("question", v.visit_id, "origin").ok, "questions allowed")
				if route == "inspect":
					var cost := (catalog.get_definition("items", v.item.definition_id) as ItemDefinition).appraisal_actions[0]
					var minute := s._day.state.game_minutes
					check(s.counter_command("appraise", v.visit_id, cost.id).ok, "inspection causes departure")
					check(v.status == "inspection_refused" and v.item.revealed_clue_ids.is_empty() and v.item.completed_action_ids.is_empty(), "no inspection result")
					check(s._day.state.game_minutes == minute + cost.minutes, "inspection time paid")
				else: check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "ghost goods can be bought")
			elif v.customer_id == "mirror_husband":
				if route == "unused":
					check(s.counter_command("reject", v.visit_id).ok, "no mirror use"); continue
				check(s.inspect_customer(v.visit_id).ok, "husband can be scanned")
				check(s._day.state.soul_history.back().result == "living", "husband alive")
				check(s.mirror_command("midnight_old_ticket", "peek").ok, "story independent of scans")
				check(s.mirror_command("midnight_old_ticket", "pursue" if route in ["pursue", "death"] else "stop").ok, "story decision")
				check(s.counter_command("reject", v.visit_id).ok, "leave husband")
				if route == "sold":
					var mirror := LivingMirror.held(s._day.state)
					check(s.sell_batch("buyer_mirror", [mirror.instance_id]).ok, "sell mirror")
			elif row.get("seven_role", "") == "pawn" and route != "no_pawn":
				check(s.counter_command("pawn", v.visit_id, "", 40).ok, "designated pawn")
			else: check(s.counter_command("reject", v.visit_id).ok, "ordinary reject")
		if n == 4:
			study(s, "wm_ticket"); study(s, "wm_life")
		if n == 6:
			study(s, "wm_identity"); study(s, "wm_concealed")
		if n == 7:
			study(s, "wm_motive"); study(s, "wm_choice", "seal" if route == "unused" else "use" if route == "missed" else "seek")
		var mirror := LivingMirror.held(s._day.state)
		if mirror != null and not s._risk.covered(s._day.state, mirror.instance_id): check(s.risk_command("cover", mirror.instance_id).ok, "cover before closing")
		if s._day.state.phase == &"open": act(s, "close_shop")
		act(s, "wait_until_seal"); act(s, "resolve_night")
		if not s._day.state.risk_pending.is_empty(): check(s.risk_command("retreat", s._day.state.risk_pending).ok, "shop response")
		act(s, "enter_room"); driver.drain(s); act(s, "sleep"); driver.drain(s)
		if not s._day.state.risk_pending.is_empty(): check(s.risk_command("defy" if route == "death" else "retreat", s._day.state.risk_pending).ok, "personal response")
		if s._day.state.phase == &"dead": break
		act(s, "finish_sleep"); act(s, "continue_run")
		if route == "accept" and n in [4, 5, 6]: checkpoint(s, "night%d" % n)
	check((not saw_swap) == (route in ["no_pawn", "death", "missed"]), "conditional swap visitation " + route)
	if route != "death": check(s._day.state.phase == &"run_ended", "seven nights finish")
	checkpoint(s, route)
	var codec := SaveCodec.new()
	var saved := codec.encode(s._day.state, 22)
	var forged := saved.duplicate(true)
	forged.cash += 80
	check(codec.decode(forged, run_def, 22, catalog) == null, "forged money rejected")
	if route == "accept":
		for field in ["exchange_history", "person_deaths", "soul_history"]:
			forged = saved.duplicate(true); forged[field].clear()
			check(codec.decode(forged, run_def, 22, catalog) == null, "forged " + field)

func checkpoint(s: RunSession, label: String) -> void:
	var store := SaveManager.new("res://.godot/qa/v22/" + label + ".json")
	store.catalog = catalog
	check(store.save_state(s._day.state, run_def, 22), "save " + label + ": " + store.error_message)
	var restored := store.load_state(run_def, 22)
	check(restored != null and GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "load exact " + label + ": " + store.error_message)
