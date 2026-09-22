extends SceneTree

func _initialize() -> void:
	var catalog:=JsonContentProvider.new("res://data/fan_condition_manifest.json").load_catalog().catalog
	var run:=catalog.get_definition("runs",catalog.default_run_id) as RunDefinition
	var count:=0
	for stage in ["no-bench", "minor-checked", "major-pressed", "minor-fan_pressure-offer", "major-condition_pressure-pawn", "minor-retry"]:
		var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/fan-condition/"+stage+".json"))
		var codec:=SaveCodec.new()
		var state:=codec.decode(payload,run,29,catalog,true)
		if state==null: push_error(codec.error_message); quit(1); return
		var expected:=payload.duplicate(true); expected.erase("save_version"); expected.erase("content_version")
		if not GhostSaveCodec.same(expected,state.to_read_model()): push_error("Cold replay mismatch " + stage); quit(1); return
		# Loading an archive creates a new run token. Transaction dedupe survives.
		payload.run_token="fedcba9876543210fedcba9876543210"
		payload.ghost_origin.run_token=payload.run_token
		if codec.decode(payload,run,29,catalog,true)==null: push_error("fork replay " + codec.error_message); quit(1); return
		count+=3
	print("FAN CONDITION COLD RESTORE: %d checks passed" % count)
	quit(0)
