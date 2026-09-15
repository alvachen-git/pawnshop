class_name CounterStoryView
extends PanelContainer

signal closed
signal opened
signal choice_requested(event_id: String, choice_id: String)
var _title: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _close: Button
var _signature := ""

func _ready() -> void:
	name = "CounterStory"
	z_index = 12
	add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", Color("302719"))
	header.add_child(_title)
	_close = Button.new()
	_close.text = "收起"
	CounterTheme.style_paper_button(_close)
	_close.pressed.connect(collapse)
	header.add_child(_close)
	column.add_child(HSeparator.new())
	_text = RichTextLabel.new()
	_text.name = "StoryText"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_color_override("default_color", Color("302719"))
	_text.bbcode_enabled = false
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "StoryChoices"
	_choices.add_theme_constant_override("separation", 8)
	column.add_child(_choices)
	hide()

func render(model: Dictionary, signature: String) -> void:
	if model.is_empty():
		_signature = ""
		hide()
		return
	if _signature == signature: return
	_signature = signature
	_title.text = model.title
	_text.text = model.text
	_text.scroll_to_line(0)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for entry in model.buttons:
		var button := Button.new()
		button.name = "Choice_" + entry.detail
		button.text = entry.label
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 18)
		CounterTheme.style_paper_button(button)
		button.disabled = not entry.enabled
		button.pressed.connect(func() -> void: choice_requested.emit(entry.target_id, entry.detail))
		_choices.add_child(button)
	show_dialogue()

func collapse() -> void:
	hide()
	closed.emit()

func show_dialogue() -> void:
	opened.emit()
	show()
	if _choices.get_child_count() > 0: _choices.get_child(0).grab_focus()

func show_error(message: String) -> void:
	_text.text += "\n\n" + message
	show_dialogue()
