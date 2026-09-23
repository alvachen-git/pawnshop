extends "res://tests/social_v27.gd"

const OLD := "res://tests/fixtures/v27_before_faction_history/"

func run() -> void:
	if not setup(): quit(1); return
	introduction_and_discovery()
	old_saves()
	reward_and_history()
	faction_isolation()
	print("V27 BOOK HISTORY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func introduction_and_discovery() -> void:
	var s := fresh_growth()
	driver.drain(s)
	var before := s.read_state()
	check(s._day.state.current_night_index == 1 and not s._day.state.social.introduced, "first night has no faction encounter")
	check(FactionBookModels.roster(s._day.state).is_empty(), "book starts with no factions")
	for section in 3:
		var page := FactionBookModels.page(s._day, "military", section)
		check(page.buttons.is_empty() and page.fields.is_empty() and not page.body.contains("孙大元"), "no pre-encounter identity or tasks")
	check(not s.social_command("accept_contract").ok and s.read_state() == before, "cannot accept task before encounter")
	s = second_night()
	var state := s._day.state
	check(state.current_night_index == 2 and state.phase == &"pre_open" and state.social.introduced, "visit on second day before opening")
	check(FactionBookModels.roster(state).size() == 1, "one faction discovered after visit")
	check(state.social.military == 0 and state.social.contract.is_empty(), "introduction adds no score or automatic task")
	check(state.social.notices.filter(func(row: Dictionary) -> bool: return row.text == MilitaryService.INTRODUCTION).size() == 1, "personal visit recorded once")
	check(not SocialReadModels.notice(state).contains("孙大元登门"), "business notice excludes introduction dialogue")
	check(SocialReadModels.faction_history(state, "military").contains("记在《往来簿》里"), "task direction preserved in history")
	before = s.read_state()
	MilitaryService.dawn(state, s.definition)
	check(before == s.read_state(), "repeat refresh cannot repeat introduction")
	verify(s, "new personal visit")
	var codec := SaveCodec.new()
	var old_scoped := codec.encode(state, 27)
	for row in old_scoped.social.notices:
		if row.text == MilitaryService.INTRODUCTION:
			row.text = "军阀经办孙大元递来名帖：‘营里偶尔要收几件日用旧物。掌柜愿意做，按单交货；不愿意，也先认个门。’名帖已夹进柜台上的《往来簿》。"
	var source := JSON.stringify(old_scoped)
	InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(old_scoped, s.definition, 27, catalog, true)
	check(restored != null and GhostSaveCodec.same(restored.to_read_model(), s.read_state()), "prior scoped v27 saves retain progress with new copy")
	check(source == JSON.stringify(old_scoped), "old scoped source remains unchanged")
	var prior_visit := codec.encode(state, 27)
	for row in prior_visit.social.notices:
		if row.text == MilitaryService.INTRODUCTION: row.text = MilitaryService.LEGACY_INTRODUCTION
	var prior_source := JSON.stringify(prior_visit)
	InvestigationSaveCodec.clear_cache()
	var prior_restored := codec.decode(prior_visit,s.definition,27,catalog,true)
	check(prior_restored != null and GhostSaveCodec.same(prior_restored.to_read_model(),s.read_state()), "previous counter visit copy reloads with same progress")
	check(JSON.stringify(prior_visit) == prior_source, "previous counter visit source not rewritten")
	prior_visit.cash += 1
	check(codec.decode(prior_visit,s.definition,27,catalog,true) == null, "visit copy alias cannot bypass money validation")

func old_saves() -> void:
	for stage in ["delivery", "claim", "closure"]:
		var path: String = OLD + stage + ".json"
		var original := FileAccess.get_file_as_string(path)
		var data: Dictionary = JSON.parse_string(original)
		var unchanged := JSON.stringify(data)
		var definition := catalog.get_definition("runs", data.run_definition_id) as RunDefinition
		var codec := SaveCodec.new()
		InvestigationSaveCodec.clear_cache()
		var restored := codec.decode(data, definition, 27, catalog, true)
		check(restored != null, "pre-fix v27 cold replay " + stage + " " + codec.error_message)
		check(JSON.stringify(data) == unchanged and FileAccess.get_file_as_string(path) == original, "source save remains unchanged " + stage)
		if restored == null: continue
		check(data.social.notices.all(func(row: Dictionary) -> bool: return not row.has("faction_id")), "fixture is genuinely pre-fix " + stage)
		var history := SocialReadModels.faction_history(restored, "military")
		check(history.contains("孙大元"), "historical army introduction retained " + stage)
		for row in restored.social.notices:
			check(history.contains(row.text) == (row.faction_id == "military"), "replayed notice belongs to its faction " + stage)
		var encoded := codec.encode(restored, 27)
		var reread := codec.decode(encoded, definition, 27, catalog, true)
		check(reread != null and GhostSaveCodec.same(restored.to_read_model(), reread.to_read_model()), "resave and warm replay " + stage)
		var forged := data.duplicate(true)
		forged.cash += 50
		check(codec.decode(forged, definition, 27, catalog, true) == null, "legacy migration rejects forged cash")
		forged = data.duplicate(true)
		forged.social.notices[0].text += "伪造"
		check(codec.decode(forged, definition, 27, catalog, true) == null, "legacy migration rejects forged text")
		forged = encoded.duplicate(true)
		forged.social.notices[0].faction_id = "other_faction"
		check(codec.decode(forged, definition, 27, catalog, true) == null, "replay rejects changed faction")
		forged = encoded.duplicate(true)
		forged.social.notices[0]["extra"] = true
		check(codec.decode(forged, definition, 27, catalog, true) == null, "replay rejects extra notice fields")
		forged = data.duplicate(true)
		forged.social = "invalid"
		check(codec.decode(forged, definition, 27, catalog, true) == null, "malformed social state rejected safely")

func reward_and_history() -> void:
	var s := fixture_session("delivery")
	check(s._day.state != null, "delivery fixture loaded")
	if s._day.state == null: return
	var state := s._day.state
	var before := s.read_state()
	var page := FactionBookModels.page(s._day, "military", 0)
	check(page.fields.has(["奖励", "50银元 · 期限不限"]), "accepted task explicitly states reward")
	check(not JSON.stringify(page.fields).contains("货款") and not JSON.stringify(page.fields).contains("贷款"), "reward wording unambiguous")
	var history := FactionBookModels.page(s._day, "military", 2).body as String
	check(history.contains("完成奖励50银元") and not history.contains("临走留下话"), "old order wording updated and customer feedback excluded")
	check(before == s.read_state(), "book browsing read only")
	check(state.social.notices.any(func(row: Dictionary) -> bool: return row.text.contains("临走留下话")), "ordinary feedback retained outside faction history")
	var ids := CoatProcurement.stock(state).map(func(item: ItemInstance) -> String: return item.instance_id)
	var detail := detail_for(s, ids.slice(0,3))
	check(s.social_command("deliver", detail).ok, "real journaled coat delivery")
	check(state.cash == before.cash + 50, "reward pays exactly fifty silver")
	check(state.fee_arrears == before.fee_arrears and state.fee_history == before.fee_history, "reward creates no debt or fees")
	check(s.read_state().pawn_tickets == before.pawn_tickets, "reward creates no pawn loan")
	check(state.social.military == before.social.military + 6, "relationship reward unchanged")
	history = FactionBookModels.page(s._day, "military", 2).body
	check(history.contains("点清三件棉袄") and history.contains("军方照应"), "delivery and plaque stay in army history")
	var after := s.read_state()
	check(not s.social_command("deliver", detail).ok and s.read_state() == after, "duplicate cannot pay again")
	verify(s, "reward and scoped history")
	check(FactionBookModels.page(s._day, "military", 0).fields.has(["奖励", "50银元"]), "repeat offered task also says reward")
	check(s.social_command("accept_contract").ok, "repeat immediately available")
	check(s.social_command("gift").ok, "gift remains available")
	history = FactionBookModels.page(s._day, "military", 2).body
	check(history.contains("礼已托人送到"), "gift result remains in army history")
	verify(s, "repeat and gift history")
	for stage in ["closure", "claim", "supply"]:
		s = fixture_session(stage)
		var command := {"closure":"close", "claim":"claim_compensate", "supply":"decline_supply"}[stage] as String
		check(s.social_command(command).ok, "preserved army action " + stage)
		var last: Dictionary = s._day.state.social.notices.back()
		check(last.faction_id == "military" and SocialReadModels.faction_history(s._day.state, "military").contains(last.text), "army event result retained " + stage)
		verify(s, stage + " scoped history")

func faction_isolation() -> void:
	var s := fixture_session("delivery")
	var state := s._day.state
	SocialRules.notice(state, "孙大元也听说街坊嫌价低，今夜散客少了。")
	SocialRules.notice(state, "商会另有一封回信。", "guild")
	SocialRules.military_notice(state, "礼已收妥。")
	var before := s.read_state()
	var history := SocialReadModels.faction_history(state, "military")
	check(history.contains("礼已收妥") and not history.contains("商会另有") and not history.contains("孙大元也听说"), "source attribution, not name matching")
	check(SocialReadModels.faction_history(state, "guild").contains("商会另有") and not SocialReadModels.faction_history(state, "guild").contains("礼已收妥"), "future faction isolation")
	check(SocialReadModels.faction_history(state, "unknown") == "尚无往来可记。", "empty faction history")
	check(before == s.read_state(), "history filtering never mutates records")
	SocialRules.notice(state, "客人说这回给的钱厚道。")
	check(SocialReadModels.notice(state).contains("给的钱厚道"), "general customer feedback still displayed")
