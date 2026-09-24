extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/start.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame; await process_frame
	var s: RunSession = main.get_node("Bootstrap").session
	if s == null: push_error("preview failed"); quit(1); return
	var version := 41 if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--recovery-release-preview=")) else 40
	var okay := s.content_version == version and s.definition.initial_cash == 300 and main.title_menu == null
	okay = okay and s._save.library.path.begins_with("user://tests/v%d_preview/" % version)
	var stage: String = main.get_node("Bootstrap").preview_stage
	var action: ActionResult
	if stage == "seller": action = s.counter_command("reject", s._counter.customers.active(s._day.state).visit_id)
	elif stage == "recall": action = s.execute("prep_phoenix_invite")
	elif stage == "truth": action = s.event_command("fd_truth", "tell")
	elif stage == "compensation": action = s.event_command("fd_compensation", "offer")
	else: action = s.event_command("fd_settle", "pay")
	var saved := s._save.library.read_entry("auto/" + String(s.definition.id))
	okay = okay and action.ok and not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), s.read_state())
	print("RECOVERY PREVIEW ", stage, " ", "PASS" if okay else "FAIL", " night", s._day.state.current_night_index, " cash", s._day.state.cash)
	if not okay: push_error("preview/save mismatch")
	main.queue_free(); await process_frame; quit(0 if okay else 1)
