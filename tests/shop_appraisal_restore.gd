extends SceneTree

func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/shop_appraisal_manifest.json").load_catalog()
	var catalog := loaded.catalog
	var run := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/saved-claim.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(payload, run, 27, catalog, true)
	if state == null:
		push_error(codec.error_message); quit(1); return
	var expected := payload.duplicate(true)
	expected.erase("save_version"); expected.erase("content_version")
	if not GhostSaveCodec.same(state.to_read_model(), expected): quit(1); return
	var item := CustomerManager.new().active(state).item
	if item.expert_reviewed or item.goods.fan_claim != "mended" or GoodsExpertise.value(item, catalog.get_definition("items", GoodsExpertise.FAN)) != 23:
		quit(1); return
	print("APPRAISAL CROSS PROCESS: 3 checks passed")
	quit(0)
