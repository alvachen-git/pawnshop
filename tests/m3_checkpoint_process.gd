extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var catalog := JsonContentProvider.new("res://data/content_manifest.json").load_catalog().catalog
	var run: RunDefinition = catalog.get_definition("runs", catalog.default_run_id)
	var save := SaveManager.new("user://tests/m3_process_checkpoint.json")
	var session := RunSession.new(run, catalog.content_version, save, catalog)
	var ok := true
	if args.size() == 1 and args[0] == "write":
		session.execute("open_shop")
		ok = session.counter_command("pawn", session.counter_model().active_id, "", 27).ok
		for command in ["close_shop", "wait_until_seal", "resolve_night", "continue_run"]: ok = session.execute(command).ok and ok
	elif args.size() == 1 and args[0] == "redeem":
		ok = session.load_checkpoint().ok
		if ok:
			ok = session.read_state().cash == 73 and session.read_state().pawn_tickets.size() == 1
			session.execute("open_shop")
			ok = session.commerce_command("redeem", session.read_state().pawn_tickets[0].ticket_id).ok and ok
			for command in ["close_shop", "wait_until_seal", "resolve_night"]: ok = session.execute(command).ok and ok
	elif args.size() == 1 and args[0] == "read":
		ok = session.load_checkpoint().ok
		if ok:
			var state := session.read_state()
			ok = state.cash == 106 and state.pawn_tickets[0].status == "redeemed" and state.inventory_instances[0].ownership_state == "redeemed" and state.ledger_entries.size() == 2 and state.summaries[1].realized_profit == 6
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	else: ok = false
	print("M3 PROCESS CHECKPOINT: ", args, " PASS=", ok)
	quit(0 if ok else 1)
