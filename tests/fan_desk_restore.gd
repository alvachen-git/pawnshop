extends SceneTree

func _initialize() -> void:
	var catalog := JsonContentProvider.new("res://data/shop_appraisal_manifest.json").load_catalog().catalog
	var run := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/desk-saved.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, run, 27, catalog, true)
	if state == null: push_error(codec.error_message); quit(1); return
	var expected := data.duplicate(true)
	expected.erase("save_version"); expected.erase("content_version")
	if not GhostSaveCodec.same(expected, state.to_read_model()): quit(1); return
	var item := CustomerManager.new().active(state).item
	var row := FanAppraisalService.record(state, item.instance_id)
	if row.pairs.brush.note != "different" or row.pairs.inscription.note != "unsure" or row.verdict != "mended": quit(1); return
	print("FAN DESK COLD RESTORE: 3 checks passed")
	quit(0)
