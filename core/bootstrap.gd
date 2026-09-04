class_name Bootstrap
extends Node

signal content_ready(catalog: ContentCatalog)
signal content_failed(issues: Array)

@export_file("*.json") var manifest_path := "res://data/content_manifest.json"
@export var save_path := "user://p0/autosave_v7.json"

var catalog: ContentCatalog
var session: RunSession


func initialize() -> ContentLoadResult:
	var provider := JsonContentProvider.new(manifest_path)
	var result := provider.load_catalog()
	if result.is_success():
		catalog = result.catalog
		var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
		if definition == null:
			result.issues.append(ContentIssue.new("error", "missing_run", manifest_path, "default_run_id", "缺少默认运行定义。"))
			content_failed.emit(result.issues)
			return result
		var saves := SaveManager.new(save_path)
		if save_path == "user://p0/autosave_v7.json":
			saves.legacy_archive_path = "user://p0/autosave.json"
			saves.prior_version_path = "user://p0/autosave_v6.json"
		session = RunSession.new(definition, catalog.content_version, saves, catalog)
		content_ready.emit(catalog)
	else:
		content_failed.emit(result.issues)
	return result
