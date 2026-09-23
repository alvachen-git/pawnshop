class_name LedgerPresenter
extends CounterFeaturePresenter

func feature_key() -> String:
	return "ledger"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	if command == "fd_event":
		if target in FirstDebt.DOCUMENTS:
			var result := _session.observe_document(target)
			if result.ok: _view.show_document(target)
		else: _session.event_command(target, detail)
	else: _session.commerce_command(command, target, detail)

func refresh() -> void:
	if not _view.is_visible_in_tree(): return
	var model: Dictionary = _session.counter_model()[feature_key()]
	model.old_debt = _session.old_debt_model()
	model.first_debt = _session.first_debt_model()
	_view.render(model)
