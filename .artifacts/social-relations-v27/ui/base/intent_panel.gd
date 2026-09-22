class_name IntentPanel
extends FeaturePanel

signal intent(command: String, visit_id: String, detail: String, amount: int)
var _body: Label
var _buttons: VBoxContainer
var _column: VBoxContainer
var _visit_id := ""

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 10)
	scroll.add_child(_column)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 14)
	_column.add_child(_body)
	_buttons = VBoxContainer.new()
	_column.add_child(_buttons)

func render(model: Dictionary) -> void:
	_body.text = model.body
	_visit_id = model.get("visit_id", "")
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for entry in model.get("buttons", []):
		var button := Button.new()
		button.text = entry.label
		button.disabled = not entry.enabled
		button.tooltip_text = entry.reason
		button.pressed.connect(_emit_intent.bind(entry.command, entry.get("target_id", _visit_id), entry.detail))
		_buttons.add_child(button)

func _emit_intent(command: String, visit_id: String, detail: String) -> void:
	intent.emit(command, visit_id, detail, 0)
