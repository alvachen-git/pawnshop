extends SceneTree

# Run twice with -- write/read to verify a checkpoint survives process exit.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	var definition: RunDefinition = loaded.catalog.get_definition("runs", loaded.catalog.default_run_id)
	var save := SaveManager.new("user://tests/process_checkpoint.json")
	var session := RunSession.new(definition, loaded.catalog.content_version, save)
	var ok := true
	if args.size() == 1 and args[0] == "write":
		for command in ["open_shop", "short_task", "close_shop", "wait_until_seal", "resolve_night"]:
			ok = session.execute(command).ok and ok
	elif args.size() == 1 and args[0] == "read":
		ok = session.load_checkpoint().ok
		ok = ok and session.read_state().phase == "day_summary" and session.read_state().closed_at == 5 and session.read_state().summaries.size() == 1
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	else:
		ok = false
	print("PROCESS CHECKPOINT: ", args, " PASS=" , ok)
	quit(0 if ok else 1)
