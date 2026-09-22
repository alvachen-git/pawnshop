class_name ActionResult
extends RefCounted

var ok: bool
var message: String

func _init(success: bool, detail: String) -> void:
	ok = success
	message = detail
