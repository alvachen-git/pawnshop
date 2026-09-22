extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/familiar_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "mirror chapter catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "familiar_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check
	driver.catalog = catalog
	for seed_value in 128:
		var rows := VarietyService.plan(run_def, catalog, seed_value)
		check(rows.size() == 42 and rows == VarietyService.plan(run_def, catalog, seed_value), "stable seeded chapter")
		check(rows[13].customer_id == "mirror_medicine" and rows[16].customer_id == "mirror_husband" and rows[19].customer_id == "mirror_moving", "fixed story people")
		var roles := {}
		for row in rows:
			if row.has("seven_role"): roles[row.seven_role] = row
		check(roles.size() == 7 and roles.pawn.night == 3, "pawn and pen roles retained")
	for route in ["ability", "pursue", "death", "reject", "sold", "missed"]: chapter(route)
	print("FAMILIAR MIRROR INTEGRATION: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func fresh(route: String) -> RunSession:
	return RunSession.new(run_def, 17, SaveManager.new("res://.godot/qa/familiar_mirror/runtime/%d_%s.json" % [Time.get_ticks_usec(), route]), catalog)

func study(s: RunSession, id: String, choice := "read") -> void:
	var result := s.study_command(id, choice)
	check(result.ok, "study " + id + ": " + result.message)

func chapter(route: String) -> void:
	var s := fresh(route)
	for n in range(1, 8):
		driver.open(s)
		if n == 6 and route != "reject":
			study(s, "wm_identity"); study(s, "wm_concealed")
		if n == 7 and route != "reject":
			study(s, "wm_motive")
			if route == "sold": check(not s.study_command("wm_choice", "use").ok, "cannot retain sold mirror")
			study(s, "wm_choice", "seek")
		if n not in [3, 4]: driver.work(s, "stop")
		else: chapter_work(s, route)
		if n == 4 and route != "reject":
			study(s, "wm_ticket"); study(s, "wm_life")
		driver.finish(s, "death" if route == "death" else "covered")
		if s._day.state.phase == &"dead": break
	if route == "death":
		check(s._day.state.phase == &"dead", "warned pursuit death")
		return
	check(s._day.state.phase == &"run_ended", "complete seven nights " + route)
	check(s._day.state.pawn_tickets.size() == 1 and s._day.state.pawn_tickets[0].status == "redeemed", "sixth night redemption")
	check(s._day.state.sale_records.filter(func(row: Dictionary) -> bool: return row.buyer_id == PreparationService.BUYER).size() == 2, "sixth night pen appointment")
	check(("wm_motive" in s._day.state.narrative_flags) == (route != "reject"), "chapter knowledge only from investigation")
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, 17)
	check(codec.decode(data, run_def, 17, catalog) != null, "final checkpoint " + codec.error_message)
	if route == "ability":
		var transfer := FileAccess.open("res://.godot/qa/familiar_mirror/cross_process.json", FileAccess.WRITE)
		transfer.store_string(JSON.stringify(data)); transfer.close()
		var forged := data.duplicate(true)
		forged.mirror_history.clear()
		check(codec.decode(forged, run_def, 17, catalog) == null, "testimony requires mirror provenance")
		forged = data.duplicate(true)
		forged.event_history = forged.event_history.filter(func(row: Dictionary) -> bool: return row.event_id != "wm_notes")
		check(codec.decode(forged, run_def, 17, catalog) == null, "cannot forge investigation source")
		forged = data.duplicate(true)
		forged.mirror_history.insert(1, forged.mirror_history[0].duplicate(true))
		check(codec.decode(forged, run_def, 17, catalog) == null, "no duplicate use on load")
		var library := SaveLibrary.new("res://.godot/qa/familiar_mirror/runtime/library_%d.json" % Time.get_ticks_usec())
		check(library.write_entry("manual/1", s._day.state, run_def, 17, catalog), "manual save " + library.error_message)
		check(not library.read_entry("manual/1").is_empty(), "manual restore " + library.error_message)

func chapter_work(s: RunSession, route: String) -> void:
	var n := s._day.state.current_night_index
	for step in 160:
		if s._day.state.game_minutes >= 480: return
		var v := s._counter.customers.active(s._day.state)
		if v == null:
			if not s.bell_model().enabled: driver.action(s, "short_task")
			else: check(s.bell_command("wait").ok, "bell reaches next story guest")
			continue
		var role: String = VarietySaveCodec.selection(s._day.state, v.visit_id).get("seven_role", "")
		if v.item.definition_id == "item_weeping_mirror":
			if route == "reject": check(s.counter_command("reject", v.visit_id).ok, "refuse mirror")
			else:
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok, "buy mirror")
				study(s, "wm_notes")
		elif v.customer_id in ["mirror_medicine", "mirror_moving"]:
			if route == "ability":
				var mirror: ItemInstance = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.definition_id == "item_weeping_mirror")[0]
				if s._risk.covered(s._day.state, mirror.instance_id): check(s.risk_command("uncover", mirror.instance_id).ok, "uncover for normal use")
				check(not s.counter_command("question", v.visit_id, "mirror_verify").ok, "hidden question requires glimpse")
				var before := v.item.to_data().duplicate(true)
				var stamp := s._day.state.game_minutes
				check(s.mirror_command("glimpse_" + v.visit_id.get_slice("/", 2), "peek").ok, "glimpse trading motive")
				check(s._day.state.game_minutes == stamp + 5 and v.item.to_data() == before and not s.mirror_pending(), "ordinary glimpse costs five without evidence or forced followup")
				check(s.counter_command("question", v.visit_id, "mirror_verify").ok, "verify glimpse")
				var reserve := v.trade.reserve_price
				var patience := v.trade.patience
				check(s.counter_command("concession", v.visit_id).ok, "discuss verified situation")
				check(v.trade.reserve_price == reserve - (5 if n == 3 else 0), "urgency and ordinary prices differ")
				check(v.trade.patience == patience - (1 if n == 4 else 0), "wrong hurry costs patience")
				check(s.counter_command("question", v.visit_id, "circumstance").ok, "ordinary question shares situation")
				check(not s.counter_command("concession", v.visit_id).ok, "no duplicate situation discount")
				var count := s._day.state.action_count
				for i in 3: s.risk_model(); s.counter_model()
				check(s._day.state.action_count == count, "free rereading")
			check(s.counter_command("reject", v.visit_id).ok, "finish sample")
		elif v.customer_id == "mirror_husband":
			if route == "missed":
				while v.status == "active": driver.action(s, "short_task")
				continue
			if route == "sold":
				check(s.counter_command("reject", v.visit_id).ok, "leave husband before sale")
				var mirror: ItemInstance = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.definition_id == "item_weeping_mirror")[0]
				check(s.sell_batch("buyer_mirror", [mirror.instance_id]).ok, "sell mirror through existing channel")
				check(not s.mirror_command("midnight_old_ticket", "peek").ok, "no remote use after sale")
				continue
			if route == "ability":
				check(not s.mirror_command("midnight_old_ticket", "peek").ok, "night limit spans ordinary and story")
			elif route in ["pursue", "death"]:
				check(s.mirror_command("midnight_old_ticket", "peek").ok, "story glimpse")
				check(s.mirror_command("midnight_old_ticket", "pursue").ok, "warned pursuit")
			check(s.counter_command("appraise", v.visit_id, "observe").ok, "ordinary watch inspection")
			check(s.counter_command("appraise", v.visit_id, "inspect").ok and "flaw" in v.item.revealed_clue_ids, "watch flaw requires normal inspection")
			check(s.counter_command("reject", v.visit_id).ok, "dismiss husband")
		elif role == "pawn": check(s.counter_command("pawn", v.visit_id, "", 40).ok, "pawn sample retained")
		elif role in ["pen4", "pen5"]:
			var result := s.counter_command("offer", v.visit_id, "", v.trade.asking_price)
			check(result.ok, "pen sample retained: " + result.message + " cash=" + str(s._day.state.cash))
		else: check(s.counter_command("reject", v.visit_id).ok, "ordinary customer")
	check(false, "bounded chapter work")
