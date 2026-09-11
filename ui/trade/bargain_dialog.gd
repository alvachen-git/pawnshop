class_name BargainDialog
extends Control

signal dismissed
var paper: PanelContainer
var scroll: ScrollContainer
var close_button: Button
var context: Label
var choices: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CounterTheme.build()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("171611b8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_outside_input)
	add_child(shade)
	paper = PanelContainer.new()
	paper.add_theme_stylebox_override("panel", CounterTheme.box("e5d5b3", "a38b63", 24, 20))
	add_child(paper)
	# Wrapped labels settle after the container receives its width. Refit then,
	# so a transient minimum height cannot leave the sheet outside the viewport.
	paper.minimum_size_changed.connect(func() -> void: _layout.call_deferred())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	paper.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "商量价钱"
	title.add_theme_font_size_override("font_size", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = Button.new()
	close_button.text = "返回交易 · Esc"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(dismiss)
	heading.add_child(close_button)
	context = Label.new()
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_theme_font_size_override("font_size", 16)
	column.add_child(context)
	column.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	hide()
	_layout()

func present(summary: String) -> void:
	context.text = summary
	scroll.scroll_vertical = 0
	show()
	_layout()
	_layout.call_deferred()
	var targets := _focus_targets()
	for index in targets.size():
		var target := targets[index]
		target.focus_neighbor_top = targets[posmod(index - 1, targets.size())].get_path()
		target.focus_neighbor_bottom = targets[(index + 1) % targets.size()].get_path()
		target.focus_neighbor_left = target.get_path()
		target.focus_neighbor_right = target.get_path()
	close_button.grab_focus()

func dismiss() -> void:
	hide()

func _visibility_changed() -> void:
	if not visible: dismissed.emit()

func _layout() -> void:
	if paper == null: return
	paper.size = Vector2(minf(760.0, size.x - 48.0), minf(570.0, size.y - 64.0))
	paper.position = (size - paper.size) / 2.0

func _outside_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		dismiss()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		# Keep keyboard navigation inside the modal, including Shift+Tab.
		var targets := _focus_targets()
		var index := targets.find(get_viewport().gui_get_focus_owner())
		index = posmod(index + (-1 if event.shift_pressed else 1), targets.size())
		targets[index].grab_focus()
		get_viewport().set_input_as_handled()

func _focus_targets() -> Array[Control]:
	var targets: Array[Control] = [close_button]
	if choices != null:
		for child in choices.get_children():
			if child is Button and child.visible and not child.disabled: targets.append(child)
	return targets
