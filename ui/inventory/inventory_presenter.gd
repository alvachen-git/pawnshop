class_name InventoryPresenter
extends CounterFeaturePresenter

func feature_key() -> String:
	return "inventory"

func _on_intent(command: String, target: String, detail: String, _amount: int) -> void:
	if command == "luxury_open":
		LuxuryAppraisalView.open(_view, _session, target)
		return
	if command == "fan_open": FanAppraisalView.open(_view, _session, target)
	elif command == "condition": _session.fan_command("condition", target)
	elif command == "growth_display": _session.growth_command("display", target)
	elif command == "growth_withdraw": _session.growth_command("withdraw")
	else: _session.commerce_command(command, target, detail)
