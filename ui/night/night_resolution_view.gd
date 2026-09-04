class_name NightResolutionView
extends FeaturePanel

signal command_requested(command: String)
var _body: Label
var _resolve: Button
var _continue: Button

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_resolve = Button.new()
	_resolve.disabled = true
	_resolve.text = "结算本夜（占位）并自动保存"
	_resolve.pressed.connect(command_requested.emit.bind("resolve_night"))
	column.add_child(_resolve)
	_continue = Button.new()
	_continue.disabled = true
	_continue.pressed.connect(command_requested.emit.bind("continue_run"))
	column.add_child(_continue)

func render(model: Dictionary) -> void:
	_body.text = model.body
	_resolve.text = model.get("resolve_label", "结算本夜（占位）并自动保存")
	_resolve.disabled = not model.can_resolve
	_continue.disabled = not model.can_continue
	_continue.text = model.continue_label
