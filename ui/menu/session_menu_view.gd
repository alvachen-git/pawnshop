class_name SessionMenuView
extends PanelContainer

signal new_requested
signal load_requested
signal panel_requested(panel_id: StringName)

var _confirmation: ConfirmationDialog
var _pending_intent := ""


func _ready() -> void:
	%NewRunButton.pressed.connect(_confirm.bind("new"))
	%LoadRunButton.pressed.connect(_confirm.bind("load"))
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
	%LoadRunButton.disabled = not bool(model.get("has_save", false))
	%LoadRunButton.tooltip_text = "尚无可读取的夜末存档。" if %LoadRunButton.disabled else "读取最近的夜末存档。"


func open_menu() -> void:
	show()
	%NewRunButton.grab_focus()


func close_menu() -> void:
	hide()


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
