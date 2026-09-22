class_name ContentLoadResult
extends RefCounted

var catalog: ContentCatalog
var issues: Array = []


func _init(result_catalog: ContentCatalog = null, result_issues: Array = []) -> void:
	catalog = result_catalog
	issues = result_issues.duplicate()


func is_success() -> bool:
	if catalog == null:
		return false
	for issue in issues:
		if issue.severity == ContentIssue.ERROR:
			return false
	return true


func formatted_issues() -> String:
	var lines: PackedStringArray = []
	for issue in issues:
		lines.append(issue.format_message())
	return "\n".join(lines)

