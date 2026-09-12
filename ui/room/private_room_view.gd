class_name PrivateRoomView
extends Control

signal command_requested(command: String)
signal menu_requested

const ART_SIZE := Vector2(1672, 941)
var _bed: Button
var _lamp: Button
var _desk: Button
var _photo: Button
var _menu: Button
var _body: Label
var _heading: Label
var _night: Label
var _confirm: ConfirmationDialog
var _letter: AcceptDialog
var _keepsakes: KeepsakesPanel
var _keepsake_source: Button
var _observation: PanelContainer
var _close_observation: Button
var _background: TextureRect
var _state_material: ShaderMaterial
var _model: Dictionary = {}
var _placements: Dictionary = {}
var _props: Array[Button] = []
var _inspect_source: Button
var _prop_hint: Label
var _hint_source: Button
var _mirror: BedroomMirror
var _sleep_prompt := false
var _transition_error: AcceptDialog

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background = TextureRect.new()
	_background.texture = preload("res://assets/bedroom/room-normal.png")
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_material = ShaderMaterial.new()
	_state_material.shader = preload("res://assets/bedroom/room_state.gdshader")
	_state_material.set_shader_parameter("rest_texture", preload("res://assets/bedroom/room-rest.png"))
	_state_material.set_shader_parameter("shell_texture", preload("res://assets/bedroom/room-shell.png"))
	_background.material = _state_material
	add_child(_background)
	_heading = Label.new()
	_heading.text = "楼上 · 寝屋"
	_heading.add_theme_font_override("font", CounterTheme.display_font())
	_heading.add_theme_color_override("font_color", Color("eed7a2"))
	_heading.add_theme_color_override("font_shadow_color", Color("100c08"))
	_heading.add_theme_constant_override("shadow_offset_y", 2)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	_place(_heading, Rect2(34, 31, 450, 60))
	_night = Label.new()
	_night.add_theme_color_override("font_color", Color("c9b28a"))
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_night)
	_place(_night, Rect2(37, 93, 220, 28))
	var wardrobe := _hotspot("RoomWardrobe", "衣柜", Rect2(32, 215, 119, 580))
	wardrobe.pressed.connect(func() -> void: _observe("旧衣挤在柜里，带着木头和皂角的气味。", wardrobe))
	_lamp = _hotspot("RoomLamp", "命灯", Rect2(184, 306, 72, 150))
	_lamp.pressed.connect(func() -> void: _observe(_model.lamp, _lamp))
	_desk = _hotspot("RoomDesk", "书桌 · 旧信", Rect2(245, 448, 190, 48))
	_desk.pressed.connect(_read_letter)
	_photo = _hotspot("RoomPhoto", "姚曼卿的照片", Rect2(262, 362, 73, 83))
	_photo.pressed.connect(_read_photo)
	_mirror = preload("res://ui/room/bedroom_mirror.tscn").instantiate() as BedroomMirror
	_mirror.name = "RoomMirror"
	add_child(_mirror)
	_place(_mirror, Rect2(1031, 71, 217, 305))
	_style_hotspot(_mirror.hit_target)
	_mirror.hit_target.pressed.connect(func() -> void: _observe(_mirror.observation_text(), _mirror.hit_target))
	_bed = _action("RoomBed", "就寝", Rect2(708, 776, 166, 55))
	_bed.pressed.connect(_bed_pressed)
	_menu = _action("RoomMenu", "菜单", Rect2(1500, 816, 138, 54))
	_menu.pressed.connect(func() -> void: dismiss_observation(); menu_requested.emit())
	_prop_hint = Label.new()
	_prop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prop_hint.add_theme_color_override("font_color", Color("f4dfb1"))
	_prop_hint.add_theme_color_override("font_outline_color", Color("1b140b"))
	_prop_hint.add_theme_constant_override("outline_size", 6)
	add_child(_prop_hint)
	_prop_hint.hide()
	_create_observation()
	_keepsakes = KeepsakesPanel.new()
	_keepsakes.name = "Keepsakes"
	add_child(_keepsakes)
	_keepsakes.photo_requested.connect(func(command: String) -> void: command_requested.emit(command))
	_keepsakes.dismissed.connect(_restore_keepsake_focus)
	resized.connect(_layout)
	_layout()

func _create_observation() -> void:
	_observation = PanelContainer.new()
	_observation.name = "Observation"
	_observation.add_theme_stylebox_override("panel", CounterTheme.box("19140eec", "8b7553", 24, 20))
	add_child(_observation)
	_place(_observation, Rect2(520, 128, 500, 310))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_observation.add_child(column)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Color("e7d8ba"))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	_close_observation = Button.new()
	_close_observation.text = "收回目光"
	_close_observation.size_flags_horizontal = Control.SIZE_SHRINK_END
	style_action(_close_observation)
	column.add_child(_close_observation)
	_close_observation.pressed.connect(_observation_pressed)
	_observation.hide()

func _observe(text: String, source: Button) -> void:
	close_private_panels()
	_sleep_prompt = false
	_close_observation.text = "收回目光"
	_close_observation.disabled = false
	_body.text = text
	_inspect_source = source
	_observation.show()

func _observation_pressed() -> void:
	if _sleep_prompt:
		if _model.get("can_finish", false): command_requested.emit("relax_sleep")
	else:
		dismiss_observation()

func show_transition_error(message: String) -> void:
	if _transition_error == null:
		_transition_error = AcceptDialog.new()
		_transition_error.title = "未能进入下一天"
		_transition_error.ok_button_text = "知道了"
		add_child(_transition_error)
	_transition_error.dialog_text = message
	_transition_error.popup_centered(Vector2i(440, 180))

func dismiss_observation() -> bool:
	if _keepsakes != null and _keepsakes.visible:
		_keepsakes.go_back()
		return true
	if not _observation.visible: return false
	_observation.hide()
	if is_instance_valid(_inspect_source) and not _inspect_source.disabled:
		_inspect_source.grab_focus()
	return true

func _hotspot(node_name: String, caption: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	_style_hotspot(button)
	add_child(button)
	_place(button, bounds)
	return button

func _style_hotspot(button: Button) -> void:
	button.clip_text = true
	for state in ["normal", "pressed", "disabled", "hover"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	var edge := CounterTheme.box("c9a4660b", "cdb28288", 0, 0)
	button.add_theme_stylebox_override("hover", edge)
	button.add_theme_stylebox_override("focus", edge)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_show_prop_hint.bind(button))
	button.focus_entered.connect(_show_prop_hint.bind(button))
	button.mouse_exited.connect(_hide_prop_hint.bind(button))
	button.focus_exited.connect(_hide_prop_hint.bind(button))
	_props.append(button)

func _show_prop_hint(button: Button) -> void:
	if button.disabled: return
	_hint_source = button
	_prop_hint.text = button.text
	_prop_hint.size = Vector2(maxf(180, button.size.x), 30)
	var local_position := button.global_position - global_position
	_prop_hint.position = Vector2(maxf(8, local_position.x + (button.size.x - _prop_hint.size.x) * 0.5), local_position.y - 34)
	_prop_hint.show()

func _hide_prop_hint(button: Button) -> void:
	if _hint_source == button:
		_prop_hint.hide()

func _action(node_name: String, caption: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_action(button)
	add_child(button)
	_place(button, bounds)
	return button

static func style_action(button: Button) -> void:
	button.add_theme_font_override("font", CounterTheme.display_font())
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: String = {"normal": "20180fb8", "hover": "493725e8", "pressed": "140f09ed", "disabled": "20180f88"}[state]
		button.add_theme_stylebox_override(state, CounterTheme.box(fill, "c4a879" if state != "disabled" else "706049", 10, 4))
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color("edd6a4") if state != "disabled" else Color("9c8b70"))
	button.add_theme_color_override("font_focus_color", Color("f6e4bc"))
	button.add_theme_stylebox_override("focus", CounterTheme.box("00000000", "e9c993", 0, 0))

func _place(control: Control, bounds: Rect2) -> void:
	_placements[control] = bounds

func _layout() -> void:
	if not is_instance_valid(_background): return
	var scale_factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var origin := (size - ART_SIZE * scale_factor) * 0.5
	_background.position = origin
	_background.size = ART_SIZE * scale_factor
	for control: Control in _placements:
		var bounds: Rect2 = _placements[control]
		control.position = origin + bounds.position * scale_factor
		control.size = bounds.size * scale_factor
	_heading.add_theme_font_size_override("font_size", roundi(40 * scale_factor))
	_night.add_theme_font_size_override("font_size", maxi(14, roundi(18 * scale_factor)))
	_prop_hint.add_theme_font_size_override("font_size", maxi(18, roundi(23 * scale_factor)))
	_body.add_theme_font_size_override("font_size", maxi(17, roundi(21 * scale_factor)))
	for button in [_bed, _menu, _close_observation]:
		button.add_theme_font_size_override("font_size", maxi(18, roundi(24 * scale_factor)))
	queue_redraw()

func render(model: Dictionary) -> void:
	var phase_changed: bool = _model.get("phase", "") != model.phase
	var finish_ready: bool = model.can_finish and not _model.get("can_finish", false)
	_model = model
	visible = model.visible
	if _keepsakes != null:
		if phase_changed or not visible: close_private_panels()
		_keepsakes.update_model(model.get("keepsakes", {"available": false}), model.error)
	if not visible and _confirm != null: _confirm.hide()
	_night.text = "第%d夜" % model.night
	if phase_changed or finish_ready or not model.error.is_empty():
		_body.text = model.body + ("\n\n" + model.error if not model.error.is_empty() else "")
		_sleep_prompt = model.phase == "sleep_resolution" and not model.dead
		_close_observation.text = "放松入眠" if _sleep_prompt else "收回目光"
		_observation.visible = visible and not model.pending and (model.dead or model.phase == "sleep_resolution" or not model.error.is_empty())
	_close_observation.disabled = _sleep_prompt and not model.can_finish
	if _keepsakes != null and _keepsakes.visible: _observation.hide()
	_bed.text = "就寝" if model.phase == "private_room" else "等到天明"
	_bed.accessibility_name = "床 · 就寝" if model.phase == "private_room" else "等到天明"
	if model.dead:
		_bed.text = "灯已熄"
		_bed.accessibility_name = "灯已熄"
	_bed.disabled = not model.can_sleep and not model.can_finish
	for prop in _props: prop.disabled = model.pending or model.dead
	if model.get("keepsakes", {}).get("enabled", false):
		_desk.disabled = not model.keepsakes.available
		_photo.disabled = not model.keepsakes.available
		_desk.text = "书桌 · 私人信件与物件"
	if model.pending or model.dead: _prop_hint.hide()
	_photo.visible = model.get("photo_placed", false)
	_state_material.set_shader_parameter("photo_placed", model.get("photo_placed", false))
	_state_material.set_shader_parameter("lamp_dead", model.dead)
	_state_material.set_shader_parameter("haunting", model.haunting)
	_state_material.set_shader_parameter("lamp_grade", int(model.get("lamp_grade", 0)))
	var lamp_state: Dictionary = model.get("lamp_state", {})
	_state_material.set_shader_parameter("personal_damage", int(lamp_state.get("damage", -1)))
	_state_material.set_shader_parameter("lamp_light", float(lamp_state.get("light", 0.0 if model.dead else 1.0)))
	var mirror_state: Dictionary = model.get("mirror", {}).duplicate()
	mirror_state["lamp_lit"] = not model.dead
	mirror_state["lamp_light"] = float(lamp_state.get("light", 0.0 if model.dead else 1.0))
	if model.dead: mirror_state["mode"] = &"normal"
	_mirror.set_state(mirror_state)
	if not visible:
		_mirror.reset()
		_observation.hide()
		if _letter != null: _letter.hide()

func _read_letter() -> void:
	if _model.get("keepsakes", {}).get("enabled", false):
		_open_keepsakes(false)
		return
	if not _model.get("gu_letter", false):
		_observe("抽屉里还没有收好的信。", _desk)
		return
	dismiss_observation()
	if _letter == null:
		_letter = AcceptDialog.new()
		_letter.title = "顾敬堂的信"
		_letter.ok_button_text = "放回抽屉"
		var text := RichTextLabel.new()
		text.custom_minimum_size = Vector2(530, 400)
		text.add_theme_font_size_override("normal_font_size", 20)
		text.add_theme_color_override("default_color", Color("302a24"))
		text.text = tr("opening.letter.permanent")
		_letter.add_child(text)
		add_child(_letter)
	_letter.popup_centered(Vector2i(570, 490))

func _read_photo() -> void:
	if _model.get("keepsakes", {}).get("enabled", false): _open_keepsakes(true)
	else: _observe(tr("opening.room.photo"), _photo)

func _open_keepsakes(photo: bool) -> void:
	if not _model.keepsakes.available: return
	_observation.hide()
	if _letter != null: _letter.hide()
	if _confirm != null: _confirm.hide()
	_prop_hint.hide()
	_keepsake_source = _photo if photo else _desk
	_keepsakes.present(_model.keepsakes, photo)

func close_private_panels() -> void:
	if _keepsakes != null and _keepsakes.visible: _keepsakes.dismiss()
	if _letter != null: _letter.hide()

func _restore_keepsake_focus() -> void:
	if not visible: return
	var target := _keepsake_source
	if not is_instance_valid(target) or not target.visible or target.disabled: target = _desk
	if target.visible and not target.disabled: target.grab_focus()

func _create_confirmation() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "就寝"
	_confirm.dialog_text = "准备就寝，结束今天的活动？"
	_confirm.ok_button_text = "就寝"
	_confirm.cancel_button_text = "再坐一会儿"
	_confirm.confirmed.connect(func() -> void: command_requested.emit("sleep"))
	add_child(_confirm)

func _bed_pressed() -> void:
	close_private_panels()
	dismiss_observation()
	if _model.can_sleep:
		if _confirm == null: _create_confirmation()
		_confirm.popup_centered(Vector2i(380, 160))
	elif _model.can_finish: command_requested.emit("finish_sleep")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("100e0a"))
