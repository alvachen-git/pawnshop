extends "res://tests/fan_condition.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	fixture(s, "knowledge-before")
	check(not ShopKnowledgeService.mastered(s._day.state, "gu_yansheng"), "not learned initially")
	check(s._day.state.shop_growth.exploration.is_empty(), "no exploration required")
	invalid(s, "learn_knowledge", "porcelain", "unregistered topic cannot be learned")
	var before := s.read_state()
	s._save.fail = true
	check(not s.growth_command("learn_knowledge", "gu_yansheng").ok, "learning save failure")
	check(s.read_state() == before, "failed learning restores knowledge preparation journal and cash")
	s._save.fail = false
	var cash := s._day.state.cash
	var minute := s._day.state.game_minutes
	growth(s, "learn_knowledge", "gu_yansheng")
	check(s._day.state.cash == cash and s._day.state.game_minutes == minute, "learning is free and preparation only")
	check(PreparationService.count(s._day.state) == 1 and ShopKnowledgeService.mastered(s._day.state, "gu_yansheng"), "learned one topic for one preparation")
	check(not FanAppraisalService.data(s._day.state).knowledge and not FanAppraisalService.data(s._day.state).manual, "new knowledge independent of legacy fan flags")
	check(not ShopKnowledgeService.mastered(s._day.state, "porcelain"), "learning does not unlock unrelated fields")
	invalid(s, "learn_knowledge", "gu_yansheng", "duplicate learning is no-op")
	fixture(s, "knowledge-learned")
	var codec := SaveCodec.new()
	var tampered := codec.encode(s._day.state,29)
	tampered.shop_growth.knowledge.gu_yansheng.night = 1
	check(codec.decode(tampered,run_def,29,catalog,true) == null, "tampered preparation record rejected")
	tampered = codec.encode(s._day.state,29)
	tampered.shop_growth.knowledge["porcelain"] = {"night":2}
	check(codec.decode(tampered,run_def,29,catalog,true) == null, "invented knowledge rejected")
	growth(s, "build", "bench")
	check(PreparationService.count(s._day.state) == 2, "learning shares daily budget with construction")
	invalid(s, "bench_two", "", "third preparation unavailable")
	act(s, "open_shop"); driver.drain(s); finish_night(s); driver.drain(s)
	check(PreparationService.count(s._day.state) == 0 and ShopKnowledgeService.mastered(s._day.state, "gu_yansheng"), "knowledge retained across nights without consuming later preparations")
	growth(s, "bench_two")
	for i in 2:
		act(s, "open_shop"); driver.drain(s); finish_night(s); driver.drain(s)
	growth(s, "fan_tools")
	fixture(s, "knowledge-equipped")
	var visit := reach_fan(s)
	check(visit != null, "fan customer reached with new knowledge")
	if visit != null:
		check(FanConditionService.desk_reason(s._day,visit.item.instance_id).is_empty(), "new knowledge enables desk without tool manual")
		claim(s)
		check(visit.item.goods.has("fan_claim"), "full self appraisal uses topic knowledge")
		fixture(s, "knowledge-appraised")
	# Real v29 saved legacy study remains recognized, without migration or second charge.
	var old := load_case("fan-sound")
	before = old.read_state()
	check(ShopKnowledgeService.mastered(old._day.state,"gu_yansheng"), "legacy study maps only to Gu Yansheng")
	check(not ShopKnowledgeService.mastered(old._day.state,"porcelain"), "legacy study is not universal knowledge")
	check(old.read_state() == before, "compatibility reads do not mutate saves")
	invalid(old,"learn_knowledge","gu_yansheng","legacy knowledge cannot be charged again")
	verify(old,"legacy knowledge restored unchanged")
	# Ineligible phases, pending business and exhausted preparations preserve all state.
	for mode in ["quota","finished","open","pending"]:
		var limited := load_case("knowledge-before")
		match mode:
			"quota": growth(limited,"build","bench"); growth(limited,"build","display")
			"finished": limited._day.state.preparation_history.append({"night":2,"action":"finish"})
			"open": act(limited,"open_shop"); driver.drain(limited)
			"pending": limited._day.state.pending_event_id = "test_pending"
		invalid(limited,"learn_knowledge","gu_yansheng",mode + " blocks study")
	print("SHOP KNOWLEDGE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
