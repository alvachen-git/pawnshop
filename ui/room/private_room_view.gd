class_name PrivateRoomView
extends Control

signal command_requested(command: String)
var _bed: Button
var _lamp: Button
var _desk: Button
var _body: Label
var _heading: Label
var _confirm: ConfirmationDialog
var _model: Dictionary = {}
var _photo: Button
var _letter: AcceptDialog

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_heading = Label.new()
	_heading.text = "楼 上 · 寝 屋"
	_heading.add_theme_font_size_override("font_size", 30)
	_heading.add_theme_color_override("font_color", Color("ead9b5"))
	add_child(_heading)
	_place(_heading, Rect2(0.05, 0.05, 0.7, 0.08))
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 19)
	_body.add_theme_color_override("font_color", Color("dfd4bd"))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_place(_body, Rect2(0.05, 0.16, 0.37, 0.25))
	_lamp = _hotspot("RoomLamp", "命灯", Rect2(0.16, 0.47, 0.10, 0.12))
	_lamp.pressed.connect(func() -> void: _body.text = _model.lamp)
	_desk = _hotspot("RoomDesk", "书桌 · 旧信", Rect2(0.065, 0.63, 0.25, 0.17))
	_desk.pressed.connect(_read_letter)
	_photo = _hotspot("RoomPhoto", "姚曼卿的照片", Rect2(0.05, 0.82, 0.25, 0.075))
	_photo.pressed.connect(func() -> void: _body.text = tr("opening.room.photo"))
	_bed = _hotspot("RoomBed", "床 · 就寝", Rect2(0.405, 0.62, 0.35, 0.28))
	_bed.pressed.connect(_bed_pressed)

func _create_confirmation() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "就寝"
	_confirm.dialog_text = "准备就寝，结束今天的活动？"
	_confirm.ok_button_text = "就寝"
	_confirm.cancel_button_text = "再坐一会儿"
	_confirm.confirmed.connect(func() -> void: command_requested.emit("sleep"))
	add_child(_confirm)

func _hotspot(node_name: String, caption: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.add_theme_stylebox_override("normal", CounterTheme.box("171c1c55", "847452", 6, 1))
	button.add_theme_stylebox_override("hover", CounterTheme.box("4b453b88", "d7bd83", 6, 2))
	button.add_theme_stylebox_override("disabled", CounterTheme.box("171c1c22", "605b4b", 6, 1))
	button.add_theme_color_override("font_color", Color("efdfb9"))
	button.add_theme_color_override("font_disabled_color", Color("999180"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	_place(button, bounds)
	return button

func _place(control: Control, bounds: Rect2) -> void:
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y

func render(model: Dictionary) -> void:
	var phase_changed: bool = _model.get("phase", "") != model.phase
	_model = model
	visible = model.visible
	if not visible and _confirm != null: _confirm.hide()
	_heading.text = "楼 上 · 寝 屋    第%d夜" % model.night
	if phase_changed or not model.error.is_empty(): _body.text = model.body + ("\n\n" + model.error if not model.error.is_empty() else "")
	_bed.text = "床 · 就寝" if model.phase == "private_room" else "等到天明"
	if model.dead: _bed.text = "灯已熄"
	_bed.disabled = not model.can_sleep and not model.can_finish
	_lamp.disabled = model.pending or model.dead
	_desk.disabled = model.pending or model.dead
	_photo.visible = model.get("photo_placed", false)
	_photo.disabled = model.pending or model.dead
	if not visible and _letter != null: _letter.hide()
	queue_redraw()

func _read_letter() -> void:
	if not _model.get("gu_letter", false):
		_body.text = "信纸压在砚台下面，折痕已经发白。\n\n「到了上海，先安顿住处。夜里潮，旧衣别急着扔。钱总能慢慢挣。」\n\n信尾没有再写别的话。"
		return
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

func _bed_pressed() -> void:
	if _model.can_sleep:
		if _confirm == null: _create_confirmation()
		_confirm.popup_centered(Vector2i(380, 160))
	elif _model.can_finish: command_requested.emit("finish_sleep")

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 648))
	_box(Rect2(0, 0, 1280, 648), "202725")
	_box(Rect2(0, 335, 1280, 313), "292621")
	for y in range(380, 650, 55): draw_line(Vector2(0, y), Vector2(1280, y), Color("413a30"), 2)
	for x in [35, 453, 977, 1245]: _box(Rect2(x, 0, 12, 648), "161c1b")
	# Window, closed door, and a quiet mirror kept front-facing on the right.
	_box(Rect2(560, 46, 186, 185), "73694f")
	_box(Rect2(570, 56, 166, 165), "15252b")
	for x in [610, 651, 692]: _box(Rect2(x, 56, 4, 165), "665e48")
	_box(Rect2(570, 132, 166, 4), "665e48")
	_box(Rect2(1030, 68, 175, 358), "514331")
	_box(Rect2(1040, 78, 155, 338), "302f26")
	draw_circle(Vector2(1171, 258), 5, Color("a79767"))
	_box(Rect2(817, 89, 148, 240), "826e50")
	_box(Rect2(827, 99, 128, 220), "52605c")
	_box(Rect2(843, 243, 92, 56), "333e3a")
	draw_line(Vector2(842, 118), Vector2(918, 180), Color("7a847766"), 3)
	# Bed frame and a folded quilt.
	_box(Rect2(492, 351, 497, 250), "211e19")
	_box(Rect2(505, 366, 469, 182), "666859")
	_box(Rect2(533, 386, 163, 56), "a89f7c")
	_box(Rect2(514, 461, 450, 101), "434e47")
	for y in [480, 507, 534]: draw_line(Vector2(518, y), Vector2(960, y), Color("6b7160"), 2)
	# Desk and life lamp on the left.
	_box(Rect2(69, 392, 354, 24), "796547")
	_box(Rect2(85, 416, 24, 181), "473928")
	_box(Rect2(382, 416, 24, 181), "473928")
	_box(Rect2(114, 369, 112, 19), "b5a47e")
	_box(Rect2(265, 371, 43, 15), "171d1a")
	_box(Rect2(235, 331, 54, 13), "867348")
	_box(Rect2(257, 340, 10, 46), "867348")
	var flame := Color("a6bca5" if _model.get("haunting", false) else "e4bc79")
	if not _model.get("dead", false):
		draw_circle(Vector2(262, 311), 24, Color(flame, 0.08))
		var grade := int(_model.get("lamp_grade", 0))
		var tip := 320 if grade >= 4 else (309 if grade == 2 else 296)
		draw_colored_polygon(PackedVector2Array([Vector2(255, 329), Vector2(267 if _model.get("haunting", false) else 261, tip), Vector2(268, 329)]), flame)
		if grade == 3: draw_colored_polygon(PackedVector2Array([Vector2(268, 329), Vector2(276, 302), Vector2(281, 329)]), flame)

func _box(rect: Rect2, color: String) -> void:
	draw_rect(rect, Color(color))
