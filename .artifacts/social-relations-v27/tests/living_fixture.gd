extends RefCounted

static func before(catalog: ContentCatalog, predicate: Callable) -> RunSession:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v22/accept.json"))
	var store := GhostReplayStore.new()
	store.origin = data.ghost_origin
	var session := RunSession.new(catalog.get_definition("runs", catalog.default_run_id), 22, store, catalog)
	for row in data.ghost_commands:
		if predicate.call(session, row): return session
		session.callv(row.method, row.args)
	return session

static func guest(catalog: ContentCatalog, id: String) -> RunSession:
	return before(catalog, func(s: RunSession, row: Dictionary) -> bool:
		var v := CustomerManager.new().active(s._day.state)
		return v != null and v.customer_id == id and row.method == "inspect_customer")
