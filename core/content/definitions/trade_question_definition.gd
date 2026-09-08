class_name TradeQuestionDefinition
extends RefCounted

var _data: Dictionary
var requires_mirror: bool:
	get: return _data.get("requires_mirror", false)
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
	if id == "circumstance" and visit.voice.has("circumstance"): return String(visit.voice.circumstance)
	if not visit.person.is_empty() and id == "origin":
		return "当户口供（待核）：" + String(visit.voice.get("origin", "旧物经手留下，您可以核对凭据。")) + "\n" + String(visit.voice.get("source_claim", ""))
	for key in [visit.item.selected_variant_id + "/" + visit.reaction_id, visit.item.selected_variant_id, visit.situation_id, visit.reaction_id, "default"]:
		if _data.answers.has(key):
			var text: String = _data.answers[key]
			if not visit.person.is_empty():
				text = "当户口供（待核）：" + String(visit.voice.get("condition" if id == "condition" else "evidence", "")) + text
			return text
	return ""
