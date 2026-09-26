extends "res://tests/special_guests_swap_journey.gd"

func fresh_special(seed_value := 42) -> RunSession:
	var store := FailingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 46, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, 46)
	var restored := codec.decode(payload, run_def, 46, catalog, true)
	check(restored != null, "cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact replay " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/special_guests_late_v46_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v46 content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var bootstrap := Bootstrap.new()
	bootstrap.manifest_path = "res://data/special_guests_late_v46_manifest.json"
	bootstrap.save_path = "user://special_guests_v46/autosave_v46.json"
	check(bootstrap.initialize().is_success(), "new entry initializes")
	check(bootstrap.session._save.library.path == "user://special_guests_v46/library.json", "isolated v46 library")
	bootstrap.free()
	verify(fresh_special(), "fresh")
	schedule_matrix()
	swap_boundaries()
	run_def._initial_cash = 6000
	journey_late()
	var seed_value := 0
	while VarietyService.rng(seed_value,"special/swap/5").randi_range(0,99) >= 20 or VarietyService.rng(seed_value,"special/swap/6").randi_range(0,99) >= 20: seed_value += 1
	for accept in [false,true]: natural_swap(seed_value,accept)
	print("SPECIAL GUESTS V46: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func schedule_matrix() -> void:
	var counts := {}
	var ordinary_late := 0
	for seed_value in 24:
		var s := fresh_special(seed_value)
		var st := s._day.state
		for n in range(2,19):
			st.current_night_index = n
			var d := SpecialGuests.data(st)
			if n in [4,8,15]: d.closed_stage = [4,8,15].find(n); d.closed_due = n
			var rows := OpeningPreparation.plan(st,run_def,catalog)
			var snapshot := st.to_read_model()
			check(rows == OpeningPreparation.plan(st,run_def,catalog) and snapshot == st.to_read_model(), "repeat plan stable")
			for row in rows:
				if int(row.night) != n: continue
				if not row.has("special_key"):
					if int(row.arrival) >= 240 and not NightMarketPlan.protected(row): ordinary_late += 1
					continue
				var policy := "closed" if String(row.special_key).begins_with("closed/") else String(row.night_policy)
				var band := SpecialGuests.window(st,policy)
				check(row.arrival >= band[0] and row.arrival <= band[1], "arrival band " + policy)
				check(rows.all(func(other: Dictionary) -> bool: return other.night != n or other.visit_id == row.visit_id or absi(int(other.arrival)-int(row.arrival)) >= 5), "no arrival collision")
				counts[policy] = int(counts.get(policy,0)) + 1
				d.seen[row.special_key] = {"night":n,"visit_id":row.visit_id}
				if policy == "closed":
					d.closed_stage += 1
					if d.closed_stage < 3: d.closed_due = [4,8,15][d.closed_stage]
	check(counts == {"closed":72,"one_quote":72,"wet_cloth":24}, "all fixed and random appointments across seeds " + str(counts))
	check(ordinary_late > 24, "ordinary visitors retained after 22:00")
	var s := fresh_special(); var st := s._day.state
	st.current_night_index = 8
	SpecialGuests.data(st).closed_stage = 1; SpecialGuests.data(st).closed_due = 8
	var fixed := {"night":8,"visit_id":"protected","arrival":300,"customer_id":"customer_citizen","context_id":"story","seven_role":"story","person":{"name":"故事人物"}}
	var rows: Array[Dictionary] = [fixed]
	var result := SpecialGuests.overlay(st,run_def,catalog,rows)
	check(fixed in result and result.size() == 2 and result[1].arrival != 300, "protected appointment retained; bundle gets separate late slot")
	var v := SpecialGuestsPreview.apply(s,"closed")
	MilitaryService.suspend(s._day)
	check(v.status == "suspended" and not SpecialGuests.data(st).closed_failed, "forced closure preserves chain")
	check(SpecialGuests.data(st).closed_due == st.current_night_index+1, "forced closure deferred")
	# Redemption delay is already applied to ordinary visits, but never moves specials outside their band.
	for policy in ["closed","one_quote","wet_cloth"]:
		v = SpecialGuestsPreview.apply(s,policy,"item_blue_bowl")
		var row := VarietySaveCodec.selection(st,v.visit_id)
		v.arrival = int(row.arrival) + 150; v.expires_at = v.arrival + 70
		SpecialGuests.prepare(st,v,row,catalog.get_definition("items",v.item.definition_id))
		check(v.arrival == row.arrival and v.expires_at == row.arrival + row.wait_minutes, "absolute schedule ignores redemption delay " + policy)

func swap_boundaries() -> void:
	for pair in [[295,300],[300,295],[300,300],[420,420],[300,425],[425,425]]:
		var s := fresh_special(); var st := s._day.state
		var v := SpecialGuestsPreview.apply(s,"one_quote","item_blue_bowl")
		st.current_night_index = 5; st.game_minutes = pair[1]
		v.person = {"id":"ordinary","name":"王先生"}; v.night_policy = ""; v.arrival = pair[0]; v.expires_at = 540
		v.visit_id = "%s/5/%s" % [run_def.id,run_def.customer_slots.back().id]
		st.ordinary_selections.assign([{"visit_id":v.visit_id,"night":5,"context_id":"ordinary","customer_id":"customer_citizen"}])
		while VarietyService.rng(st.run_seed,"special/swap/5").randi_range(0,99) >= 20: st.run_seed += 1
		var item := ItemInstance.new(); item.instance_id = "pledged"; item.definition_id = "item_blue_bowl"; item.selected_variant_id = "sound"; item.ownership_state = "pledged"
		st.inventory_instances.append(item)
		var ticket := PawnTicket.new(); ticket.ticket_id = "ticket"; ticket.item_instance_id = item.instance_id; ticket.principal = 20; ticket.due_night = 18; ticket.customer_id = "customer_citizen"; ticket.terms_id = "sample_three_redeem"
		st.pawn_tickets.append(ticket)
		GhostGuests.arrive(st,v)
		var allowed: bool = pair[0] >= 300 and pair[0] <= 420 and pair[1] >= 300 and pair[1] <= 420
		check((v.customer_id == GhostGuests.SWAP) == allowed, "swap actual counter clock " + str(pair))
		check(SpecialGuests.data(st).swap_rolls.is_empty() == not allowed, "outside hours cannot consume nightly draw")

func journey_late() -> void:
	var s := fresh_special(42)
	var nights: Array = []; var hats := 0; var wet := 0
	for n in range(1,19):
		driver.drain(s); act(s,"open_shop"); driver.drain(s)
		for step in 180:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				var row := VarietySaveCodec.selection(s._day.state,v.visit_id)
				if row.has("special_key"):
					check(v.arrival >= 240, "no early special arrival")
					verify(s, "arrival night%d" % n)
					if v.customer_id == GhostGuests.CLOSED:
						nights.append(n)
						var before := s.read_state()
						(s._save as FailingStore).fail = true
						check(not s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok and before == s.read_state(), "bundle purchase failure rolls back clock and chain")
						(s._save as FailingStore).fail = false
						v = s._counter.customers.active(s._day.state)
						check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok, "bundle purchase")
						check(("莫太早落闩" in s.message) == (n < 15), "late return hint only before further visits")
					else:
						if v.night_policy == "one_quote": hats += 1
						else: wet += 1
						s.counter_command("reject",v.visit_id)
					verify(s,"transaction night%d" % n)
				else: s.counter_command("reject",v.visit_id)
				driver.drain(s)
			else:
				if not s.bell_model().enabled: break
				s.bell_command("wait"); driver.drain(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
		act(s,"resolve_night"); driver.drain(s); act(s,"enter_room"); driver.drain(s)
		act(s,"sleep"); driver.drain(s); act(s,"finish_sleep"); driver.drain(s)
		if n in [4,8,15,18]: verify(s,"night%d" % n)
		if n < 18: act(s,"continue_run")
	check(nights == [4,8,15], "bundle fixed return nights preserved")
	check(hats == 3 and wet == 1, "hat and wet appearances " + str([hats,wet]))
	check(s._day.state.narrative_flags.count(SpecialGuests.QUEST_FLAG) == 1, "quest qualification once")
