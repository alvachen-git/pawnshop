class_name FirstDebtDocument
extends PanelContainer

var document: Dictionary
func configure(row: Dictionary) -> void:
	document = row.duplicate(true)
	custom_minimum_size = Vector2(330, 510)
	theme = CounterTheme.build()
	var paper := CounterTheme.painted_paper(Color("ead8b5"))
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: paper.set_content_margin(side, 22)
	add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var title := AccountPaper.label(column, row.title, 25)
	title.add_theme_color_override("font_color", Color("382d20"))
	AccountPaper.rule(column)
	if row.id == "fd_mark":
		var image := TextureRect.new()
		image.texture = load("res://assets/first_debt/mark_repair.png")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(280, 230)
		column.add_child(image)
	var text := AccountPaper.label(column, row.text, 21)
	text.add_theme_color_override("font_color", Color("403326"))
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if row.id in ["fd_ticket", "fd_receipt", "fd_family"]:
		var stamp := AccountPaper.label(column, "瑞字四十七", 20)
		stamp.add_theme_color_override("font_color", Color("805747"))
