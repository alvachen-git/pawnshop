class_name QuestionDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _prompt: String
var prompt: String:
	get: return _prompt
var _answer: String
var answer: String:
	get: return _answer
var _minutes: int
var minutes: int:
	get: return _minutes

func _init(p_id: String, p_prompt: String, p_answer: String, p_minutes: int) -> void:
	_id = p_id
	_prompt = p_prompt
	_answer = p_answer
	_minutes = p_minutes

