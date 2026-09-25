extends "res://tests/wealthy_customers.gd"

func run() -> void:
	if not setup(): quit(1); return
	ad_boundaries()
	milestones()
	natural_play() # Includes save replay, atomic rollback and forged-outcome rejection.
	for manifest in ["res://data/wealthy_manifest.json", "res://data/porcelain_release_manifest.json", "res://data/camera_manifest.json"]:
		var loaded := JsonContentProvider.new(manifest).load_catalog()
		check(loaded.is_success(), "feedback catalog " + manifest)
		var definition := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
		var state := RunState.create(definition)
		state.ghost_catalog = loaded.catalog
		state.social_enabled = true
		state.social = SocialRules.initial()
		state.shop_growth["luxury"] = WealthyCustomers.initial()
		var records: Array = WealthyCustomers.data(state).advertisements
		var financial := {"reputation_trade_count": 12, "reputation_growth": 0}
		var before := state.to_read_model().duplicate(true)
		check(ReputationFeedback.summary(state, financial, 1).contains("今夜未托人宣传"), "no advertising is not zero outcome")
		check(state.to_read_model() == before, "summary is read only")
		records.append({"night": 1, "roll": 2, "delta": 0, "settled": false})
		check(ReputationFeedback.summary(state, financial, 1).contains("收铺后听回音"), "unsettled advert is pending")
		for delta in [-1, 0, 1, 3]:
			records[0].delta = delta; records[0].settled = true
			state.social.notices = [{"night": 1, "text": "街坊捎来口信。 商誉%+d。" % delta}]
			var snapshot := state.to_read_model().duplicate(true)
			var text := ReputationFeedback.summary(state, financial, 1)
			var notice := SocialReadModels.notice(state)
			for words in [text, notice]:
				check(not words.contains("商誉") and words.contains(ReputationFeedback.effect(delta)), "outcome described without score " + str(delta))
			check(text.contains("12 笔"), "transaction count remains visible")
			check(state.to_read_model() == snapshot, "old numeric notice and gameplay data preserved")
		check(ReputationFeedback.summary(state, financial, 2).contains("今夜未托人宣传"), "previous night feedback not reused")
	check(ReputationFeedback.notice("交货奖励50银元，压价10%。") == "交货奖励50银元，压价10%。", "money and actionable percentages preserved")
	var capped := ReputationFeedback.notice("又办成十笔收当生意，街坊认门的多了。累计100笔，商誉+0。")
	check(capped.contains("累计100笔") and capped.contains("暂无变化") and not capped.contains("认门的多了"), "capped milestone does not promise growth")
	check(ReputationFeedback.notice("客人识破贬价的说辞，出门时摇了摇头。商誉-2。").contains("口碑受了损"), "watch penalty retains consequence")
	print("REPUTATION FEEDBACK: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
