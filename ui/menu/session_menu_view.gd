class_name SessionMenuView
extends PanelContainer

signal save_requested
signal leave_requested(destination: String)
signal new_requested
signal load_requested
signal panel_requested(panel_id: StringName)

var _save_button: Button
var _leave_buttons: Array[Button] = []
var _manual_storage := false
var _confirmation: ConfirmationDialog
var _pending_intent := ""
var _error_dialog: AcceptDialog


func _ready() -> void:
	%NewRunButton.pressed.connect(_confirm.bind("new"))
	%LoadRunButton.pressed.connect(func() -> void:
		if _manual_storage: hide(); load_requested.emit()
		else: _confirm("load")
	)
	_save_button = Button.new()
	_save_button.text = "保存游戏"
	_save_button.pressed.connect(func() -> void: hide(); save_requested.emit())
	%LoadRunButton.get_parent().add_child(_save_button)
	%LoadRunButton.get_parent().move_child(_save_button, %LoadRunButton.get_index())
	for destination in ["title", "quit"]:
		var button := Button.new()
		button.text = "返回主菜单" if destination == "title" else "退出游戏"
		button.pressed.connect(func() -> void: hide(); leave_requested.emit(destination))
		%LoadRunButton.get_parent().add_child(button)
		_leave_buttons.append(button)
	%EventButton.pressed.connect(_route.bind(&"events"))
	%RiskButton.pressed.connect(_route.bind(&"risk"))
	%NightButton.pressed.connect(_route.bind(&"night"))
	_confirmation = ConfirmationDialog.new()
	_confirmation.theme = CounterTheme.build()
	_confirmation.title = "确认操作"
	_confirmation.ok_button_text = "确认"
	_confirmation.cancel_button_text = "取消"
	_confirmation.confirmed.connect(_accept_confirmation)
	add_child(_confirmation)


func render(model: Dictionary) -> void:
	_manual_storage = model.get("manual_storage", false)
	_save_button.visible = _manual_storage
	_save_button.disabled = not model.get("save_reason", "").is_empty()
	_save_button.tooltip_text = model.get("save_reason", "")
	for button in _leave_buttons: button.visible = _manual_storage
	%EventButton.visible = not model.get("in_room", false)
	%NightButton.visible = not model.get("in_room", false)
	%LoadRunButton.text = "读取存档" if model.get("room_flow", false) else "读取夜末存档"
	%LoadRunButton.disabled = not bool(model.get("has_save", false))
	%LoadRunButton.tooltip_text = "尚无可读取的存档。" if %LoadRunButton.disabled else "读取最近一次保存的进度。"


func open_menu() -> void:
	show()
	%NewRunButton.grab_focus()


func close_menu() -> void:
	hide()


func show_load_error(message: String) -> void:
	if _error_dialog == null:
		_error_dialog = AcceptDialog.new()
		_error_dialog.title = "读取失败"
		_error_dialog.ok_button_text = "知道了"
		add_child(_error_dialog)
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered(Vector2i(460, 170))


func _route(panel_id: StringName) -> void:
	hide()
	panel_requested.emit(panel_id)


func _confirm(intent: String) -> void:
	_pending_intent = intent
	_confirmation.title = "开始新游戏" if intent == "new" else "读取存档"
	_confirmation.dialog_text = "将放弃当前未保存的夜内进度。是否继续？"
	_confirmation.popup_centered()


func _accept_confirmation() -> void:
	hide()
	if _pending_intent == "new":
		new_requested.emit()
	else:
		load_requested.emit()
