extends "res://tests/run_mirror_call.gd"

func test_manifest() -> String:
	return "res://data/unified_manifest.json"

func fixture_root() -> String:
	return "res://.godot/qa/unified-campaign/"

func act(s: RunSession, command: String) -> void:
	if command == "open_shop" and s._day.state.current_night_index == 2:
		check(s._day.state.social.introduced, "same new game reaches military introduction")
		check(s.growth_command("learn_knowledge", "gu_yansheng").ok, "same new game learns fan knowledge")
		check(s.social_command("accept_contract").ok, "same new game accepts coat procurement")
		verify(s, "combined knowledge and procurement")
	super.act(s, command)

func entry_checks() -> void:
	check(SocialRules.enabled(run_def) and ShopGrowthService.enabled(run_def), "unified social and facilities")
	check(FanConditionService.enabled(run_def) and FanBargainingService.enabled(run_def), "unified fan condition and bargaining")
	check(AqiCompanion.enabled(run_def) and MirrorDreamService.call_enabled(run_def), "unified companion and dreams")
	super.entry_checks()
