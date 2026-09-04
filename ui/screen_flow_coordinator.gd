class_name ScreenFlowCoordinator
extends Node

signal active_panel_changed(panel_id: StringName)

var _panels: Dictionary = {}
var _active_panel_id: StringName


func register_panel(panel: FeaturePanel) -> void:
	if panel == null or panel.get_panel_id().is_empty():
		push_error("无法注册没有panel_id的FeaturePanel。")
		return
	_panels[panel.get_panel_id()] = panel


func show_panel(panel_id: StringName) -> void:
	if not _panels.has(panel_id):
		push_warning("未注册的Panel：%s" % panel_id)
		return
	for registered_id in _panels:
		_panels[registered_id].visible = registered_id == panel_id
	_active_panel_id = panel_id
	active_panel_changed.emit(panel_id)


func get_active_panel_id() -> StringName:
	return _active_panel_id

