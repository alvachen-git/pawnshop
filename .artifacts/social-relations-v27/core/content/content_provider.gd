class_name ContentProvider
extends RefCounted


func load_catalog() -> ContentLoadResult:
	var issue := ContentIssue.new(
		ContentIssue.ERROR,
		"provider_not_implemented",
		"ContentProvider",
		"load_catalog",
		"内容提供者必须实现 load_catalog()。"
	)
	return ContentLoadResult.new(null, [issue])

