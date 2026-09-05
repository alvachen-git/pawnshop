class_name CounterTheme
extends RefCounted

# Shared ink/paper controls remain legible in every atmosphere.
static func build() -> Theme:
	var result := Theme.new()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	# Godot uses OpenType axis IDs (wght = 0x77676874), not the raw tag string.
	font.variation_opentype = {0x77676874: 400.0}
	result.default_font = font
	result.default_font_size = 17
	result.set_color("font_color", "Label", Color("302a24"))
	result.set_stylebox("panel", "PanelContainer", paper())
	for state in ["normal", "hover", "pressed", "disabled"]:
		var background := {"normal": "493c30", "hover": "65513b", "pressed": "302b25", "disabled": "c4b595"}
		result.set_stylebox(state, "Button", box(background[state], "8a785b", 12, 10))
		result.set_color("font_" + state + "_color" if state != "normal" else "font_color", "Button", Color("f0dfb9") if state != "disabled" else Color("655c4d"))
	var focus := box("00000000", "b78345", 0, 0)
	focus.set_border_width_all(3)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("normal", "LineEdit", box("f1e2bf", "74634e", 8, 8))
	result.set_color("font_color", "LineEdit", Color("302a24"))
	result.set_color("font_uneditable_color", "LineEdit", Color("655c4d"))
	result.set_stylebox("panel", "PopupPanel", paper())
	result.set_stylebox("panel", "AcceptDialog", paper())
	return result

static func paper() -> StyleBoxFlat:
	return box("d8c7a2", "897557", 2, 2)

static func box(fill: String, edge: String, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style
