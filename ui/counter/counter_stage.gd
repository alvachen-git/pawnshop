@tool
class_name CounterStage
extends Control

# Low fidelity, deterministic vector layers. All coordinates share one room.
# Replace individual layers with sprites later; never move the interaction zones.
@export_enum("正常营业", "深夜异常", "禁时鬼市") var atmosphere := 0:
	set(value):
		atmosphere = value
		queue_redraw()
var has_customer := false
var has_item := false
var smoke_wrong := false
var lamp_wrong := false
var lamp_dead := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 590))
	_room()
	if has_customer: _customer()
	_desk()
	_props()
	_print_wear()

func _room() -> void:
	var walls := ["39362e", "292d2c", "293335"]
	var street := ["66685e", "303d40", "52686b"]
	var timber := ["5e4635", "463a30", "473c34"]
	_rect(0, 0, 1280, 590, walls[atmosphere])
	# Door, lintel and Shanghai lane remain fixed between states.
	_rect(323, 28, 634, 324, street[atmosphere])
	for index in 7:
		var x := 340.0 + index * 94
		_rect(x, 80 + index % 3 * 20, 78, 244, "353e3c" if atmosphere == 0 else "263235")
		for window in 3:
			_rect(x + 12, 102 + window * 57, 24, 33, "86816a" if atmosphere == 0 else "536567")
			_line(Vector2(x + 24, 103 + window * 57), Vector2(x + 24, 134 + window * 57), "373b34", 2)
		_line(Vector2(x, 80 + index % 3 * 20), Vector2(x + 85, 74 + index % 3 * 20), "242a27", 7)
	for y in [286, 310, 330]: _line(Vector2(328, y), Vector2(955, y), "797563" if atmosphere == 0 else "5d7375", 1)
	for x in [302, 945]:
		_rect(x, 22, 34, 345, timber[atmosphere])
		_line(Vector2(x + 8, 26), Vector2(x + 8, 345), "977b52", 2)
	_rect(302, 20, 678, 30, "4a392c")
	_line(Vector2(310, 49), Vector2(970, 49), "a58a62", 2)
	# Peripheral cabinets, hardware and paper tickets.
	for side_x in [30, 1000]:
		_rect(side_x, 90, 248, 265, "302b25")
		for row in 3:
			for col in 2:
				var x: float = side_x + 8 + col * 119
				var y := 101.0 + row * 81
				_rect(x, y, 110, 71, timber[atmosphere])
				_outline(Rect2(x + 4, y + 4, 102, 63), "786047")
				_rect(x + 9, y + 12, 30, 20, "ae9b76")
				_line(Vector2(x + 49, y + 43), Vector2(x + 76, y + 43), "b4996a", 3)
	# One quiet hanging sign and two practical street lamps.
	_rect(837, 67, 60, 115, "3a352c")
	_outline(Rect2(843, 73, 48, 103), "8c7957")
	for x in [397, 906]:
		_line(Vector2(x, 49), Vector2(x, 100), "2a2722", 3)
		draw_circle(Vector2(x, 112), 17, Color("ad8a4d" if atmosphere == 0 else ("6c6450" if atmosphere == 1 else "8d2a24")))
		_line(Vector2(x - 11, 95), Vector2(x + 11, 95), "b2996b", 3)
	if atmosphere == 2:
		# One street anomaly: lamps reflected at an impossible height.
		for x in [397, 906]: _rect(x - 3, 223, 6, 72, "996153")

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

func _desk() -> void:
	_rect(0, 342, 1280, 248, "5e4635" if atmosphere == 0 else "483b31")
	_rect(0, 342, 1280, 20, "93714c" if atmosphere == 0 else "705e47")
	_line(Vector2(0, 363), Vector2(1280, 363), "261f1b", 5)
	# Broad appraisal felt, deliberately free of text noise.
	draw_colored_polygon(PackedVector2Array([Vector2(356, 383), Vector2(907, 383), Vector2(962, 578), Vector2(309, 578)]), Color("2c2c27"))
	draw_colored_polygon(PackedVector2Array([Vector2(364, 390), Vector2(899, 390), Vector2(949, 571), Vector2(322, 571)]), Color("646554" if atmosphere == 0 else "485b58"))
	_line(Vector2(366, 393), Vector2(896, 393), "aba282", 1)
	if has_item:
		# Wrapped parcel is explicitly a generic object placeholder, not a fake clue.
		_parcel()

func _parcel() -> void:
	_rect(428, 443, 152, 76, "363930")
	draw_colored_polygon(PackedVector2Array([Vector2(430, 438), Vector2(552, 427), Vector2(578, 460), Vector2(462, 476)]), Color("b6a483"))
	draw_colored_polygon(PackedVector2Array([Vector2(430, 438), Vector2(462, 476), Vector2(462, 520), Vector2(430, 484)]), Color("897959"))
	draw_colored_polygon(PackedVector2Array([Vector2(462, 476), Vector2(578, 460), Vector2(578, 503), Vector2(462, 520)]), Color("9a8b6a"))
	_line(Vector2(493, 433), Vector2(519, 468), "4f4837", 3)
	_line(Vector2(519, 468), Vector2(519, 511), "4f4837", 3)
	_line(Vector2(445, 457), Vector2(566, 445), "665a43", 2)

func _props() -> void:
	# Incense looks after the shop, lamp looks after the person.
	_rect(171, 466, 80, 36, "60756a")
	_rect(164, 462, 94, 7, "9d9774")
	for x in [192, 211, 230]:
		_line(Vector2(x, 463), Vector2(x, 422), "ad9260", 2)
		_rect(x - 1, 419, 3, 4, "a9693b")
	var smoke := PackedVector2Array([Vector2(211, 416), Vector2(216, 400), Vector2(209, 386), Vector2(213, 370)])
	if smoke_wrong: smoke = PackedVector2Array([Vector2(211, 416), Vector2(229, 410), Vector2(254, 412), Vector2(274, 410)])
	draw_polyline(smoke, Color("a4aaa0"), 1.5, true)
	_rect(1031, 467, 84, 12, "282922")
	_rect(1066, 391, 12, 77, "7c8064")
	draw_colored_polygon(PackedVector2Array([Vector2(1029, 406), Vector2(1048, 373), Vector2(1096, 373), Vector2(1117, 406)]), Color("7a7960"))
	_line(Vector2(1032, 408), Vector2(1114, 408), "b2a983", 3)
	if not lamp_dead:
		var light := Color("e3ba70" if not lamp_wrong and atmosphere != 2 else "afc4c9")
		draw_circle(Vector2(1072, 419), 6, light)
		_line(Vector2(1072, 425), Vector2(1066 if lamp_wrong else 1072, 410), light.to_html(), 3)
	# Closed ledger with ruled fore-edge and one scarce vermilion seal.
	_rect(1000, 516, 166, 52, "312b23")
	_rect(1003, 521, 158, 41, "c4b48e")
	for y in [531, 536, 541, 546]: _line(Vector2(1009, y), Vector2(1157, y), "9b8b6c", 1)
	_rect(1000, 509, 165, 15, "687267")
	_rect(1124, 508, 22, 17, "8d2a24")

func _print_wear() -> void:
	# Static grain only on scenery; UI text is drawn later on clean paper.
	for i in 380:
		var x := float((i * 137 + 19) % 1280)
		var y := float((i * 73 + 41) % 590)
		draw_circle(Vector2(x, y), 0.65, Color(0.85, 0.77, 0.60, 0.10))
	for i in 32:
		var x := float((i * 151) % 1280)
		var y := 369.0 + float((i * 37) % 219)
		draw_line(Vector2(x, y), Vector2(x + 22 + i % 43, y + 1), Color(0.17, 0.12, 0.08, 0.25), 1)

func _rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _line(a: Vector2, b: Vector2, color: String, width := 1.0) -> void:
	draw_line(a, b, Color(color), width, true)

func _outline(rect: Rect2, color: String) -> void:
	draw_rect(rect, Color(color), false, 1)
