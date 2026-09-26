extends "res://tests/special_guests_rules.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/special_guests_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	run_def._initial_cash = 6000; driver.check = check; driver.catalog = catalog
	var seed_value := 0
	while VarietyService.rng(seed_value,"special/swap/5").randi_range(0,99) >= 20 or VarietyService.rng(seed_value,"special/swap/6").randi_range(0,99) >= 20: seed_value += 1
	for accept in [false,true]: natural_swap(seed_value,accept)
	print("SPECIAL SWAP JOURNEY: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func natural_swap(seed_value:int,accept:bool) -> void:
	var s := fresh_special(seed_value)
	for n in range(1,13):
		driver.drain(s); act(s,"open_shop"); driver.drain(s)
		for step in 180:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				if v.customer_id == GhostGuests.SWAP:
					check(n >= 5 and n <= 12,"natural swap window")
					var snapshot := s.read_state(); s.counter_model(); s.counter_model()
					check(snapshot == s.read_state(),"swap UI does not redraw")
					verify(s,"natural swap arrived")
					(s._save as FailingStore).fail = true
					check(not s.counter_command("swap_accept" if accept else "swap_reject",v.visit_id).ok,"swap save failure")
					check(snapshot == s.read_state(),"swap failure exact rollback")
					(s._save as FailingStore).fail = false
					check(s.counter_command("swap_accept" if accept else "swap_reject",v.visit_id).ok,"natural swap choice")
					verify(s,"natural swap decision")
					check(s._day.state.ghost_visits.size() == 1 and s._day.state.exchange_history.size() == (1 if accept else 0),"appearance persisted once")
					return
				if n >= 3 and "pawn" in v.transaction_modes and v.purpose.is_empty():
					var customer := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
					var terms := catalog.get_definition("pawn_terms",VarietyService.terms_for(v,customer)) as PawnTermsDefinition
					check(s.counter_command("pawn",v.visit_id,"",maxi(1,roundi(v.trade.asking_price * terms.loan_ratio))).ok,"create natural collateral")
				else: s.counter_command("reject",v.visit_id)
				driver.drain(s)
			else:
				if not s.bell_model().enabled: break
				s.bell_command("wait"); driver.drain(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
		act(s,"resolve_night"); driver.drain(s); act(s,"enter_room"); driver.drain(s)
		act(s,"sleep"); driver.drain(s); act(s,"finish_sleep"); driver.drain(s)
		act(s,"continue_run")
	check(false,"selected seed must encounter a swap visitor")
