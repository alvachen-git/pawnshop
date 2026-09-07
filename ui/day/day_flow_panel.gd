class_name DayFlowPanel
extends FeaturePanel

signal command_requested(command: String)

var _description: Label
var _message: Label
var _commands: VBoxContainer
var _buttons: Dictionary = {}

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_description)
	_commands = VBoxContainer.new()
	column.add_child(_commands)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 13)
	column.add_child(_message)

func render(model: Dictionary) -> void:
	_description.text = model.description
	_message.text = model.message
	if _buttons.keys() != model.commands.map(func(entry: Dictionary) -> String: return entry.id):
		for child in _commands.get_children(): _commands.remove_child(child); child.queue_free()
		_buttons.clear()
		for entry in model.commands:
			var button := Button.new()
			button.text = entry.label
			_commands.add_child(button)
			if model.get("preparation", false):
				button.add_theme_font_size_override("font_size", 16)
				for state in ["normal", "hover", "pressed", "disabled"]:
					var style := button.get_theme_stylebox(state).duplicate() as StyleBox
					style.content_margin_top = 3
					style.content_margin_bottom = 3
					button.add_theme_stylebox_override(state, style)
			button.pressed.connect(command_requested.emit.bind(entry.id))
			_buttons[entry.id] = button
	for entry in model.commands:
		_buttons[entry.id].text = entry.label
		_buttons[entry.id].disabled = not entry.enabled
		_buttons[entry.id].visible = entry.get("visible", true)
		_buttons[entry.id].tooltip_text = entry.get("tooltip", "" if entry.enabled else entry.get("reason", "当前阶段不可用或剩余时间不足。"))
