extends "res://tests/town_life_rules.gd"

func run() -> void:
	for version in [48,49,50]:
		var manifest := "res://data/town_life_manifest.json" if version == 48 else "res://data/town_life_v%d_manifest.json" % version
		var loaded := JsonContentProvider.new(manifest).load_catalog()
		check(loaded.is_success(),"load version " + str(version))
		if not loaded.is_success(): continue
		catalog=loaded.catalog; run_def=catalog.get_definition("runs",catalog.default_run_id)
		driver.check=check; driver.catalog=catalog
		var prices := {"item_abacus":[48,32,12],"item_copper_handwarmer":[42,28,14]} if version == 48 else {"item_abacus":[12,7,2],"item_copper_handwarmer":[65,42,18]}
		if version == 50: prices={"item_silver_earrings":[38,25,9],"item_copper_handwarmer":[65,42,18]}
		for id in prices:
			var definition := catalog.get_definition("items",id) as ItemDefinition
			check(definition.base_value == prices[id][0],"base value "+str(version)+id)
			for index in 3:
				var variant = definition.possible_variants[index]
				check(variant.true_value==prices[id][index],"condition value "+id+variant.id)
				var s := fresh_special()
				var v := TownLifePreview.apply(s,"goods",id,variant.id)
				var customer := catalog.get_definition("customers",v.customer_id) as CustomerDefinition
				check(v.trade.asking_price==roundi(definition.base_value*customer.terms.ask_multiplier),"opening price uses correct version")
				for action in ["observe","inspect"]:
					check(s.counter_command("appraise",v.visit_id,action).ok,"inspect repriced goods")
				check(variant.id in v.item.revealed_clue_ids,"actual condition revealed")
				var price := v.trade.asking_price
				var before := s._day.state.cash
				check(s.counter_command("offer",v.visit_id,"",price).ok and v.status=="bought","buy repriced goods")
				check(s._day.state.cash==before-price and v.item.acquisition_price==price,"cash and cost agree")
				var buyer := catalog.get_definition("buyers","buyer_lu") as BuyerDefinition
				var commerce := CommerceService.new(catalog)
				check(commerce.base_quote(v.item,buyer)==maxi(1,roundi(prices[id][index]*buyer.value_multiplier)),"Lu respects actual condition value")
				var expected := RecyclerPolicy.price(s._day.state,definition)
				s._day.state.phase=&"pre_open";s._day.state.game_minutes=0
				before=s._day.state.cash
				check(s.sell_batch(RecyclerPolicy.BUYER,[v.item.instance_id]).ok,"sell repriced goods")
				check(s._day.state.cash==before+expected and v.item.ownership_state=="sold","sale cash matches quote")
		var b := Bootstrap.new(); b.manifest_path=manifest
		b.save_path="user://town-prices-qa-v%d/auto.json" % version
		check(b.initialize().is_success(),"bootstrap version "+str(version))
		check(b.session._save.library.path=="user://town_life_v%d/library.json" % version,"separate save library")
		b.free()
		verify(fresh_special(),"new run version "+str(version))
	print("TOWN PRICES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)
