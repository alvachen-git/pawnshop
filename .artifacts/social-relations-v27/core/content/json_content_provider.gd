class_name JsonContentProvider
extends ContentProvider

var manifest_path: String
var _schema_validator := SourceSchemaValidator.new()
var _mapper := ContentMapper.new()
var _domain_validator := DomainValidator.new()


func _init(provider_manifest_path: String) -> void:
	manifest_path = provider_manifest_path


func load_catalog() -> ContentLoadResult:
	var issues: Array = []
	var manifest_read := _read_json(manifest_path)
	if not manifest_read.ok:
		issues.append(manifest_read.issue)
		return ContentLoadResult.new(null, issues)
	var manifest: Variant = manifest_read.data
	issues.append_array(_schema_validator.validate_manifest(manifest, manifest_path))
	if _has_errors(issues):
		return ContentLoadResult.new(null, issues)

	var catalog := ContentCatalog.new()
	catalog.content_version = int(manifest.content_version)
	catalog.default_run_id = manifest.get("default_run_id", "")
	for source_entry in manifest.sources:
		var source_path: String = source_entry.path
		var source_read := _read_json(source_path)
		if not source_read.ok:
			issues.append(source_read.issue)
			continue
		issues.append_array(_schema_validator.validate_collection(source_entry.kind, source_read.data, source_path))
		if _has_errors(issues):
			continue
		for record in source_read.data.records:
			var definition := _mapper.map_record(source_entry.kind, record)
			if definition == null:
				issues.append(ContentIssue.new(ContentIssue.ERROR, "mapping_failed", source_path, record.id, "记录无法映射为领域定义。"))
			elif not catalog.add_definition(source_entry.kind, definition):
				issues.append(ContentIssue.new(ContentIssue.ERROR, "duplicate_id", source_path, record.id, "同类型内容ID重复。"))

	if not _has_errors(issues):
		issues.append_array(_domain_validator.validate_catalog(catalog))
	if _has_errors(issues):
		return ContentLoadResult.new(null, issues)
	return ContentLoadResult.new(catalog, issues)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"issue": ContentIssue.new(ContentIssue.ERROR, "file_not_found", path, "$", "找不到内容文件。"),
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"issue": ContentIssue.new(ContentIssue.ERROR, "file_open_failed", path, "$", "无法打开内容文件。"),
		}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"ok": false,
			"issue": ContentIssue.new(
				ContentIssue.ERROR,
				"invalid_json",
				path,
				"line %d" % parser.get_error_line(),
				parser.get_error_message()
			),
		}
	return {"ok": true, "data": parser.data}


func _has_errors(issues: Array) -> bool:
	for issue in issues:
		if issue.severity == ContentIssue.ERROR:
			return true
	return false
