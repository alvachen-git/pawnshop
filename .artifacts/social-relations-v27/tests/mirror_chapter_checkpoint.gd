extends SceneTree

func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/mirror_chapter_manifest.json").load_catalog()
	if not loaded.is_success(): push_error("FAIL chapter catalog"); quit(1); return
	var run: RunDefinition = loaded.catalog.get_definition("runs", "mirror_chapter")
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/mirror_chapter/cross_process.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(payload, run, 16, loaded.catalog)
	if state == null: push_error("FAIL cross process: " + codec.error_message); quit(1); return
	if state.phase != &"run_ended" or "wm_seek" not in state.narrative_flags or state.mirror_history.size() != 2:
		push_error("FAIL persisted chapter knowledge"); quit(1); return
	print("MIRROR CROSS PROCESS: 3 assertions, 0 failures")
	quit(0)
