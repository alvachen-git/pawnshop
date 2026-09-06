extends SceneTree

var passes := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL " + label)
func run() -> void:
	var result := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	check(result.is_success(), "v11 three night catalog")
	if not result.is_success(): quit(1); return
	var helper := VarietyTests.new()
	helper._expect = check
	helper.catalog = result.catalog
	helper.run_def = result.catalog.get_definition("runs", result.catalog.default_run_id)
	helper._random_contract()
	helper._content_matrix()
	helper._watchmaker()
	helper._provenance_money()
	helper._checkpoint_sources()
	helper._pawn_identity()
	helper._batch()
	for path in helper.paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("INTEGRATED VARIETY TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
