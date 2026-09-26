extends "res://tests/town_life_rules.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/town_life_v50_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v50 catalog")
	if not loaded.is_success(): quit(1);return
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id)
	driver.check=check;driver.catalog=catalog
	check(not catalog.has_definition("items","item_abacus"),"new catalog excludes abacus")
	check(TownLife.items(run_def).size()==6,"six new goods retained")
	for id in run_def.variety.customer_ids:
		var customer := catalog.get_definition("customers",id) as CustomerDefinition
		check("item_abacus" not in customer.item_pool,"ordinary pool removes abacus "+id)
	check("item_silver_earrings" in MedicineStory.pool(run_def,catalog),"Huaian can carry earrings")
	check("item_abacus" not in MedicineStory.pool(run_def,catalog),"Huaian no abacus")
	var seen := false
	for seed_value in 1000:
		var id := SpecialGuests.pick_item(seed_value,"earrings-pool",80,TownLife.items(run_def))
		if id=="item_silver_earrings":seen=true
		check(id!="item_abacus","special pool no abacus")
	check(seen,"special pool includes earrings")
	var definition := catalog.get_definition("items","item_silver_earrings") as ItemDefinition
	check(definition.category=="jewelry","jewelry category")
	for variant in definition.possible_variants:
		var s := fresh_special();var v := TownLifePreview.apply(s,"goods","silver_earrings",variant.id)
		check(s.counter_command("pawn",v.visit_id,"medium",v.trade.asking_price).ok and v.status=="pawned","earrings support pawn "+variant.id)
		check(v.item.ownership_state=="pledged","pledged item protected")
		s=fresh_special();v=TownLifePreview.apply(s,"goods","silver_earrings",variant.id)
		var store:=FailingStore.new();store.origin=s._day.state.ghost_origin.duplicate(true);store.fail=true;s._save=store
		var before:=s.read_state()
		check(not s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"failed sale save")
		check(GhostSaveCodec.same(before,s.read_state()),"earrings purchase rolls back")
	for policy in ["one_quote","wet_cloth"]:
		var s:=fresh_special();var v:=SpecialGuestsPreview.apply(s,policy,"item_silver_earrings")
		var expected:=34 if policy=="one_quote" else 23
		check(v.trade.asking_price==expected,"special price "+policy)
		check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok and v.status=="bought","special earrings purchase "+policy)
	print("TOWN EARRINGS: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)
