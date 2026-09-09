class_name Bootstrap
extends Node

signal content_ready(catalog: ContentCatalog)
signal content_failed(issues: Array)

@export_file("*.json") var manifest_path := "res://data/content_manifest.json"
@export var save_path := "user://p0/autosave_v12.json"

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
		if OrdinarySamplePlan.enabled(definition) or SevenNightPlan.enabled(definition):
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int():
					definition._seed = int(argument.trim_prefix("--seed=")) & 0x7fffffff
					definition._randomize_seed = false
		var saves := SaveManager.new(save_path)
		if save_path == "user://p0/autosave_v12.json":
			for old_path in ["user://p0/autosave_v11.json", "user://p0/autosave_v10.json", "user://p0/autosave_v9.json"]:
				if FileAccess.file_exists(old_path):
					saves.import_checkpoint_path = old_path
					break
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v11.json":
			for old_path in ["user://p0/autosave_v10.json", "user://p0/autosave_v9.json"]:
				if FileAccess.file_exists(old_path):
					saves.import_checkpoint_path = old_path
					break
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v10.json":
			saves.import_checkpoint_path = "user://p0/autosave_v9.json" if FileAccess.file_exists("user://p0/autosave_v9.json") else "user://p0/autosave_v8.json"
			saves.prior_version_path = "user://p0/autosave_v8.json"
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v9.json":
			saves.import_checkpoint_path = "user://p0/autosave_v8.json"
			saves.prior_version_path = "user://p0/autosave_v8.json"
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v8.json":
			saves.prior_version_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v7.json":
			saves.legacy_archive_path = "user://p0/autosave.json"
			saves.prior_version_path = "user://p0/autosave_v6.json"
		saves.library = SaveLibrary.new() if not save_path.begins_with("user://tests/") else null
		saves.catalog = catalog
		session = RunSession.new(definition, catalog.content_version, saves, catalog)
		if OrdinarySamplePlan.enabled(definition) or SevenNightPlan.enabled(definition): print("RUN SEED: ", session.read_state().run_seed)
		if SevenNightPlan.enabled(definition) and "--log-plan" in OS.get_cmdline_user_args(): print("SEVEN VISIT PLAN: ", JSON.stringify(session.read_state().seven_plan))
		if FamiliarStories.enabled(definition) and "--log-plan" in OS.get_cmdline_user_args(): print("FAMILIAR STORY PLAN: ", JSON.stringify(session.read_state().familiar_plan))
		content_ready.emit(catalog)
	else:
		content_failed.emit(result.issues)
	return result
