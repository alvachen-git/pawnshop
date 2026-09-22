class_name InventoryPresenter
extends CounterFeaturePresenter

func feature_key() -> String:
	return "inventory"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	if command == "growth_display": _session.growth_command("display", target)
	elif command == "growth_withdraw": _session.growth_command("withdraw")
	else: _session.commerce_command(command, target, detail)
