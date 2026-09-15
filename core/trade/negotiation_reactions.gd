class_name NegotiationReactions
extends RefCounted

# Reception-only presentation history; never changes the save/replay contract.
var _state: RunState
var _visit_id := ""
var _rows: Array[Dictionary] = []

func record(day: DayController, visit: CustomerVisit, before: int, command: String, detail: String, result: ActionResult) -> void:
	if visit == null or not result.ok or visit.status != "active": return
	var relevant := command in ["pressure", "belittle", "concession", "offer", "pawn"]
	if command == "question":
		var scenario := TradeScenarioService.for_visit(day.definition, visit)
		var question := scenario.find_question(detail) if scenario != null else null
		relevant = question != null and not question.pressure_clue.is_empty()
	if not relevant: return
	if _state != day.state or _visit_id != visit.visit_id:
		_rows.clear()
	_state = day.state
	_visit_id = visit.visit_id
	_rows.push_front({"message": result.message, "before": before, "after": visit.trade.asking_price})

func for_visit(state: RunState, visit_id: String) -> Array[Dictionary]:
	if state != _state or visit_id != _visit_id: return []
	return _rows.duplicate(true)
