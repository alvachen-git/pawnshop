extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/start.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame; await process_frame
	var s: RunSession = main.get_node("Bootstrap").session
	if s == null: push_error("preview failed"); quit(1); return
	var okay := s.content_version == 31 and s.definition.initial_cash == 300 and main.title_menu == null
	okay = okay and s._save.library.path.begins_with("user://tests/v31_preview/")
	if not s.counter_model().get("case_dialogue", {}).is_empty():
		okay = okay and main.get_node("CounterScreen").first_debt_conversation.visible
	var before := s.read_state()
	var action: ActionResult
	if s._day.state.phase == &"pre_open": action = s.execute("prep_dragon_search" if not FirstDebt.flag(s._day.state, "fd_search_message") else "prep_dragon_invite")
	elif s._day.state.current_night_index == 11: action = s.observe_document("fd_receipt")
	elif not FirstDebt.flag(s._day.state, "fd_search_promised"): action = s.event_command("fd_search_motive", "help")
	elif not DragonSearch.quoted(s._day.state): action = s.event_command("fd_dragon_quote", "dear" if s._day.state.social.reputation < 0 else "fair")
	else: action = s.event_command("fd_dragon_deal", "buy" if "--dragon-preview=buy" in OS.get_cmdline_user_args() else "later")
	if "--dragon-preview=buy" in OS.get_cmdline_user_args():
		okay = okay and before.cash == 369 and s._day.state.cash == 169 and FirstDebt.owned(s._day.state, FirstDebt.DRAGON) != null
		okay = okay and s._day.state.game_minutes == before.game_minutes + 5
		var after := s.read_state()
		okay = okay and not s.event_command("fd_dragon_deal", "buy").ok and s.read_state() == after
	var saved := s._save.library.read_entry("auto/first_debt_dragon_search")
	okay = okay and action.ok and not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state())
	print("DRAGON PREVIEW ", "PASS" if okay else "FAIL", " night", before.current_night_index, " ", action.message)
	if not okay: push_error("preview or save mismatch")
	main.queue_free(); await process_frame; quit(0 if okay else 1)
