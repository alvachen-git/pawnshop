class_name TradeFeedbackView
extends Control

# Compatibility holder for result consumers. The recent-result bar renders
# replies; this node never creates an overlay, timer, sound or input blocker.
var record: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func cancel() -> void:
	hide()
