extends SceneTree

func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/first_debt_reckoning_manifest.json").load_catalog()
	var run := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v29/chen-delivered.json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, run, 29, loaded.catalog, true)
	if state == null: push_error(codec.error_message); quit(1); return
	var store := GhostReplayStore.new(); store.origin = data.ghost_origin
	var session := RunSession.new(run, 29, store, loaded.catalog); session._day.state = state
	if FirstDebt.chen_waiting(state) or not session.counter_model().get("case_dialogue", {}).is_empty():
		push_error("delivery visitor reappeared after process restore"); quit(1); return
	if not session.observe_document("fd_customer_ticket").ok or not session.counter_model().get("case_dialogue", {}).is_empty():
		push_error("ticket investigation after departure failed"); quit(1); return
	print("CHEN DELIVERY NEW PROCESS: departed visitor stays absent; original ticket remains readable")
	quit(0)
