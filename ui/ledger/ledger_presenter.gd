class_name LedgerPresenter
extends CounterFeaturePresenter

func feature_key() -> String:
	return "ledger"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	_session.commerce_command(command, target, detail)
