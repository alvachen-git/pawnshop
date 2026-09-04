extends Node

@onready var _bootstrap: Bootstrap = $Bootstrap
@onready var _counter_screen: CounterScreen = $CounterScreen


func _ready() -> void:
	_bootstrap.content_ready.connect(_counter_screen.show_content_ready)
	_bootstrap.content_failed.connect(_counter_screen.show_content_error)
	_bootstrap.initialize()
	if _bootstrap.session != null:
		_counter_screen.bind_session(_bootstrap.session)
