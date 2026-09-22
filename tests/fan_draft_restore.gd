extends SceneTree

func _initialize() -> void:
	var catalog := JsonContentProvider.new("res://data/shop_appraisal_manifest.json").load_catalog().catalog
	var run := catalog.get_definition("runs",catalog.default_run_id) as RunDefinition
	for stage in ["draft-uncommitted", "draft-committed"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/" + stage + ".json"))
		var codec := SaveCodec.new()
		var state := codec.decode(data,run,27,catalog,true)
		if state == null: push_error(codec.error_message); quit(1); return
		var expected := data.duplicate(true)
		expected.erase("save_version"); expected.erase("content_version")
		if not GhostSaveCodec.same(expected,state.to_read_model()): quit(1); return
		var id := CustomerManager.new().active(state).item.instance_id
		var pairs := FanAppraisalService.notes(state,id)
		if pairs.brush.note != "different" or pairs.inscription.note != "unsure": quit(1); return
		if FanAppraisalService.record(state,id).verdict != ("" if stage == "draft-uncommitted" else "sound"): quit(1); return
	print("FAN DRAFT COLD RESTORE: 8 checks passed")
	quit(0)
