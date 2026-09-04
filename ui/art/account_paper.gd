class_name AccountPaper
extends RefCounted

static func label(parent: Node, text: String, size: int = 16) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", size)
	parent.add_child(node)
	return node

static func rule(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("a28b65")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)

static func metrics(parent: Node, rows: Array) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	for row in rows:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(column)
		label(column, str(row[0]), 14)
		label(column, str(row[1]), 23)
	return box

static func entry(parent: Node) -> VBoxContainer:
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", CounterTheme.box("e6d6b0", "a28b65", 12, 12))
	parent.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	paper.add_child(column)
	return column

static func stamp(parent: Node, text: String, closed: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color := "716950" if closed else "8d2a24"
	panel.add_theme_stylebox_override("panel", CounterTheme.box("00000000", color, 8, 4))
	parent.add_child(panel)
	var node := label(panel, text, 15)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_color_override("font_color", Color(color))

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func action(parent: Node, entry: Dictionary, callback: Callable) -> Button:
	var button := Button.new()
	button.text = entry.label
	button.disabled = not entry.enabled
	button.tooltip_text = entry.reason
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback.bind(entry.command, entry.target_id, entry.detail))
	parent.add_child(button)
	if not entry.enabled and not entry.reason.is_empty(): label(parent, entry.reason, 14)
	return button
