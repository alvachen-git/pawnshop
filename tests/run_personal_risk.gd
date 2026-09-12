extends "res://tests/run_mirror_chapter.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/life_lamp_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "v22 content loads")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "life_lamp_seven")
	run_def._randomize_seed = false
	run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	if "process-read" in OS.get_cmdline_user_args():
		var files := DirAccess.get_files_at("res://.artifacts/lamp-transfer")
		check(files.size() >= 18, "all cross-process stage snapshots exist")
		for filename in files:
			var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.artifacts/lamp-transfer/" + filename))
			var codec := SaveCodec.new()
			check(codec.decode(payload, run_def, 22, catalog) != null, "new process restores " + filename + ": " + codec.error_message)
		print("LAMP CROSS PROCESS: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1); return
	units()
	story_effects()
	compatibility()
	if failures > 0: quit(1); return
	for route in ["stop", "pursue", "severe", "shop", "storage", "both", "sold"]:
		production_route(route)
		if failures > 0: break
	if failures == 0: wet_cloth_route()
	print("PERSONAL RISK: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func units() -> void:
	var state := RunState.create(run_def)
	state.phase = &"open"; state.game_minutes = 25
	for i in range(1, 5):
		check(PersonalRisk.damage(state, "unit/%d" % i) == 1 and state.personal_damage == i, "independent ordinary harm %d" % i)
		check((state.phase == &"dead") == (i == 4), "death only at exhaustion")
	check(state.personal_death_phase == "open" and state.summaries.is_empty() and state.closed_at == -1 and state.fee_history.is_empty(), "business death never closes or charges fees")
	check(PersonalRisk.recover(state, "after_death", 4) == 0 and state.personal_damage == 4, "no resurrection")
	state = RunState.create(run_def)
	check(PersonalRisk.damage(state, "mirror/one") == 1, "pursuit onset")
	check(PersonalRisk.damage(state, "mirror/one", 2) == 1 and state.personal_damage == 2, "severe upgrade adds only difference")
	check(PersonalRisk.damage(state, "mirror/one", 2) == 0, "duplicate severe ignored")
	check(PersonalRisk.recover(state, "treatment/one") == 1 and state.personal_damage == 1, "explicit treatment")
	check(PersonalRisk.damage(state, "mirror/one", 2) == 0, "recovery retains injury dedup")
	check(PersonalRisk.recover(state, "treatment/two", 4) == 1 and state.personal_damage == 0, "recovery clamps to normal")
	check(PersonalRisk.damage(state, "another", 2) == 2 and state.phase != &"dead", "fresh severe survives from normal")
	check(PersonalRisk.damage(state, "third", 2) == 2 and state.phase == &"dead", "two severe wounds exhaust lamp")
	var old := JsonContentProvider.new("res://data/night_market_manifest.json").load_catalog().catalog
	var old_state := RunState.create(old.get_definition("runs", "night_market"))
	check(PersonalRisk.damage(old_state, "legacy") == 0 and not old_state.to_read_model().has("personal_damage"), "legacy runs retain old rules")
	for d in 5:
		state.personal_damage = d
		check(not PersonalRisk.lamp_state(state).double_flame, "no implicit double flame")

func story_effects() -> void:
	var original_events := run_def._event_ids.duplicate()
	var source := {"id": "test_personal", "title": "测试剧情", "speaker": "", "body": "测试", "kind": "anchor", "phase": "open", "night_min": 1, "night_max": 7, "window_start": 0, "window_end": 541, "priority": 99, "weight": 1, "max_count": 20, "cooldown": 0, "required_flags": [], "excluded_flags": [], "required_items": [], "conflicts_with": [], "presentation": {"scene": "test", "hotspots": true}, "choices": [
		{"id": "hurt", "label": "触碰", "result": "一阵冷意刺入胸口。", "minutes": 5, "grant_flags": [], "personal_damage": true},
		{"id": "severe", "label": "靠近", "result": "冰冷的手攥住了喉咙。", "minutes": 5, "grant_flags": [], "personal_damage": 2},
		{"id": "heal", "label": "服药", "result": "胸口的凉意退了一些。", "minutes": 5, "grant_flags": [], "personal_recovery": true},
		{"id": "full", "label": "调息", "result": "胸口渐渐暖了。", "minutes": 5, "grant_flags": [], "personal_recovery": 4}]}
	source.speaker = "旁白"
	check(EventSchema.validate(source, "test", "$").is_empty(), "story effect schema accepts defaults and severity")
	var invalid := source.duplicate(true)
	invalid.choices[0].personal_damage = 3
	check(not EventSchema.validate(invalid, "test", "$").is_empty(), "ordinary damage cannot silently configure fatal severity")
	catalog.add_definition("events", EventDefinition.from_dto(EventDTO.from_source(source)))
	run_def._event_ids = ["test_personal"]
	var s := fresh("test_effect")
	check(s.execute("open_shop").ok, "test event opens")
	var four := fresh("four_ordinary")
	four.execute("open_shop")
	for damage in range(1, 5):
		check(four.event_command("test_personal", "hurt").ok and four._day.state.personal_damage == damage, "four independent story injuries " + str(damage))
	for action in ["hurt", "hurt", "heal", "full", "hurt", "severe"]:
		check(s.event_command("test_personal", action).ok, "story effect " + action + ": " + s.message)
	check(s._day.state.personal_damage == 3 and s._day.state.phase == &"open", "healed then hurt again")
	check(s.event_model().text.contains("影子薄得几乎看不见"), "lethal next choice has contextual warning in narrative view")
	var before := s.read_state()
	check(s.load_checkpoint().ok and before == s.read_state(), "mid-trade injury save resumes exact scene")
	var library := SaveLibrary.new("res://.godot/lamp-fault-%d.json" % Time.get_ticks_usec())
	library.fail_write = true; s._save.library = library
	check(not s.event_command("test_personal", "hurt").ok and before == s.read_state(), "failed business death rolls back injury event time archive and journal")
	s._save.library = null
	check(s.event_command("test_personal", "hurt").ok and s._day.state.phase == &"dead", "business exhaustion commits immediately")
	check(s._day.state.game_minutes == 35 and s._day.state.closed_at == -1 and s._day.state.summaries.is_empty() and s._day.state.cash == run_def.initial_cash, "no invented closing or interest")
	var codec := SaveCodec.new()
	var payload := codec.encode(s._day.state, 22)
	check(codec.decode(JSON.parse_string(JSON.stringify(payload)), run_def, 22, catalog) != null, "terminal business JSON roundtrip " + codec.error_message)
	for key in ["personal_damage", "personal_death_phase", "personal_risk_history", "cash", "game_minutes"]:
		var bad := payload.duplicate(true)
		if key == "personal_risk_history": bad[key].clear()
		elif key == "personal_death_phase": bad[key] = "sleep_resolution"
		else: bad[key] += 1
		check(codec.decode(bad, run_def, 22, catalog) == null, "reject tampered " + key)
	check(not s.event_command("test_personal", "heal").ok and s._day.state.phase == &"dead", "dead story cannot heal")
	run_def._event_ids = original_events

func compatibility() -> void:
	var library := SaveLibrary.new("res://.godot/lamp-compat-%d.json" % Time.get_ticks_usec())
	var s := fresh("compat")
	check(library.write_entry("auto/life_lamp_seven", s._day.state, run_def, 22, catalog), "new independent autosave " + library.error_message)
	var loaded := JsonContentProvider.new("res://data/night_market_manifest.json").load_catalog()
	var old_run: RunDefinition = loaded.catalog.get_definition("runs", "night_market")
	var old := RunSession.new(old_run, 21, PersonalSaveCodec.ReplayStore.new(), loaded.catalog)
	check(library.write_entry("manual/1", old._day.state, old_run, 21, loaded.catalog), "shared manual slot accepts old run")
	var decoded := library.read_entry("manual/1")
	check(not decoded.is_empty() and library.adopt(decoded, s), "adopt legacy save")
	check(not s._day.state.personal_risk_enabled and s.content_version == 21, "legacy rules unchanged after switch")
	s.new_run()
	check(s._day.state.personal_risk_enabled and s.content_version == 22 and s._day.state.personal_damage == 0, "new game returns to v22 without retroactive injury")
	decoded = library.read_entry("auto/life_lamp_seven")
	check(not decoded.is_empty() and library.adopt(decoded, s), "new autosave remains available")
	check(library.write_entry("manual/2", s._day.state, run_def, 22, catalog), "resumed v22 writes shared manual slot")

func wet_cloth_route() -> void:
	var s := fresh("wet_cloth")
	var attacks := 0
	var treatments := 0
	for n in range(1, 8):
		driver.open(s)
		for guard in 150:
			driver.drain(s)
			if s._day.state.phase != &"open" or s._day.state.game_minutes >= 530: break
			var visit := s._counter.customers.active(s._day.state)
			if visit != null:
				if visit.night_policy == "wet_cloth":
					var before := s._day.state.personal_damage
					check(s.counter_command("question", visit.visit_id, "origin").ok, "wet cloth actual taboo")
					attacks += 1
					check(s._day.state.personal_damage == before + 1, "wet cloth actual harm counts once")
					if visit.status == "active":
						s.counter_command("offer", visit.visit_id, "", visit.trade.asking_price)
						if visit.status == "active": s.counter_command("reject", visit.visit_id)
					check(s._day.state.personal_damage == before + 1, "same wet cloth purchase does not repeat harm")
				else: s.counter_command("reject", visit.visit_id)
			else:
				var treated := false
				for id in NightMarketRisk.unresolved(s._day.state):
					if n >= 4 and NightMarketRisk.treatment_reason(s._day, id).is_empty():
						var before := s._day.state.personal_damage
						check(s.execute("seal_cloth/" + id).ok and s._day.state.personal_damage == before, "sealing cloth does not heal")
						treatments += 1; treated = true; break
				if not treated: s.execute("short_task")
		if s._day.state.phase == &"open": driver.action(s, "close_shop")
		if s._day.state.phase == &"closed_processing": driver.action(s, "wait_until_seal")
		for command in ["resolve_night", "enter_room", "sleep", "finish_sleep"]:
			driver.action(s, command); driver.drain(s)
		check(s._day.state.personal_damage == attacks and s._day.state.phase != &"dead", "ordinary sleep neither heals nor adds legacy nightly harm")
		driver.action(s, "continue_run")
	check(attacks == 2 and treatments > 0, "production wet-cloth sources and treatment exercised")
	print("LAMP WET CLOTH: ", attacks, " injuries; ", treatments, " sealed; ", s._day.state.phase)
	transfer(s, "wet_cloth_end")

func transfer(s: RunSession, label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://.artifacts/lamp-transfer")
	var file := FileAccess.open("res://.artifacts/lamp-transfer/" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 22)))

func mirror_edges(s: RunSession) -> void:
	var pursuit: Dictionary = s._day.state.mirror_history.filter(func(row: Dictionary) -> bool: return row.action == "pursue").back()
	var peek: Dictionary = s._day.state.mirror_history.filter(func(row: Dictionary) -> bool: return row.visit_id == pursuit.visit_id and row.action == "peek").back()
	for action in ["stop", "pursue"]:
		var state := RunSnapshot.copy(s._day.state)
		state.mirror_history.assign(state.mirror_history.filter(func(row: Dictionary) -> bool: return row != pursuit))
		state.personal_damage = 0; state.personal_risk_history.clear()
		state.game_minutes = int(peek.minute); state.phase = &"open"
		var visitor: CustomerVisit = state.visits.filter(func(v: CustomerVisit) -> bool: return v.visit_id == pursuit.visit_id)[0]
		visitor.status = "active"
		visitor.expires_at = state.game_minutes + 5
		state.visits.assign([visitor])
		var result := s._mirror.choose(DayController.new(run_def, state), pursuit.encounter_id, action)
		check(state.personal_damage == 0 and state.personal_risk_history.is_empty(), "stop or expired pursuit never harms: " + action)
		check(result.ok if action == "stop" else not result.ok and state.mirror_history.back().action == "pursue_expired", "actual pursuit expiry branch")

func production_route(route: String) -> void:
	var s := fresh("personal_" + route)
	for n in range(1, 4):
		driver.open(s)
		if n < 3:
			driver.work(s, "stop")
			driver.finish(s, "covered")
			continue
		chapter_work(s, "pursue" if route in ["pursue", "severe", "both", "sold"] else "ability" if route == "stop" else "calm")
		var mirror := s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.definition_id == "item_weeping_mirror")
		check(not mirror.is_empty(), "mirror held in production")
		if mirror.is_empty(): return
		var item: ItemInstance = mirror[0]
		var pursuit := route in ["pursue", "severe", "both", "sold"]
		check(s._day.state.personal_damage == (1 if pursuit else 0), "actual pursuit alone harms: " + route)
		transfer(s, route + "_business")
		if route == "pursue": mirror_edges(s)
		if route not in ["both", "shop", "storage"]: s.risk_command("cover", item.instance_id)
		for command in ["close_shop", "wait_until_seal", "resolve_night"]: driver.action(s, command)
		if not s._day.state.risk_pending.is_empty():
			check(s.risk_command("defy" if route in ["both", "shop"] else "retreat", item.instance_id).ok, "shop response")
			check(s._day.state.personal_damage == (3 if route == "both" else 2 if route == "shop" else 0) and s._day.state.phase != &"dead", "shop attack stacks; correct avoidance never harms")
		driver.action(s, "enter_room"); driver.drain(s)
		driver.action(s, "sleep"); driver.drain(s)
		if pursuit:
			var before := s.read_state()
			var library := SaveLibrary.new("res://.godot/lamp-room-fault-%d.json" % Time.get_ticks_usec())
			library.fail_write = true; s._save.library = library
			check(not s.risk_command("defy", item.instance_id).ok and before == s.read_state(), "failed sleep response rolls back entirely")
			s._save.library = null
			check(s.risk_command("defy" if route in ["severe", "both"] else "retreat", item.instance_id).ok, "personal response " + route)
			var expected := 4 if route == "both" else 2 if route == "severe" else 1
			check(s._day.state.personal_damage == expected, "same event total after response")
			var damage := s._day.state.personal_damage
			check(not s.risk_command("defy", item.instance_id).ok and s._day.state.personal_damage == damage, "repeat response cannot charge")
			check(s.load_checkpoint().ok and s._day.state.personal_damage == damage, "reload does not charge again")
			transfer(s, route + "_response")
		if s._day.state.phase != &"dead":
			var damage := s._day.state.personal_damage
			driver.action(s, "finish_sleep"); driver.action(s, "continue_run")
			check(s._day.state.personal_damage == damage and s._day.state.current_night_index == 4, "sleep keeps injury and continues next day")
			transfer(s, route + "_next_day")
			if route == "sold":
				driver.open(s)
				var sold := false
				for guard in 100:
					driver.drain(s)
					if s._commerce.trip_reason(s._day, catalog.get_definition("buyers", "buyer_mirror")).is_empty():
						sold = s.sell_batch("buyer_mirror", [item.instance_id]).ok
						break
					var visitor := s._counter.customers.active(s._day.state)
					if visitor != null: s.counter_command("reject", visitor.visit_id)
					else: s.execute("short_task")
					if s._day.state.game_minutes >= 460: break
				check(sold and s._day.state.personal_damage == 1, "sale in buyer window does not heal")
		else:
			check(s._day.state.personal_death_phase == "sleep_resolution", "sleep source recorded")
			var library := SaveLibrary.new("res://.godot/lamp-ending-%d.json" % Time.get_ticks_usec())
			check(library.write_entry("auto/life_lamp_seven", s._day.state, run_def, 22, catalog), "death and archive publish in shared library")
			var ending := library.read_entry("auto/life_lamp_seven")
			check(not ending.is_empty() and ending.state.phase == &"dead", "shared library restores ending")
	print("LAMP ROUTE ", route, " damage=", s._day.state.personal_damage, " phase=", s._day.state.phase)
