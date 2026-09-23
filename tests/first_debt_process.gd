extends SceneTree
func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_manifest.json").load_catalog()
	if not loaded.is_success(): quit(1); return
	var run := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
	var count := 0
	for name in DirAccess.get_files_at("res://.godot/qa/v28/"):
		if not name.begins_with("committed-") or not name.ends_with(".json"): continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v28/" + name))
		var codec := SaveCodec.new()
		var state := codec.decode(data, run, 28, loaded.catalog, true)
		if state == null: push_error(name + ": " + codec.error_message); quit(1); return
		count += 1
	print("FIRST DEBT NEW PROCESS: ", count, " committed checkpoints restored")
	quit(0 if count >= 13 else 1)
