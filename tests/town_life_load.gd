extends SceneTree
func _initialize() -> void:
	var loaded := JsonContentProvider.new("res://data/town_life_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	if loaded.is_success():
		var run := loaded.catalog.get_definition("runs", loaded.catalog.default_run_id) as RunDefinition
		var store := GhostReplayStore.new()
		store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
		var session := RunSession.new(run, 48, store, loaded.catalog)
		print("TOWN LOAD: ", session._day.state.visits.size(), " visits; ", run.variety.keys())
	quit(0 if loaded.is_success() else 1)
