extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var catalog := JsonContentProvider.new("res://tests/fixtures/m3_manifest.json").load_catalog().catalog
	var definition: RunDefinition = catalog.get_definition("runs", catalog.default_run_id)
	var save := SaveManager.new("user://tests/m2_process_checkpoint.json")
	var session := RunSession.new(definition, catalog.content_version, save, catalog)
	var ok := true
	if args.size() == 1 and args[0] == "write":
		session.execute("open_shop")
		ok = session.counter_command("offer", session.counter_model().active_id, "", 60).ok
		for command in ["close_shop", "wait_until_seal", "resolve_night"]:
			ok = session.execute(command).ok and ok
	elif args.size() == 1 and args[0] == "read":
		ok = session.load_checkpoint().ok
		var state := session.read_state()
		ok = ok and state.phase == "day_summary" and state.cash == 40 and state.inventory_instances.size() == 1 and state.ledger_entries.size() == 1
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	else: ok = false
	print("M2 PROCESS CHECKPOINT: ", args, " PASS=", ok)
	quit(0 if ok else 1)
