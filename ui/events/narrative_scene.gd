class_name NarrativeScene
extends Control

signal menu_requested

var _session: RunSession
var _title: Label
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _skip: Button
var _menu_button: Button
var _scene := ""
var _signature := ""
var _model: Dictionary = {}
var _audio: AudioStreamPlayer
var _heard_scene := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 15
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -23
	add_child(_audio)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CounterTheme.box("262622f5", "8b7955", 26, 26))
	add_child(card)
	_place(card, Rect2(0.48, 0.07, 0.47, 0.85))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_title = _label(column, 29, "ead8b4")
	_speaker = _label(column, 16, "c4a575")
	column.add_child(HSeparator.new())
	_text = RichTextLabel.new()
	_text.name = "NarrativeText"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.add_theme_color_override("default_color", Color("e1d7c1"))
	_text.bbcode_enabled = false
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "NarrativeChoices"
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)
	_skip = Button.new()
	_skip.text = tr("opening.skip")
	_skip.pressed.connect(_skip_prologue)
	add_child(_skip)
	_place(_skip, Rect2(0.055, 0.86, 0.36, 0.06))
	_menu_button = Button.new()
	_menu_button.text = "菜单"
	_menu_button.add_theme_font_size_override("font_size", 14)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(_menu_button)
	_place(_menu_button, Rect2(0.77, 0.935, 0.18, 0.045))
	hide()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		_audio.stop()
		_heard_scene = ""
		return
	if _scene != _heard_scene:
		_heard_scene = _scene
		var sound: String = {"factory": "factory", "key": "key", "exterior": "door", "customer": "clock", "sleep": "floor"}.get(_scene, "paper")
		_audio.stream = load("res://assets/opening/" + sound + ".wav")
		_audio.play()
	elif _scene == "factory" and not _audio.playing:
		_audio.play()

func bind(session: RunSession) -> void:
	_session = session
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	_model = _session.event_model()
	visible = not _model.presentation.is_empty()
	if not visible:
		_signature = ""
		return
	_scene = _model.presentation.scene
	var state := _session.read_state()
	var signature: String = state.run_token + "/" + _model.pending_id + "/" + str(state.event_history.size())
	if _scene == "inspection":
		var meta := ConfigFile.new()
		meta.set_value("opening", "seen", true)
		meta.save(_session._save.path + ".meta")
	var meta := ConfigFile.new()
	_skip.visible = _model.presentation.get("repeat_skip", false) and meta.load(_session._save.path + ".meta") == OK and meta.get_value("opening", "seen", false)
	if signature == _signature: return
	_signature = signature
	_title.text = _model.title
	_speaker.text = _model.speaker
	_text.text = _model.text + ("\n\n" + _model.feedback if not _model.feedback.is_empty() else "")
	_text.scroll_to_line(0)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for entry in _model.buttons:
		var button := Button.new()
		button.name = "Choice_" + entry.detail
		button.text = entry.label
		button.custom_minimum_size.y = 43
		button.disabled = not entry.enabled
		button.pressed.connect(_choose.bind(entry.target_id, entry.detail))
		_choices.add_child(button)
	if _choices.get_child_count() > 0: _choices.get_child(0).grab_focus()
	var focusable: Array[Control] = []
	for button in _choices.get_children(): focusable.append(button)
	if _skip.visible: focusable.append(_skip)
	focusable.append(_menu_button)
	for index in focusable.size():
		var button := focusable[index]
		button.focus_next = button.get_path_to(focusable[(index + 1) % focusable.size()])
		button.focus_previous = button.get_path_to(focusable[(index - 1 + focusable.size()) % focusable.size()])
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled()

func _choose(id: String, choice: String) -> void:
	var result := _session.event_command(id, choice)
	if not result.ok: _text.text += "\n\n" + result.message

func _skip_prologue() -> void:
	# Replay the same zero-cost choices; preserve flags and checkpoint validation.
	for step in 40:
		var model := _session.event_model()
		if not model.presentation.get("repeat_skip", false) or model.buttons.is_empty(): break
		var first: Dictionary = model.buttons[0]
		var result := _session.event_command(first.target_id, first.detail)
		if not result.ok:
			_text.text += "\n\n" + result.message
			break

func _label(parent: Node, font_size: int, color: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _place(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 720))
	_box(Rect2(0, 0, 1280, 720), "171b1a" if _scene == "factory" else "25241e")
	_box(Rect2(0, 485, 1280, 235), "1b1c19")
	for x in [55, 286, 527]:
		_box(Rect2(x, 0, 9, 720), "111613")
	if _scene == "factory":
		for x in [80, 235, 390]:
			_box(Rect2(x, 65, 124, 175), "797e71")
			for i in 3: _box(Rect2(x + 6 + i * 40, 72, 32, 161), "3a4b48")
			_box(Rect2(x, 151, 124, 6), "777563")
		for x in [60, 230, 400]:
			_box(Rect2(x, 352, 141, 145), "454b42")
			draw_circle(Vector2(x + 70, 362), 50, Color("737765"))
			draw_circle(Vector2(x + 70, 362), 36, Color("2b3531"))
			for y in [412, 438, 464]: _box(Rect2(x + 8, y, 125, 6), "242d28")
		_person(Vector2(415, 365), "595e51")
	elif _scene in ["photo", "wedding"]:
		_box(Rect2(73, 167, 282, 326), "bdad89")
		_box(Rect2(88, 182, 252, 270), "74796a")
		_person(Vector2(158, 312), "424e44")
		_person(Vector2(267, 320), "565b4c")
		if _scene == "wedding":
			_box(Rect2(355, 253, 179, 242), "873b30")
			_ink("囍", Vector2(408, 355), 54, "d4b480")
			_ink("姚曼卿", Vector2(397, 412), 20, "d4b480")
			_ink("陆绍廷", Vector2(397, 446), 20, "d4b480")
	elif _scene in ["key", "letter"]:
		_box(Rect2(100, 183, 351, 264), "ccbb93")
		for y in range(221, 408, 31): _box(Rect2(125, y, 257, 2), "a89670")
		draw_arc(Vector2(420, 451), 30, 0, TAU, 40, Color("b5a679"), 8)
		draw_line(Vector2(394, 451), Vector2(232, 451), Color("b5a679"), 8)
		_box(Rect2(236, 451, 12, 23), "b5a679")
		_box(Rect2(263, 451, 12, 16), "b5a679")
	elif _scene == "exterior":
		_box(Rect2(89, 144, 438, 407), "504532")
		_box(Rect2(117, 229, 174, 321), "191f1c")
		_box(Rect2(310, 229, 187, 321), "302d23")
		_box(Rect2(128, 164, 361, 55), "29271f")
		_ink("当", Vector2(276, 207), 38, "c7b58a")
	elif _scene in ["room", "sleep"]:
		_box(Rect2(348, 341, 205, 176), "4d5548")
		_box(Rect2(359, 350, 116, 51), "a59876")
		_box(Rect2(75, 345, 237, 16), "786447")
		_box(Rect2(90, 361, 13, 152), "4c3c2c")
		_box(Rect2(275, 361, 13, 152), "4c3c2c")
		_lamp(Vector2(226, 331))
		_box(Rect2(85, 96, 142, 168), "615c47")
		_box(Rect2(94, 106, 124, 149), "263a3b")
		if "INTRO_MANQING_PHOTO_PLACED" in _session.read_state().narrative_flags:
			_box(Rect2(127, 281, 55, 63), "c4b287")
			_box(Rect2(134, 288, 41, 44), "657060")
	else:
		_box(Rect2(55, 355, 511, 172), "59432e")
		_box(Rect2(50, 340, 521, 21), "8a704b")
		if _scene in ["memory", "stamp", "customer"]: _person(Vector2(293, 247), "75705a")
		_lamp(Vector2(463, 323))
		_box(Rect2(102, 316, 113, 17), "c5b58d")
		_box(Rect2(231, 312, 93, 21), "63372d")
		if _scene == "stamp":
			_box(Rect2(112, 398, 305, 133), "cdbc97")
			_box(Rect2(307, 428, 67, 67), "8c3328")
			_ink("当", Vector2(320, 474), 34, "d9b98b")
	_ink("鬼 市 当 铺", Vector2(73, 61), 18, "b7a582")
	_ink({"factory":"纱厂 · 午后", "photo":"衣内袋的旧照片", "wedding":"旧人 · 新帖", "key":"一封信 · 一把钥匙", "letter":"顾叔的笔迹", "memory":"柜上旧事", "stamp":"落印成账", "exterior":"老城厢 · 黄昏", "inspection":"柜台还是从前那张", "customer":"第一夜 · 新掌柜", "room":"灯火初安", "sleep":"夜深了"}.get(_scene, ""), Vector2(74, 577), 24, "d5c29a")

func _box(rect: Rect2, color: String) -> void:
	draw_rect(rect, Color(color))

func _ink(text: String, point: Vector2, font_size: int, color: String) -> void:
	draw_string(get_theme_default_font(), point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color))

func _person(point: Vector2, color: String) -> void:
	draw_circle(point - Vector2(0, 57), 28, Color(color))
	draw_colored_polygon(PackedVector2Array([point+Vector2(-22,-28),point+Vector2(22,-28),point+Vector2(56,87),point+Vector2(-56,87)]), Color(color))

func _lamp(point: Vector2) -> void:
	_box(Rect2(point.x-24,point.y-9,48,9), "aa925d")
	_box(Rect2(point.x-4,point.y-43,8,34), "aa925d")
	draw_circle(point-Vector2(0,57), 37, Color("f1cd7330"))
	draw_colored_polygon(PackedVector2Array([point+Vector2(-7,-44),point+Vector2(0,-79),point+Vector2(7,-44)]), Color("f0c986"))
