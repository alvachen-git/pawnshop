extends "res://tests/watch_negotiation.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/named_wealthy_manifest.json").load_catalog()
	check(loaded.is_success(),"v37 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,37,store,catalog)

func run() -> void:
	if not setup(): quit(1); return
	var state := RunState.create(run_def); state.ghost_catalog = catalog
	var old := JsonContentProvider.new("res://data/watch_patterns_manifest.json").load_catalog()
	var old_run := old.catalog.get_definition("runs",old.catalog.default_run_id) as RunDefinition
	check(not WealthyCustomers.fixed_people(old_run),"v36 identity generation preserved")
	for cid in WealthyCustomers.NAMES:
		var definition := catalog.get_definition("customers",cid) as CustomerDefinition
		for seed_value in 12:
			state.run_seed = seed_value
			for night in [2,6,10]:
				var slot := {"visit_id":"named_wealthy_ten/%d/example" % night,"night":night,"arrival":100}
				var row := WealthyCustomers.make_row(state,run_def,catalog,slot,cid,[])
				check(row.person == WealthyCustomers.person(definition),"stable name and identity across nights and seeds")
				check(VarietyService.name_for(row.person,definition) == WealthyCustomers.NAMES[cid]+" · "+definition.terms.display_name,"name and profession")
				var legacy_slot := slot.duplicate(true); legacy_slot.visit_id = String(slot.visit_id).replace("named_wealthy_ten/","watch_patterns_ten/")
				var legacy := WealthyCustomers.make_row(state,old_run,old.catalog,legacy_slot,cid,[])
				for field in ["item_id","variant_id","transaction_modes","terms_id"]:
					check(row[field] == legacy[field],"fixed names do not reroll goods, transaction or redemption")
		var s := fresh_growth(); PrecisionPreview.apply(s,2,definition.item_pool[0].trim_prefix("item_luxury_"))
		var v: CustomerVisit = s._day.state.visits[0]
		check(v.person == WealthyCustomers.person(definition),"preview shares production identity")
		check(s.counter_model().visual.customer_name.begins_with(WealthyCustomers.NAMES[cid]),"counter displays full name")
		var snapshot := RunSnapshot.copy(s._day.state)
		check(snapshot.visits[0].person == v.person,"snapshot retains fixed identity")
		check(s.counter_command("pawn",v.visit_id,"",v.trade.asking_price).ok,"fixed person pawns item")
		var ticket: PawnTicket = s._day.state.pawn_tickets.back()
		check(ticket.person == WealthyCustomers.person(definition),"ticket retains same full name and identity")
		s._day.state.current_night_index = ticket.due_night; s._day.state.game_minutes = 0
		PawnReturnService.prepare(s._day.state,catalog); PawnReturnService.arrive(s._day.state)
		check(s.counter_model().visual.customer_name == WealthyCustomers.NAMES[cid]+" · "+definition.terms.display_name,"redemption returns as same named person")
	# Reproduce the screenshot without changing the real watch or counting damage twice.
	for personality in ["easy","careful","firm"]:
		var s := fixture35("sound","intact","stable","sell",personality); hear(s)
		var v: CustomerVisit = s._day.state.visits[0]
		check(v.trade.asking_price == 385,"initial real-watch asking")
		check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"inspect intact exterior")
		check(say(s,{"identity":"imitation","running":"stopping","exterior":"observed"}).ok,"claims accepted")
		check(v.trade.asking_price == {"easy":39,"careful":212,"firm":385}[personality],"385 to 39 is full concession, not repeated discounts")
		check(v.item.goods.watch_value.actual == 500,"accepted false claims cannot alter actual value")
		check(ReputationService.basis(s._day.state,v) == 350,"false claims cannot lower public reward basis")
		var current := v.trade.asking_price; WatchNegotiation.reprice(s._day.state,v)
		check(v.trade.asking_price == current,"reprice idempotent")
	# Genuine production save can resolve the new version and cold-replay.
	var s := second_night(); InvestigationSaveCodec.clear_cache()
	var library := SaveLibrary.new("res://.godot/qa/named-wealthy-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/named_wealthy_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,37,catalog),"v37 disk write")
	var read := library.read_entry("manual/1")
	check(not read.is_empty() and read.catalog.content_version == 37,"v37 disk read")
	if not read.is_empty(): check(GhostSaveCodec.same(s.read_state(),read.state.to_read_model()),"exact cold replay")
	print("NAMED WEALTHY: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
