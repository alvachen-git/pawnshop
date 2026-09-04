class_name InventoryPresenter
extends CounterFeaturePresenter

func feature_key() -> String:
	return "inventory"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	_session.commerce_command(command, target, detail)
