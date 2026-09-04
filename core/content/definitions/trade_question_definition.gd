class_name TradeQuestionDefinition
extends RefCounted

var _data: Dictionary
var id: String:
	get: return _data.id
var prompt: String:
	get: return _data.prompt
var minutes: int:
	get: return int(_data.minutes)
var requires_questions: Array:
	get: return _data.requires_questions.duplicate()
var requires_clues: Array:
	get: return _data.requires_clues.duplicate()
var pressure_clue: String:
	get: return _data.pressure_clue
var patience_cost: int:
	get: return int(_data.patience_cost)

func _init(data: Dictionary) -> void:
	_data = data.duplicate(true)

func answer(visit: CustomerVisit) -> String:
	for key in [visit.item.selected_variant_id, visit.situation_id, visit.reaction_id, "default"]:
		if _data.answers.has(key): return _data.answers[key]
	return ""
