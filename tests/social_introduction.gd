extends "res://tests/social_v27.gd"

func run() -> void:
	if not setup(): quit(1); return
	driver.pause_military_intro = true
	var s := second_night()
	var state := s._day.state
	check(MilitaryIntroduction.active(state) and state.social.intro_step == 0, "second day itemless reception")
	check(not state.social.introduced and FactionBookModels.roster(state).is_empty(), "unmet faction remains hidden")
	var start := s.read_state()
	var initial_visits := state.visits.map(func(row: CustomerVisit) -> String: return row.visit_id)
	var v := MilitaryIntroduction.id(state)
	var model := s.counter_model()
	check(model.active_id == v and model.itemless and model.context_actions.item.is_empty(), "counter has person but no merchandise")
	check(model.context_actions.customer.size() == 1 and not model.trade.can_offer and not model.trade.can_pawn, "conversation only")
	check(not SocialReadModels.notice(state).contains("孙大元登门"), "no introduction in business page")
	for command in ["open_shop", "close_shop", "wait_until_seal", "prep_attract"]:
		check(not s.execute(command).ok and start == s.read_state(), "cannot bypass conversation via " + command)
	for command in ["offer", "pawn", "reject", "appraise", "intimidate"]:
		check(not s.counter_command(command,v).ok and start == s.read_state(), "no trading command " + command)
	check(not s.social_command("accept_contract").ok, "no task before meeting")
	check(not s.counter_command("military_intro","wrong","0").ok, "wrong reception rejected")
	check(not s.counter_command("military_intro",v,"0",1).ok, "no money in conversation")
	verify(s, "before introduction")
	for step in 3:
		check(s.counter_command("military_intro",v,str(step)).ok, "conversation step " + str(step))
		var after := s.read_state()
		check(not s.counter_command("military_intro",v,str(step)).ok and after == s.read_state(), "duplicate choice cannot skip forward")
		verify(s, "introduction step " + str(step))
		var store := s._save
		var data := SaveCodec.new().encode(state,27)
		InvestigationSaveCodec.clear_cache()
		s._day.state = SaveCodec.new().decode(data,s.definition,27,catalog,true)
		state = s._day.state
		check(state != null and state.social.intro_step == step+1, "cold reload exact speech progress")
		if step < 2: check(FactionBookModels.roster(state).is_empty(), "mid-dialogue book still empty")
		check(store == s._save, "reload leaves store intact")
	check(state.social.introduced and FactionBookModels.roster(state).size() == 1, "book unlocked after farewell")
	check(state.cash == start.cash and state.game_minutes == start.game_minutes and state.social.military == start.social.military and state.social.reputation == start.social.reputation, "greeting has no economic or score effects")
	check(state.visits.map(func(row: CustomerVisit) -> String: return row.visit_id) == initial_visits and s.read_state().ordinary_selections == start.ordinary_selections, "ordinary queue unchanged")
	check(state.social.notices.filter(func(row: Dictionary) -> bool:return row.text == MilitaryService.INTRODUCTION).size() == 1, "one meeting history record")
	check(not SocialReadModels.notice(state).contains("孙大元登门"), "business page stays clear after meeting")
	check(s.can_execute("open_shop") and s.social_command("accept_contract").ok, "normal business and tasks available after meeting")
	verify(s, "order after meeting")
	# Publication failure must not consume a dialogue step or reveal the faction.
	s = second_night(); var before := s.read_state()
	(s._save as CountingStore).fail = true
	check(not s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),"0").ok and before == s.read_state(), "failed save rolls back dialogue")
	(s._save as CountingStore).fail = false
	check(s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),"0").ok, "retry applies once")
	# Frozen older v27 games keep their already completed introduction and rules.
	for stage in ["delivery","claim","closure"]:
		var path: String = "res://tests/fixtures/v27_before_faction_history/" + stage + ".json"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var run := catalog.get_definition("runs",data.run_definition_id) as RunDefinition
		var old := SaveCodec.new().decode(data,run,27,catalog,true)
		check(old != null and old.social.introduced and not MilitaryIntroduction.active(old), "old save doesn't replay meeting " + stage)
		var forged := data.duplicate(true); forged.cash += 50
		check(SaveCodec.new().decode(forged,run,27,catalog,true) == null, "legacy cash integrity " + stage)
	print("MILITARY INTRODUCTION: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
