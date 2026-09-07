class_name SaveLibraryView
extends CanvasLayer

signal loaded
signal leave_confirmed(destination: String)
var session: RunSession
var library: SaveLibrary
var overlay: Control
var list: VBoxContainer
var status: Label
var heading: Label
var filter: OptionButton
var confirm: ConfirmationDialog
var error_dialog: AcceptDialog
var leave_dialog: ConfirmationDialog
var mode := "load"
var pending_key := ""
var destination := ""
var _return_focus: Control

func bind(value: RunSession) -> void:
	session = value
	library = session._save.library
	layer = 80
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.theme = CounterTheme.build()
	add_child(host)
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color("171713dd")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.anchor_left = 0.12
	paper.anchor_right = 0.88
	paper.anchor_top = 0.055
	paper.anchor_bottom = 0.945
	paper.add_theme_stylebox_override("panel", CounterTheme.box("d8c8a0", "8b7955", 20, 20))
	overlay.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	paper.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heading)
	_button(bar, "关闭 · Esc", close)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_button(actions, "保存游戏", func() -> void: mode = "save"; refresh())
	_button(actions, "读取游戏", func() -> void: mode = "load"; refresh())
	filter = OptionButton.new()
	filter.add_item("全部局类型")
	for id in SaveLibrary.NAMES:
		filter.add_item(SaveLibrary.NAMES[id])
		filter.set_item_metadata(filter.item_count - 1, id)
	filter.item_selected.connect(func(_index: int) -> void: refresh())
	actions.add_child(filter)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	confirm = ConfirmationDialog.new()
	confirm.ok_button_text = "确认"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(_commit)
	confirm.canceled.connect(func() -> void: pending_key = "")
	host.add_child(confirm)
	error_dialog = AcceptDialog.new()
	error_dialog.ok_button_text = "知道了"
	host.add_child(error_dialog)
	leave_dialog = ConfirmationDialog.new()
	leave_dialog.ok_button_text = "直接离开"
	leave_dialog.cancel_button_text = "取消"
	leave_dialog.add_button("保存后离开", false, "save")
	leave_dialog.confirmed.connect(func() -> void: leave_confirmed.emit(destination))
	leave_dialog.canceled.connect(func() -> void: destination = "")
	leave_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"save": leave_dialog.hide(); open("save", true)
	)
	host.add_child(leave_dialog)
	session.storage_requested.connect(open)
	session.leave_requested.connect(request_leave)
	session.changed.connect(func() -> void:
		if overlay.visible: refresh()
	)
	overlay.hide()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open(requested_mode := "load", keep_destination := false) -> void:
	if not keep_destination: destination = ""
	_return_focus = get_viewport().gui_get_focus_owner()
	mode = "load" if requested_mode == "manage" else requested_mode
	overlay.show()
	refresh()
	filter.grab_focus()

func close() -> void:
	overlay.hide()
	destination = ""
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree(): _return_focus.grab_focus()

func refresh() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	heading.text = "保存游戏" if mode == "save" else "读取游戏"
	var reason := SaveLibrary.save_reason(session._day.state)
	status.text = reason if mode == "save" and not reason.is_empty() else "手动存档共6位；自动存档独立保留。\n最近位置：" + library.last_label
	var rows := library.entries()
	if rows.is_empty() and not library.error_message.is_empty(): status.text = library.error_message
	for row in rows:
		if mode == "save" and not row.key.begins_with("manual/"): continue
		if filter.selected > 0 and not row.empty and row.run_id != filter.get_item_metadata(filter.selected): continue
		var button := _button(list, row.label + "\n" + row.detail, _select.bind(row))
		button.name = String(row.key).replace("/", "_")
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not reason.is_empty() if mode == "save" else not row.valid
		button.tooltip_text = reason if mode == "save" else row.detail
	_trap_focus()

func _trap_focus() -> void:
	var controls: Array[Control] = []
	var pending: Array[Node] = [overlay]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		for child in node.get_children(): pending.append(child)
		if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not (node is BaseButton and node.disabled): controls.append(node)
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])

func _select(row: Dictionary) -> void:
	pending_key = row.key
	if mode == "save" and row.empty: _commit(); return
	confirm.title = "覆盖存档" if mode == "save" else "读取存档"
	confirm.dialog_text = ("将覆盖以下存档：\n" if mode == "save" else "将放弃当前进度并读取：\n") + row.label + "\n" + row.detail
	confirm.popup_centered(Vector2i(520, 260))

func _commit() -> void:
	if pending_key.is_empty() or library.busy: return
	var key := pending_key
	pending_key = ""
	if mode == "save":
		if not library.write_entry(key, session._day.state, session.definition, session.content_version, session._counter.catalog): _error(library.error_message); return
		refresh()
		status.text = "保存成功：" + library.last_label
		if not destination.is_empty(): leave_confirmed.emit(destination)
	else:
		var restored := library.read_entry(key)
		if restored.is_empty() or not library.adopt(restored, session): _error(library.error_message); return
		close()
		loaded.emit()

func _error(message: String) -> void:
	error_dialog.title = "保存失败" if mode == "save" else "读取失败"
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(520, 220))

func request_leave(target: String) -> void:
	destination = target
	if not library.dirty(session._day.state): leave_confirmed.emit(target); return
	var reason := SaveLibrary.save_reason(session._day.state)
	leave_dialog.title = "返回主菜单" if target == "title" else "退出游戏"
	leave_dialog.dialog_text = "当前有未保存进度。最近位置：%s。\n%s" % [library.last_label, "营业期间不能保存，直接离开会失去最近保存之后的进度。" if not reason.is_empty() else "是否保存后离开？"]
	# The one custom action is alongside the standard OK and Cancel buttons.
	for button in leave_dialog.get_ok_button().get_parent().get_children():
		if button is Button and button.text == "保存后离开": button.visible = reason.is_empty()
	leave_dialog.popup_centered(Vector2i(580, 240))

func _input(event: InputEvent) -> void:
	if confirm != null and (confirm.visible or leave_dialog.visible or error_dialog.visible): return
	if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
