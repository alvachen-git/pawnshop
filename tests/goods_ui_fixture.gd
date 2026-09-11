extends "res://tests/run_goods_expertise.gd"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var chosen := {}; var wanted := []
	for seed_value in 512:
		var state := RunState.create(run_def); state.run_seed = seed_value
		var rows := OpeningPreparation.plan(state, run_def, catalog)
		var cups := rows.filter(func(r: Dictionary) -> bool: return r.night <= 5 and r.item_id == GoodsExpertise.CUP and r.variant_id == "sound" and "sell" in r.transaction_modes)
		var fans := rows.filter(func(r: Dictionary) -> bool: return r.night <= 5 and r.item_id == GoodsExpertise.FAN and "sell" in r.transaction_modes)
		if fans.is_empty(): continue
		for a in cups:
			for b in cups:
				if a.visit_id >= b.visit_id or a.goods.pattern != b.goods.pattern or a.goods.side == b.goods.side or a.goods.workshop != b.goods.workshop: continue
				chosen = {"seed": seed_value, "cup_ids": ["item/" + a.visit_id, "item/" + b.visit_id], "fan_id": "item/" + fans[0].visit_id}
				wanted = [a.visit_id, b.visit_id, fans[0].visit_id]; break
			if not chosen.is_empty(): break
		if not chosen.is_empty(): break
	check(not chosen.is_empty(), "natural intact pair QA seed")
	if chosen.is_empty(): quit(1); return
	run_def._randomize_seed = false; run_def._seed = chosen.seed
	var s := RunSession.new(run_def, 21, SaveManager.new(QA + "ui_runtime.json"), catalog); s.new_run()
	for night in range(1, 6):
		driver.drain(s)
		if night >= 2: check(s.execute("prep_finish").ok, "prep")
		check(s.execute("open_shop").ok, "open"); driver.drain(s)
		for step in 130:
			driver.drain(s)
			if s._day.state.game_minutes >= 465: break
			var v := s._counter.customers.active(s._day.state)
			if v == null: s.execute("short_task"); continue
			if v.visit_id in wanted:
				for action in ["observe", "inspect", "crosscheck"]: check(s.counter_command("appraise", v.visit_id, action).ok, "appraise")
				check(s.counter_command("offer", v.visit_id, "", v.trade.asking_price).ok and v.status == "bought", "fixture purchase")
			else: s.counter_command("reject", v.visit_id)
		for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]: driver.drain(s); check(s.execute(action).ok, "fixture " + action)
	var data := SaveCodec.new().encode(s._day.state, 21); var codec := SaveCodec.new()
	check(codec.decode(JSON.parse_string(JSON.stringify(data)), run_def, 21, catalog, true) != null, "legitimate UI fixture " + codec.error_message)
	for pair in [["ui_fixture.json", data], ["ui_metadata.json", chosen]]:
		var file := FileAccess.open(QA + pair[0], FileAccess.WRITE); file.store_string(JSON.stringify(pair[1])); file.close()
	print("GOODS UI FIXTURE: %d passes, %d failures; seed %d" % [passes, failures, chosen.seed])
	quit(0 if failures == 0 else 1)
