extends "res://tests/run_first_debt.gd"

class FailingStore extends GhostReplayStore:
	var fail := false
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		return not fail

func fresh_special(seed_value := 42) -> RunSession:
	var store := FailingStore.new()
	store.origin = {"seed": seed_value, "run_token": "0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def, 44, store, catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, 44)
	var restored := codec.decode(payload, run_def, 44, catalog, true)
	check(restored != null, "cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "exact replay " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/special_guests_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "special guests content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	var goods := {}
	var high := 0
	for seed_value in 10000:
		var id := SpecialGuests.pick_item(seed_value, "coverage")
		goods[id] = true
		if id in SpecialGuests.LUXURY: high += 1
	check(goods.size() == 23 and high > 1750 and high < 2250, "all 23 goods and 80/20 distribution")
	check(not goods.has("item_weeping_mirror") and not goods.has("fd_dragon"), "unique plot goods excluded")
	for seed_value in 32:
		var s := fresh_special(seed_value)
		check(s._day.state.shop_growth.has("special_guests"), "version gated progress")
		var before := s.read_state()
		var rows := OpeningPreparation.plan(s._day.state, run_def, catalog)
		check(before == s.read_state(), "read plan stable")
		for key in SpecialGuests.data(s._day.state).targets:
			var n := int(SpecialGuests.data(s._day.state).targets[key])
			check(n >= 2 and n <= 18 and n not in [4,8,15], "target valid " + key)
		check(rows.size() >= 108, "mainline visitors retained")
		if seed_value == 0: verify(s, "fresh")
	if "quick" not in OS.get_cmdline_user_args():
		journey_special(42, false)
		journey_special(18, true)
	print("SPECIAL GUESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func journey_special(seed_value: int, refuse_closed: bool) -> void:
	run_def._initial_cash = 6000
	var s := fresh_special(seed_value)
	var closed_nights: Array = []
	var wet_seen := 0
	var hats := 0
	for n in range(1,19):
		driver.drain(s); act(s,"open_shop"); driver.drain(s)
		for step in 160:
			var v := s._counter.customers.active(s._day.state)
			if v != null:
				var row := VarietySaveCodec.selection(s._day.state, v.visit_id)
				if row.has("special_key"):
					check(v.person.name == SpecialGuests.NAME, "anonymous visitor")
					var model := s.counter_model()
					check(model.visual.customer_name == SpecialGuests.NAME, "anonymous read model")
					if v.customer_id == GhostGuests.CLOSED:
						closed_nights.append(n)
						check(s.counter_command("reject" if refuse_closed else "offer",v.visit_id,"",v.trade.asking_price).ok,"closed transaction")
					else:
						if v.night_policy == "wet_cloth": wet_seen += 1
						else:
							hats += 1
							check(v.trade.rounds_left == 1, "one quote only")
							for cmd in ["pressure","belittle","concession","luxury_pressure","watch_claim","camera_claim","fan_pressure","condition_pressure","intimidate"]:
								check(not s._counter.reason(s._day,cmd,v.visit_id).is_empty(),"cannot bypass quote " + cmd)
						var old := s.read_state()
						(s._save as FailingStore).fail = true
						check(not s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"failed save rejects purchase")
						check(old == s.read_state(),"failed purchase rollback")
						(s._save as FailingStore).fail = false
						v = s._counter.customers.active(s._day.state)
						check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"special purchase")
						check(s._day.state.personal_damage == 0 and s._day.state.night_market_history.is_empty(),"no wet curse")
					verify(s,"special transaction n%d" % n)
				else: s.counter_command("reject",v.visit_id)
				driver.drain(s)
			else:
				if not s.bell_model().enabled: break
				s.bell_command("wait"); driver.drain(s)
		if s._day.state.phase == &"open": act(s,"close_shop")
		if s._day.state.phase == &"closed_processing": act(s,"wait_until_seal")
		act(s,"resolve_night"); driver.drain(s)
		act(s,"enter_room"); driver.drain(s)
		check(s._day.state.personal_damage == 0,"sleep has no wet damage")
		act(s,"sleep"); driver.drain(s); act(s,"finish_sleep"); driver.drain(s)
		if n in [4,8,15,18]: verify(s,"night%d" % n)
		if n < 18: act(s,"continue_run")
	check(closed_nights == ([4] if refuse_closed else [4,8,15]),"closed appointments " + str(closed_nights))
	check((SpecialGuests.QUEST_FLAG in s._day.state.narrative_flags) == not refuse_closed,"future quest eligibility")
	check(wet_seen == 1 and hats == 3,"one wet and three hat visits: %d/%d" % [wet_seen,hats])
