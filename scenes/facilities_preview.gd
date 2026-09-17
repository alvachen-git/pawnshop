extends Control

var room: FacilitiesRoomView

func _ready() -> void:
	theme = CounterTheme.build()
	room = FacilitiesRoomView.new()
	add_child(room)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.anchor_bottom = 0.9
	room.add_preview_controls()
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	add_child(footer)
	FacilitiesRoomView.bounds(footer, Rect2(0, 0.9, 1, 0.1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	footer.add_child(row)
	var note := Label.new()
	note.text = "  设施外观预览 · 点击物件查看设计 · 不读取或写入经营存档"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(note)
	var exit_button := Button.new()
	exit_button.text = "关闭预览"
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	CounterTheme.style_paper_button(exit_button)
	row.add_child(exit_button)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--facility-level="): room.set_preview(int(argument.trim_prefix("--facility-level=")))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and room.sheet.visible:
		room.close_sheet()
		get_viewport().set_input_as_handled()
