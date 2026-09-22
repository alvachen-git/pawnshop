extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var loaded := JsonContentProvider.new("res://tests/fixtures/m4_manifest.json").load_catalog()
	if not loaded.is_success():
		quit(1)
		return
	var catalog := loaded.catalog
	var run: RunDefinition = catalog.get_definition("runs", catalog.default_run_id)
	var save := SaveManager.new("user://tests/m4_process_checkpoint.json")
	var session := RunSession.new(run, catalog.content_version, save, catalog)
	var ok := true
	if args.size() == 1 and args[0] == "write":
		ok = _resolve(session)
		for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "continue_run"]: ok = session.execute(command).ok and ok
		ok = ok and session.read_state().pending_event_id == "cash_lesson"
	elif args.size() == 1 and args[0] == "choose":
		ok = session.load_checkpoint().ok
		ok = ok and session.read_state().pending_event_id == "cash_lesson" and "contact_requested" in session.read_state().narrative_flags
		ok = _resolve(session) and ok
		for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night"]: ok = session.execute(command).ok and ok
	elif args.size() == 1 and args[0] == "read":
		ok = session.load_checkpoint().ok
		var state := session.read_state()
		ok = ok and state.phase == "day_summary" and state.current_night_index == 2 and "buyer_introduced" in state.narrative_flags and state.event_history.size() == 4 and state.pending_event_id.is_empty()
		ok = ok and not session.event_command("buyer_reply", "accept").ok
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	else: ok = false
	print("M4 PROCESS CHECKPOINT: ", args, " PASS=", ok, " ", session.message)
	quit(0 if ok else 1)

func _resolve(session: RunSession) -> bool:
	for guard in 10:
		var model := session.event_model()
		if model.pending_id.is_empty(): return true
		if not session.event_command(model.pending_id, model.buttons[0].detail).ok: return false
	return false
