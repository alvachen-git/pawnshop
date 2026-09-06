class_name TitleMenuView
extends Control

signal new_requested
signal load_requested
signal exit_requested

const DESIGN_SIZE := Vector2(1672, 941)
const BACKGROUND := preload("res://assets/main_menu/menu-background.png")
const LIGHT_SHADER := """
shader_type canvas_item;
uniform float dim_amount = 0.0;
void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float door = smoothstep(0.51, 0.55, UV.x) * (1.0-smoothstep(0.62,0.67,UV.x));
    door *= smoothstep(0.1,0.2,UV.y) * (1.0-smoothstep(0.72,0.83,UV.y));
    COLOR = vec4(color.rgb * (1.0 - door * dim_amount * 0.23), color.a);
}
"""

var buttons: Array[TitleMenuButton] = []
var confirmation: ConfirmationDialog
var error_dialog: AcceptDialog
var _stage: Control
var _light: ShaderMaterial
var _active_age := 0.0
var _dim_amount := 0.0
var _has_save := false
var _motion := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = CounterTheme.build()
	_motion = not bool(ProjectSettings.get_setting("gui/accessibility/reduce_motion", false))
	var backdrop := ColorRect.new()
	backdrop.color = Color("090908")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = DESIGN_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var art := TextureRect.new()
	art.name = "Doorway"
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = DESIGN_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = LIGHT_SHADER
	_light = ShaderMaterial.new()
	_light.shader = shader
	art.material = _light
	_stage.add_child(art)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "Songti SC", "Noto Serif SC"])
	font.fallbacks = [preload("res://assets/fonts/NotoSansSC.ttf")]
	var labels := ["开启新游戏", "读取游戏", "离开游戏"]
	for index in 3:
		var button := TitleMenuButton.new()
		button.name = ["NewGame", "LoadGame", "ExitGame"][index]
		button.text = labels[index]
		button.position = Vector2(67.7, 512.84 + index * 118.42)
		button.size = Vector2(531.69, 99.53)
		button.motion_enabled = _motion
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 48 if index == 0 else 43)
		_stage.add_child(button)
		buttons.append(button)
	buttons[0].pressed.connect(_request_new)
	buttons[1].pressed.connect(func() -> void: load_requested.emit())
	buttons[2].pressed.connect(func() -> void: exit_requested.emit())
	for index in 3:
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[(index + 2) % 3])
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(buttons[(index + 1) % 3])
	confirmation = ConfirmationDialog.new()
	confirmation.title = "开启新游戏"
	confirmation.dialog_text = "开始新游戏后，后续保存将替换现有进度。是否继续？"
	confirmation.ok_button_text = "开启新游戏"
	confirmation.cancel_button_text = "返回"
	confirmation.confirmed.connect(func() -> void: new_requested.emit())
	add_child(confirmation)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "读取失败"
	error_dialog.ok_button_text = "返回"
	add_child(error_dialog)
	resized.connect(_layout)
	_layout()


func configure(ready_to_play: bool, has_save: bool) -> void:
	_has_save = has_save
	buttons[0].disabled = not ready_to_play
	buttons[1].disabled = not ready_to_play or not has_save
	buttons[1].tooltip_text = "读取最近保存的进度。" if has_save else "尚无可读取的游戏进度。"
	if not ready_to_play: show_error("游戏内容载入失败，请检查文件是否完整。", "无法开铺")


func show_error(message: String, title := "读取失败") -> void:
	for button in buttons: button.clear_interaction()
	error_dialog.title = title
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(510, 180))


func _request_new() -> void:
	if _has_save:
		for button in buttons: button.clear_interaction()
		confirmation.popup_centered(Vector2i(510, 180))
	else: new_requested.emit()


func _layout() -> void:
	if _stage == null: return
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_stage.scale = Vector2.ONE * ratio
	_stage.position = (size - DESIGN_SIZE * ratio) / 2.0


func _process(delta: float) -> void:
	var engaged := false
	for button in buttons: engaged = engaged or button.is_engaged()
	_active_age = _active_age + delta if engaged else 0.0
	var target := 1.0 if engaged and _active_age >= 0.34 and _motion else 0.0
	_dim_amount = move_toward(_dim_amount, target, delta / (0.78 if target > _dim_amount else 1.1))
	_light.set_shader_parameter("dim_amount", _dim_amount)


func _unhandled_key_input(event: InputEvent) -> void:
	if confirmation.visible or error_dialog.visible or not event.is_pressed(): return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		for button in buttons: button.clear_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode in [KEY_HOME, KEY_END]:
		buttons[0 if event.keycode == KEY_HOME else 2].grab_focus()
		get_viewport().set_input_as_handled()
