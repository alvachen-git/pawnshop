class_name ContentIssue
extends RefCounted

const ERROR := "error"
const WARNING := "warning"

var severity: String
var code: String
var source_path: String
var field_path: String
var message: String


func _init(
	issue_severity: String,
	issue_code: String,
	issue_source_path: String,
	issue_field_path: String,
	issue_message: String
) -> void:
	severity = issue_severity
	code = issue_code
	source_path = issue_source_path
	field_path = issue_field_path
	message = issue_message


func format_message() -> String:
	return "[%s] %s · %s · %s: %s" % [
		severity.to_upper(),
		code,
		source_path,
		field_path,
		message,
	]

