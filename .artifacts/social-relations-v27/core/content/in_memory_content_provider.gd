class_name InMemoryContentProvider
extends ContentProvider

var _catalog: ContentCatalog


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func load_catalog() -> ContentLoadResult:
	if _catalog == null:
		var issue := ContentIssue.new(ContentIssue.ERROR, "missing_catalog", "InMemoryContentProvider", "$", "测试目录不能为空。")
		return ContentLoadResult.new(null, [issue])
	var issues := DomainValidator.new().validate_catalog(_catalog)
	return ContentLoadResult.new(_catalog if issues.is_empty() else null, issues)
