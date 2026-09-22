extends "res://tests/run_integrated_seven.gd"

func run() -> void:
	catalog = JsonContentProvider.new("res://data/life_lamp_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check
	driver.catalog = catalog
	var reading := "read" in OS.get_cmdline_user_args()
	for legacy in [false, true]:
		for accepted in [true, false]:
			for command in ["offer", "pawn"]:
				var path := "user://tests/quote_v22_%s_%s_%s.json" % [legacy, accepted, command]
				var save := SaveManager.new(path)
				save.catalog = catalog
				if reading:
					var restored := save.load_state(run_def, 22)
					check(restored != null, "v22 cross-process restore: " + path + " " + save.error_message)
					if restored != null:
						var rows := restored.scenario_history + restored.bargaining_history
						var last: Dictionary = rows.filter(func(row: Dictionary) -> bool: return row.command == command).back()
						check(last.ok == not legacy, "historical quote ordering retained")
						check(restored.inventory_instances.size() == (1 if accepted and not legacy else 0), "restored acquisition matches decision")
					continue
				var s := session()
				if command == "pawn":
					for night in 2:
						driver.open(s)
						for action in ["close_shop", "wait_until_seal", "resolve_night", "enter_room", "sleep", "finish_sleep", "continue_run"]:
							driver.action(s, action)
							driver.drain(s)
				driver.open(s)
				var v := s._counter.customers.active(s._day.state)
				if command == "pawn":
					check(s.counter_command("reject", v.visit_id).ok, "pass tutorial sale")
					driver.drain(s)
					for step in 100:
						v = s._counter.customers.active(s._day.state)
						if v != null:
							var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
							var modes: Array = customer.transaction_modes if v.transaction_modes.is_empty() else v.transaction_modes
							if "pawn" in modes and "pawn" in customer.transaction_modes: break
							check(s.counter_command("reject", v.visit_id).ok, "pass sell-only customer")
						driver.action(s, "short_task")
						driver.drain(s)
				if v == null:
					check(false, "must find an eligible customer before deadline test")
					quit(1); return
				while s._day.state.game_minutes < v.expires_at - 5:
					driver.action(s, "short_task")
					driver.drain(s)
				s._counter.quote_before_timeout = not legacy
				var amount := v.trade.reserve_price
				if command == "pawn":
					var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
					var terms := catalog.get_definition("pawn_terms", VarietyService.terms_for(v, customer)) as PawnTermsDefinition
					amount = maxi(1, roundi(amount * terms.loan_ratio))
				var quoted := s.counter_command(command, v.visit_id, "", amount if accepted else 1)
				check(quoted.ok == not legacy, "v22 deadline quote %s legacy=%s accepted=%s: %s" % [command, legacy, accepted, quoted.message])
				driver.drain(s)
				driver.action(s, "close_shop")
				driver.action(s, "wait_until_seal")
				driver.action(s, "resolve_night")
				check(save.save_state(s._day.state, run_def, 22), "write actual replayable checkpoint: " + save.error_message)
				var raw := SaveCodec.new().encode(s._day.state, 22)
				check(SaveCodec.new().decode(raw, run_def, 22, catalog) != null, "new or old quote replay accepted")
				raw.cash += 1
				check(SaveCodec.new().decode(raw, run_def, 22, catalog) == null, "forged money rejected")
	print("QUOTE DEADLINE PROCESS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func session() -> RunSession:
	run_def._randomize_seed = false
	run_def._seed = 42
	return RunSession.new(run_def, 22, PersonalSaveCodec.ReplayStore.new(), catalog)