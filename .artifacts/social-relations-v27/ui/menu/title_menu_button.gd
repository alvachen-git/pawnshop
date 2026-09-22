class_name TitleMenuButton
extends Button

signal atmosphere_changed

const PLAQUE := preload("res://assets/main_menu/button-plaque.png")
const PLAQUE_SHADER := """
shader_type canvas_item;
uniform float hover_amount = 0.0;
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 tinted = base.rgb * vec3(0.725, 0.341, 0.271) * 1.85;
    float gray = dot(tinted, vec3(0.2126, 0.7152, 0.0722));
    tinted = mix(vec3(gray), tinted, 0.75);
    COLOR = vec4(mix(base.rgb * 0.96, tinted, hover_amount), base.a);
}
"""

var motion_enabled := true
var hover_amount := 0.0
var _pointer_inside := false
var _keyboard_mode := false
var _phase := 0.0
var _plaque: TextureRect
var _ink: Label
var _material: ShaderMaterial


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("d8c7a2")
	focus.set_border_width_all(2)
	add_theme_stylebox_override("focus", focus)
	add_theme_color_override("font_color", Color("d8c7a2"))
	add_theme_color_override("font_hover_color", Color("f1dfbb"))
	add_theme_color_override("font_focus_color", Color("f1dfbb"))
	add_theme_color_override("font_pressed_color", Color("f1dfbb"))
	add_theme_color_override("font_disabled_color", Color("817566"))
	var texture := AtlasTexture.new()
	texture.atlas = PLAQUE
	texture.region = Rect2(23, 229, 1800, 337)
	_plaque = TextureRect.new()
	_plaque.name = "Plaque"
	_plaque.texture = texture
	_plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.show_behind_parent = true
	var shader := Shader.new()
	shader.code = PLAQUE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_plaque.material = _material
	add_child(_plaque)
	_plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink = Label.new()
	_ink.name = "InkEcho"
	_ink.text = text
	_ink.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.show_behind_parent = true
	_ink.add_theme_font_override("font", get_theme_font("font"))
	_ink.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	_ink.add_theme_color_override("font_color", Color("925347"))
	add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.modulate.a = 0.0
	mouse_entered.connect(func() -> void: _pointer_inside = true)
	mouse_exited.connect(func() -> void: _pointer_inside = false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey: _keyboard_mode = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_keyboard_mode = false
		# Mouse clicks must not leave a keyboard-selected red plaque behind.
		if event is InputEventMouseMotion and has_focus(): release_focus()


func is_engaged() -> bool:
	return not disabled and (_pointer_inside or (_keyboard_mode and has_focus()))


func _process(delta: float) -> void:
	var target := 1.0 if is_engaged() else 0.0
	var previous := hover_amount
	hover_amount = move_toward(hover_amount, target, delta / (0.65 if target > hover_amount else 0.8)) if motion_enabled else target
	_phase += delta if target > 0.0 else 0.0
	_material.set_shader_parameter("hover_amount", hover_amount)
	_plaque.modulate.a = 0.48 if disabled else 1.0
	if motion_enabled:
		_plaque.position = Vector2(2, -2) * hover_amount if not button_pressed else Vector2(1, 1)
		_ink.position = Vector2(3.0 * sin(_phase * 2.7), sin(_phase * 3.1))
		_ink.modulate.a = hover_amount * (0.15 + 0.25 * (sin(_phase * 2.7) + 1.0) / 2.0)
	else:
		_plaque.position = Vector2.ZERO
		_ink.modulate.a = 0.0
	if not is_equal_approx(previous, hover_amount): atmosphere_changed.emit()


func clear_interaction() -> void:
	_pointer_inside = false
	_keyboard_mode = false
	release_focus()
