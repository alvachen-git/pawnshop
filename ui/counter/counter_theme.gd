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
		result.set_stylebox(state, "Button", paper_button_style(state))
		result.set_color("font_" + state + "_color" if state != "normal" else "font_color", "Button", Color("302a24") if state != "disabled" else Color("706657"))
	result.set_color("font_focus_color", "Button", Color("302a24"))
	var focus := box("00000000", "8d2a24", 0, 0)
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

static func painted_paper(tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/art04/ui/paper.png")
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 24)
		style.set_content_margin(side, 3)
	return style

static func paper_button_style(state: String) -> StyleBoxTexture:
	var tint: Color = {"normal": Color.WHITE, "hover": Color("fff0cc"), "pressed": Color("bdac86"), "disabled": Color("b7b09b")}[state]
	var style := painted_paper(tint)
	# Keep the existing control padding and minimum height when replacing its skin.
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, 12 if side in [SIDE_LEFT, SIDE_RIGHT] else 10)
	return style

static func style_paper_button(button: Button) -> void:
	button.add_theme_font_override("font", display_font())
	button.add_theme_color_override("font_focus_color", Color("302a24"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint: Color = {"normal": Color.WHITE, "hover": Color("fff0cc"), "pressed": Color("bdac86"), "disabled": Color("8a8877")}[state]
		button.add_theme_stylebox_override(state, painted_paper(tint))
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color("302a24"))
	var focus := box("00000000", "8d2a24", 0, 0)
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)

static func display_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Songti SC", "STSong", "SimSun", "Noto Serif CJK SC"])
	font.fallbacks = [preload("res://assets/fonts/NotoSansSC.ttf")]
	return font

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
