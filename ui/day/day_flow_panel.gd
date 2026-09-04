class_name DayFlowPanel
extends FeaturePanel

signal command_requested(command: String)
signal new_requested
signal load_requested

var _description: Label
var _message: Label
var _commands: VBoxContainer
var _load: Button
var _confirmation: ConfirmationDialog
var _pending_intent := ""
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
	var row := HBoxContainer.new()
	column.add_child(row)
	var restart := Button.new()
	restart.text = "新游戏"
	restart.pressed.connect(_confirm.bind("new"))
	row.add_child(restart)
	_load = Button.new()
	_load.text = "读取夜末存档"
	_load.pressed.connect(_confirm.bind("load"))
	row.add_child(_load)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "确认切换运行"
	_confirmation.ok_button_text = "确认"
	_confirmation.cancel_button_text = "取消"
	_confirmation.confirmed.connect(_accept_confirmation)
	add_child(_confirmation)

func render(model: Dictionary) -> void:
	_description.text = model.description
	_message.text = model.message
	_load.disabled = not model.has_save
	if _buttons.is_empty():
		for entry in model.commands:
			var button := Button.new()
			button.text = entry.label
			button.pressed.connect(command_requested.emit.bind(entry.id))
			_commands.add_child(button)
			_buttons[entry.id] = button
	for entry in model.commands:
		_buttons[entry.id].disabled = not entry.enabled
		_buttons[entry.id].tooltip_text = "" if entry.enabled else "当前阶段不可用或剩余时间不足。"

func _confirm(intent: String) -> void:
	_pending_intent = intent
	_confirmation.dialog_text = "将放弃当前未保存的夜内进度。是否继续？"
	_confirmation.popup_centered()

func _accept_confirmation() -> void:
	if _pending_intent == "new":
		new_requested.emit()
	else:
		load_requested.emit()
