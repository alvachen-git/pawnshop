class_name LedgerPresenter
extends CounterFeaturePresenter

var _feedback := ""
var _feedback_page := -1

func feature_key() -> String:
	return "ledger"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	_feedback = ""
	var page := (_view as LedgerPanel)._selected
	var result: ActionResult
	if command == "fd_event":
		if target in FirstDebt.DOCUMENTS:
			result = _session.observe_document(target)
			if result.ok: _view.show_document(target)
		else: result = _session.event_command(target, detail)
	else: result = _session.commerce_command(command, target, detail)
	if not result.ok:
		_feedback = result.message
		_feedback_page = page
	refresh()

func refresh() -> void:
	if not _view.is_visible_in_tree():
		_feedback = ""
		return
	if _session.message != _feedback: _feedback = ""
	var model: Dictionary = _session.counter_model()[feature_key()]
	model.old_debt = _session.old_debt_model()
	model.first_debt = _session.first_debt_model()
	model.ledger_feedback = _feedback
	model.feedback_page = _feedback_page
	_view.render(model)
