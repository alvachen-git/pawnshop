class_name CounterView
extends PanelContainer

func render(model: Dictionary) -> void:
	$CounterMargin/CounterLayout/CustomerPlaceholder/CustomerText.text = model.customer
	$CounterMargin/CounterLayout/Desk/DeskLayout/ItemPlaceholder.text = model.item
	%CounterMessage.text = model.queue


func set_counter_message(message: String) -> void:
	%CounterMessage.text = message
