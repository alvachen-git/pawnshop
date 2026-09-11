@tool
class_name CounterStage
extends Control

# ART04: approved gouache room. Legacy neutral stand-ins remain for unmapped content.
# All atmosphere changes share the same texture, camera and interaction zones.
@export_enum("正常营业", "深夜异常", "禁时鬼市") var atmosphere := 0:
	set(value):
		atmosphere = value
		queue_redraw()
var night_band := -1
var has_customer := false
var has_item := false
var smoke_wrong := false
var lamp_wrong := false
var lamp_dead := false
var show_life_lamp := true
var _paint: TextureRect
var _paint_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_paint = TextureRect.new()
	_paint.name = "PaintedRoom"
	_paint.texture = preload("res://assets/art04/counter_room.png")
	_paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paint.stretch_mode = TextureRect.STRETCH_SCALE
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.show_behind_parent = true
	add_child(_paint)
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Background is a complete 16:9 painting. The status strip covers its foot.
	_paint.anchor_bottom = 1.0 / 0.9
	_paint_material = ShaderMaterial.new()
	_paint_material.shader = preload("res://ui/art/counter_room.gdshader")
	_paint.material = _paint_material
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	if _paint_material != null:
		_paint_material.set_shader_parameter("atmosphere", atmosphere)
		_paint_material.set_shader_parameter("night_band", night_band)
		_paint_material.set_shader_parameter("lamp_wrong", lamp_wrong and show_life_lamp)
		_paint_material.set_shader_parameter("lamp_dead", lamp_dead and show_life_lamp)
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 648))
	# Smoke is a quiet rule-feedback stroke, never baked into the painted room.
	var smoke := PackedVector2Array([Vector2(105, 414), Vector2(108, 398), Vector2(102, 380), Vector2(105, 362)])
	if smoke_wrong:
		smoke = PackedVector2Array([Vector2(105, 414), Vector2(122, 409), Vector2(145, 410), Vector2(161, 407)])
	draw_polyline(smoke, Color(0.72, 0.74, 0.69, 0.5), 1.25, true)
	if has_customer:
		draw_set_transform(Vector2(56, -34), 0, Vector2(1.0, 1.10) * size / Vector2(1280, 648))
		_customer()
	if has_item:
		draw_set_transform(Vector2(100, -45), 0, size / Vector2(1280, 648))
		_parcel()

func _customer() -> void:
	# Neutral half-body stand-in, no invented character identity or facial horror.
	var coat := Color("4b4940" if atmosphere == 0 else "394444")
	var skin := Color("a99c7d" if atmosphere == 0 else "7e8a80")
	draw_colored_polygon(PackedVector2Array([Vector2(493, 344), Vector2(510, 251), Vector2(567, 222), Vector2(647, 222), Vector2(702, 250), Vector2(725, 344)]), coat)
	_rect(585, 197, 43, 51, skin.to_html())
	draw_circle(Vector2(607, 171), 46, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(563, 164), Vector2(563, 135), Vector2(588, 117), Vector2(624, 118), Vector2(651, 141), Vector2(651, 164), Vector2(624, 151), Vector2(587, 151)]), Color("302e29"))
	_line(Vector2(576, 174), Vector2(591, 175), "5e5849", 2)
	_line(Vector2(622, 175), Vector2(637, 174), "5e5849", 2)
	_line(Vector2(607, 179), Vector2(603, 196), "80745d", 2)
	_line(Vector2(595, 210), Vector2(620, 209), "685c4e", 2)
	_line(Vector2(584, 233), Vector2(611, 253), "9d9477", 2)
	_line(Vector2(633, 233), Vector2(611, 253), "9d9477", 2)
	_line(Vector2(612, 255), Vector2(612, 340), "8b8169", 2)
	for y in [268, 291, 314]: _line(Vector2(610, y), Vector2(628, y), "a69a7b", 3)
	_line(Vector2(534, 272), Vector2(551, 328), "686454", 2)
	_line(Vector2(682, 274), Vector2(664, 328), "686454", 2)

func _parcel() -> void:
	_rect(428, 443, 152, 76, "363930")
	draw_colored_polygon(PackedVector2Array([Vector2(430, 438), Vector2(552, 427), Vector2(578, 460), Vector2(462, 476)]), Color("b6a483"))
	draw_colored_polygon(PackedVector2Array([Vector2(430, 438), Vector2(462, 476), Vector2(462, 520), Vector2(430, 484)]), Color("897959"))
	draw_colored_polygon(PackedVector2Array([Vector2(462, 476), Vector2(578, 460), Vector2(578, 503), Vector2(462, 520)]), Color("9a8b6a"))
	_line(Vector2(493, 433), Vector2(519, 468), "4f4837", 3)
	_line(Vector2(519, 468), Vector2(519, 511), "4f4837", 3)
	_line(Vector2(445, 457), Vector2(566, 445), "665a43", 2)

func _rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _line(a: Vector2, b: Vector2, color: String, width := 1.0) -> void:
	draw_line(a, b, Color(color), width, true)

func _outline(rect: Rect2, color: String) -> void:
	draw_rect(rect, Color(color), false, 1)
