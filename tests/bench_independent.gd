extends "res://tests/fan_condition.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	var model := FanAppraisalModels.facility(s._day)
	check(model.buttons.is_empty(), "unbuilt bench does not list later upgrades")
	invalid(s, "bench_two", "", "still needs level one")
	growth(s, "build", "bench")
	fixture(s, "upgrade-without-book")
	check(FanAppraisalModels.facility(s._day).buttons[0].enabled, "upgrade enabled without manual")
	var before := s.read_state()
	s._save.fail = true
	check(not s.growth_command("bench_two").ok, "upgrade save failure")
	check(s.read_state() == before, "upgrade complete rollback")
	s._save.fail = false
	var cash := s._day.state.cash
	growth(s, "bench_two")
	check(s._day.state.cash == cash - 80 and PreparationService.count(s._day.state) == 2, "upgrade cost and shared preparation")
	check(not FanAppraisalService.data(s._day.state).manual, "upgrade does not grant book")
	invalid(s, "bench_two", "", "duplicate upgrade")
	invalid(s, "fan_tools", "", "tools require finished bench")
	invalid(s, "fan_study", "", "study needs book")
	verify(s, "bookless construction")
	for i in 2:
		act(s, "open_shop"); driver.drain(s); finish_night(s); driver.drain(s)
	check(FanAppraisalService.bench_level(s._day.state) == 2, "finishes after two nights without book")
	fixture(s, "tools-without-book")
	cash = s._day.state.cash
	growth(s, "fan_tools")
	check(s._day.state.cash == cash - 30 and not FanAppraisalService.data(s._day.state).knowledge, "tools do not grant knowledge")
	invalid(s, "fan_study", "", "tools do not bypass book")
	verify(s, "bookless tools")
	act(s, "open_shop"); driver.drain(s); act(s, "close_shop"); driver.drain(s)
	growth(s, "explore", "0"); growth(s, "fan_manual")
	check(FanAppraisalService.data(s._day.state).manual and not FanAppraisalService.data(s._day.state).knowledge, "finding book does not study it")
	finish_night(s); driver.drain(s)
	cash = s._day.state.cash
	growth(s, "fan_study")
	check(s._day.state.cash == cash and PreparationService.count(s._day.state) == 1, "study is free and uses one preparation")
	check(FanAppraisalService.data(s._day.state).knowledge, "knowledge learned")
	invalid(s, "fan_study", "", "cannot study twice")
	verify(s, "study after independent construction")
	# Current saved fixtures still replay; lack of knowledge still gates comparison.
	var ready := load_case("fan-sound")
	var visit := CustomerManager.new().active(ready._day.state)
	check(FanConditionService.desk_reason(ready._day, visit.item.instance_id).is_empty(), "existing ready save still works")
	var a := FanAppraisalService.data(ready._day.state)
	a.knowledge = false; a.manual = false
	check(FanConditionService.desk_reason(ready._day, visit.item.instance_id).contains("顾砚生知识"), "missing specific knowledge explained")
	a.manual = true
	check(FanConditionService.desk_reason(ready._day, visit.item.instance_id).contains("第一柜学习"), "cabinet learning explained")
	print("BENCH INDEPENDENT: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
