class_name TradeScenarioDefinition
extends RefCounted

var _data: Dictionary
var _questions: Array[TradeQuestionDefinition] = []
var id: String:
	get: return _data.id
var slot_id: String:
	get: return _data.slot_id
var item_id: String:
	get: return _data.item_id
var introduction: String:
	get: return _data.introduction
var variant_ids: Array:
	get: return _data.variant_ids.duplicate()
var situations: Array:
	get: return _data.situations.duplicate()
var reactions: Array:
	get: return _data.reactions.duplicate()
var questions: Array[TradeQuestionDefinition]:
	get: return _questions.duplicate()
var images: Array:
	get: return _data.images.duplicate(true)
var benefit_groups: Dictionary:
	get: return _data.benefit_groups.duplicate()
var concession_question: String:
	get: return _data.concession_question
var concession_amount: int:
	get: return int(_data.concession_amount)
var concession_minutes: int:
	get: return int(_data.concession_minutes)
var urgent_wait_minutes: int:
	get: return int(_data.urgent_wait_minutes)

func _init(data: Dictionary) -> void:
	_data = data.duplicate(true)
	for row in data.questions: _questions.append(TradeQuestionDefinition.new(row))

func find_question(key: String) -> TradeQuestionDefinition:
	for question in _questions:
		if question.id == key: return question
	return null

func group(clue: String) -> String:
	return _data.benefit_groups.get(clue, clue)
