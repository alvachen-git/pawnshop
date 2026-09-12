class_name KeepsakesPanel
extends Control

signal photo_requested(command: String)
signal dismissed

var paper: PanelContainer
var title: Label
var scroll: ScrollContainer
var contents: VBoxContainer
var body: RichTextLabel
var error_label: Label
var primary: Button
var back: Button
var letter_buttons: Array[Button] = []
var photo_button: Button
var page := ""
var _model: Dictionary = {}
var _letter_id := ""
var _photo_from_desk := false
var _list_scroll := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("0b090666")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	paper = PanelContainer.new()
	paper.add_theme_stylebox_override("panel", CounterTheme.box("19140ef8", "8b7553", 28, 24))
	add_child(paper)
	paper.minimum_size_changed.connect(func() -> void: _layout.call_deferred())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	paper.add_child(column)
	title = Label.new()
	title.add_theme_font_override("font", CounterTheme.display_font())
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("eed7a2"))
	column.add_child(title)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	contents = VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 14)
	scroll.add_child(contents)
	body = RichTextLabel.new()
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = true
	body.focus_mode = Control.FOCUS_ALL
	body.add_theme_color_override("default_color", Color("e7d8ba"))
	body.add_theme_font_size_override("normal_font_size", 21)
	body.add_theme_constant_override("line_separation", 8)
	contents.add_child(body)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_font_size_override("font_size", 18)
	error_label.add_theme_color_override("font_color", Color("f0bd97"))
	column.add_child(error_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	primary = _button("")
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(primary)
	primary.pressed.connect(func() -> void:
		primary.disabled = true
		photo_requested.emit("photo_store" if _model.photo_placed else "photo_place"))
	back = _button("合上抽屉")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	back.pressed.connect(go_back)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not visible: dismissed.emit())
	hide()
	_layout()

func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 46
	PrivateRoomView.style_action(button)
	button.add_theme_font_size_override("font_size", 22)
	return button

func present(model: Dictionary, photo := false) -> void:
	_model = model
	_list_scroll = 0
	_photo_from_desk = false
	page = "photo" if photo else "desk"
	show()
	_render_page()

func update_model(model: Dictionary, error := "") -> void:
	_model = model
	if not visible: return
	if not model.available: dismiss(); return
	error_label.text = error
	error_label.visible = not error.is_empty()
	primary.disabled = false

func _clear_choices() -> void:
	for button in letter_buttons:
		contents.remove_child(button)
		button.queue_free()
	letter_buttons.clear()
	if is_instance_valid(photo_button):
		contents.remove_child(photo_button)
		photo_button.queue_free()
		photo_button = null

func _render_page() -> void:
	_clear_choices()
	error_label.hide()
	primary.visible = page == "photo"
	primary.disabled = false
	scroll.scroll_vertical = 0
	if page == "desk":
		title.text = "私人信件"
		body.text = "抽屉里还没有收好的信。" if _model.letters.is_empty() else "信纸沿着旧折痕叠好，收在抽屉一侧。"
		for letter in _model.letters:
			var button := _button(letter.title)
			button.pressed.connect(_open_letter.bind(letter.id))
			contents.add_child(button)
			letter_buttons.append(button)
		if not _model.photo_placed:
			photo_button = _button("私人物件 · 姚曼卿的照片")
			photo_button.pressed.connect(_open_photo)
			contents.add_child(photo_button)
		back.text = "合上抽屉"
	elif page == "photo":
		title.text = "姚曼卿的照片"
		body.text = tr("opening.room.photo")
		primary.text = "收进抽屉" if _model.photo_placed else _model.place_label
		back.text = "放回原处"
	elif page == "letter":
		var found := false
		for letter in _model.letters:
			if letter.id == _letter_id:
				title.text = letter.title
				body.text = tr(letter.body_key)
				found = true
		if not found: page = "desk"; _render_page(); return
		back.text = "放回抽屉"
	_layout()
	_layout.call_deferred()
	_focus_initial.call_deferred()

func _open_letter(id: String) -> void:
	_list_scroll = scroll.scroll_vertical
	_letter_id = id
	page = "letter"
	_render_page()

func _open_photo() -> void:
	_list_scroll = scroll.scroll_vertical
	_photo_from_desk = true
	page = "photo"
	_render_page()

func go_back() -> void:
	if page == "letter" or (page == "photo" and _photo_from_desk):
		page = "desk"
		_render_page()
		_restore_list.call_deferred()
	else: dismiss()

func _restore_list() -> void:
	if page != "desk" or not visible: return
	if _photo_from_desk and is_instance_valid(photo_button): photo_button.grab_focus()
	else:
		for i in _model.letters.size():
			if _model.letters[i].id == _letter_id: letter_buttons[i].grab_focus()
	scroll.set_deferred("scroll_vertical", _list_scroll)

func dismiss() -> void:
	hide()
	page = ""

func _layout() -> void:
	if paper == null: return
	var height := 590.0 if page == "letter" else 340.0 if page == "photo" else 420.0
	paper.size = Vector2(minf(700, size.x - 64), minf(height, size.y - 72))
	paper.position = (size - paper.size) * 0.5

func _focus_targets() -> Array[Control]:
	var targets: Array[Control] = [body]
	for button in letter_buttons: targets.append(button)
	if is_instance_valid(photo_button): targets.append(photo_button)
	if primary.visible and not primary.disabled: targets.append(primary)
	targets.append(back)
	return targets

func _focus_initial() -> void:
	if not visible: return
	var targets := _focus_targets()
	for i in targets.size():
		targets[i].focus_neighbor_top = targets[posmod(i - 1, targets.size())].get_path()
		targets[i].focus_neighbor_bottom = targets[(i + 1) % targets.size()].get_path()
		targets[i].focus_neighbor_left = targets[i].get_path()
		targets[i].focus_neighbor_right = targets[i].get_path()
	back.grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			var targets := _focus_targets()
			var index := targets.find(get_viewport().gui_get_focus_owner())
			targets[posmod(index + (-1 if event.shift_pressed else 1), targets.size())].grab_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_PAGEDOWN, KEY_PAGEUP, KEY_HOME, KEY_END]:
			match event.keycode:
				KEY_PAGEDOWN: scroll.scroll_vertical += int(scroll.size.y * 0.8)
				KEY_PAGEUP: scroll.scroll_vertical -= int(scroll.size.y * 0.8)
				KEY_HOME: scroll.scroll_vertical = 0
				KEY_END: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			get_viewport().set_input_as_handled()
