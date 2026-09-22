extends "res://tests/social_relations.gd"

func run() -> void:
	if not setup(): quit(1); return
	for stage in ["preparation", "supply", "claim"]:
		var path: String = "res://tests/fixtures/social_book_legacy/" + stage + ".json"
		var original := FileAccess.get_file_as_string(path)
		check(original.contains("陈经办"), "frozen fixture predates representative rename")
		var data: Dictionary = JSON.parse_string(original)
		var definition := catalog.get_definition("runs", data.run_definition_id) as RunDefinition
		InvestigationSaveCodec.clear_cache()
		var codec := SaveCodec.new()
		var restored := codec.decode(data, definition, 26, catalog, true)
		check(restored != null, "old v26 snapshot restored " + stage + " " + codec.error_message)
		if restored == null: continue
		check(restored.cash == data.cash and restored.social.military == data.social.military, "financial and relation history unchanged")
		check(GhostSaveCodec.same(restored.action_journal, data.action_journal), "all historical choices preserved")
		check(JSON.stringify(restored.to_read_model()).contains("孙大元"), "new name in replayed history")
		check(not JSON.stringify(restored.to_read_model()).contains("陈经办"), "old representative removed from display state")
		var resaved := codec.encode(restored, 26)
		check(codec.decode(resaved, definition, 26, catalog, true) != null, "migrated save can reload")
		check(FileAccess.get_file_as_string(path) == original, "reading does not rewrite old save")
		for field in ["military", "reputation"]:
			var forged := data.duplicate(true)
			forged.social[field] += 1
			check(codec.decode(forged, definition, 26, catalog, true) == null, "copy alias does not accept forged " + field)
		var forged_cash := data.duplicate(true)
		forged_cash.cash += 1
		check(codec.decode(forged_cash, definition, 26, catalog, true) == null, "copy alias does not accept forged cash")
	var s := fresh_growth()
	check(FactionBookModels.roster(s._day.state).is_empty(), "no undiscovered names in new book")
	s._day.state.social.introduced = true
	var entries := FactionBookModels.roster(s._day.state)
	check(entries.size() == 1 and entries[0].representative == "孙大元", "only introduced playable faction listed")
	var before := JSON.stringify(s.read_state())
	for step in 3:
		FactionBookModels.roster(s._day.state)
		FactionBookModels.attitude(s._day.state, "military")
		FactionBookModels.page(s._day, "military", 0)
		FactionBookModels.page(s._day, "military", 1)
		FactionBookModels.page(s._day, "military", 2)
	check(JSON.stringify(s.read_state()) == before, "opening and browsing never alter simulation")
	var procurement := FactionBookModels.page(s._day, "military", 0)
	var gift := FactionBookModels.page(s._day, "military", 1)
	var history := FactionBookModels.page(s._day, "military", 2)
	check(procurement.fields.size() == 4 and not procurement.buttons.any(func(row: Dictionary) -> bool: return row.command == "gift"), "procurement structured and excludes gift")
	check(gift.buttons.size() == 1 and gift.buttons[0].command == "gift" and gift.fields.size() == 3, "gift costs and interval have their own page")
	check(history.buttons.is_empty(), "history is read only")
	for kind in ["fee", "closure", "claim", "supply"]:
		s._day.state.social.pending = {"kind":kind}
		check(FactionBookModels.pending_section(s._day.state) == (0 if kind == "supply" else 1), "urgent letter assigned " + kind)
	s._day.state.social.pending.clear()
	FactionBookModels.perform(s, "unknown", "gift", "")
	check(JSON.stringify(s.read_state()) == before, "unknown faction cannot invoke army action")
	for value in [-100, -80, -50, -20, 0, 20, 50, 80, 100]:
		s._day.state.social.military = value
		check(not FactionBookModels.attitude(s._day.state, "military").contains(str(value)), "attitudes hide exact scores")
	legacy_unchanged()
	print("SOCIAL BOOK: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
