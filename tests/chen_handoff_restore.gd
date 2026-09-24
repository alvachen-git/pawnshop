extends SceneTree

func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	var catalog: ContentCatalog = loaded.catalog
	var run := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	for route in ["buy", "reject", "failed", "reject_later"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v29/chen-handoff-" + route + ".json"))
		var codec := SaveCodec.new()
		var state := codec.decode(data, run, 29, catalog, true)
		if state == null: push_error(codec.error_message); quit(1); return
		var store := GhostReplayStore.new()
		store.origin = data.ghost_origin
		var session := RunSession.new(run, 29, store, catalog)
		session._day.state = state
		var model := session.counter_model()
		if not model.get("case_dialogue", {}).get("auto_open", false) or model.visual.customer_id != "fd_chen" or session.bell_model().enabled:
			push_error("restored handoff exposes next guest " + route); quit(1); return
	for route in ["buy", "reject", "failed", "later"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v29/chen-complete-" + route + ".json"))
		var codec := SaveCodec.new()
		var state := codec.decode(data, run, 29, catalog, true)
		if state == null: push_error(codec.error_message); quit(1); return
		var store := GhostReplayStore.new()
		store.origin = data.ghost_origin
		var session := RunSession.new(run, 29, store, catalog)
		session._day.state = state
		if not session.counter_model().get("case_dialogue", {}).is_empty():
			push_error("completed recognition reappears after restore " + route); quit(1); return
	print("CHEN HANDOFF NEW PROCESS: 4 pending scenes restored; 4 completed scenes stay departed")
	quit(0)
