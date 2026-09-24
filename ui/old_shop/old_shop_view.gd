class_name OldShopView
extends Control

signal closed
signal read_requested(id: String)
signal action_requested(id: String, choice: String)

const ART := {"fd_ticket": "chen_ticket_trace", "fd_receipt": "sale_receipt", "fd_family": "family_booklet", "mirror_ticket": "mirror_ticket"}
var model: Dictionary = {}
var category := 0
var selected := ""
var mode := "album"
var _canvas: Control
var _content: Control
var _message: Label
var _close: Button
var _tabs: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	theme = CounterTheme.build()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	var book := TextureRect.new()
	book.texture = load("res://assets/old_shop/album.png")
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.stretch_mode = TextureRect.STRETCH_SCALE
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(book, Rect2(6, 47, 1268, 667), _canvas)
	var plaque := TextureRect.new()
	var title_texture := AtlasTexture.new()
	title_texture.atlas = load("res://assets/old_shop/ledger_title.png")
	title_texture.region = Rect2(12, 205, 1938, 385)
	plaque.texture = title_texture
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.accessibility_name = "旧当铺"
	_place(plaque, Rect2(89, 22, 290, 76), _canvas)
	for i in 3:
		var tab := _button(["旧当票", "旧凭据", "铺中旧物"][i], Rect2(742 + i * 116, 39, 109, 43), _canvas)
		tab.toggle_mode = true
		tab.pressed.connect(select_category.bind(i))
		_tabs.append(tab)
	_close = _button("收起 · Esc", Rect2(1094, 39, 146, 43), _canvas)
	_close.z_index = 2
	_close.pressed.connect(back)
	_content = Control.new()
	_content.size = _canvas.size
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_content)
	_message = _label("", Rect2(92, 675, 1095, 36), 16, _canvas, Color("efdfbd"))
	resized.connect(_resize)
	_resize()
	hide()

func _resize() -> void:
	if _canvas == null: return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - _canvas.size * factor) / 2.0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_TAB or (event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not get_viewport().gui_get_focus_owner() is ScrollContainer)):
		var controls: Array[Control] = []
		_focusable(_canvas, controls)
		if not controls.is_empty():
			var current := controls.find(get_viewport().gui_get_focus_owner())
			var backwards: bool = event.shift_pressed if event.keycode == KEY_TAB else event.keycode in [KEY_LEFT, KEY_UP]
			controls[posmod(current + (-1 if backwards else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _focusable(parent: Node, result: Array[Control]) -> void:
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled: result.append(child)
		elif child is ScrollContainer and child.is_visible_in_tree(): result.append(child)
		_focusable(child, result)

func open_album() -> void:
	mode = "album"
	_message.text = ""
	show()
	_draw()
	_tabs[category].grab_focus()

func render(value: Dictionary) -> void:
	model = value
	_draw()

func select_category(index: int) -> void:
	category = index
	selected = ""
	mode = "album"
	_message.text = ""
	_draw()
	_tabs[category].grab_focus()

func show_message(value: String) -> void:
	_message.text = value

func show_document(id: String) -> void:
	selected = id
	mode = "detail"
	_message.text = ""
	_draw()
	_close.grab_focus()

func back() -> void:
	if mode != "album":
		mode = "album"
		_draw()
		var read := _content.get_node_or_null("DocumentHit") as Button
		if read != null: read.grab_focus()
		else: _tabs[category].grab_focus()
	else:
		hide()
		closed.emit()

func _draw() -> void:
	if _content == null: return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for i in 3: _tabs[i].set_pressed_no_signal(category == i)
	_close.text = "收起 · Esc" if mode == "album" else "返回册页 · Esc"
	var docs: Array = model.get("documents", [])
	var page_docs := docs.filter(func(d: Dictionary) -> bool: return int(d.category) == category)
	var chosen: Dictionary = {}
	for doc in docs:
		if doc.id == selected: chosen = doc
	if chosen.is_empty() or (mode == "album" and chosen.category != category):
		chosen = page_docs[0] if not page_docs.is_empty() else {}
		selected = chosen.get("id", "")
	if chosen.is_empty():
		_label(["旧当票", "旧凭据", "铺中旧物"][category], Rect2(92, 91, 455, 42), 26)
		_label("这里还没有夹存的旧纸。" if category != 2 else "这里还没有收存的旧物。", Rect2(115, 281, 420, 100), 21)
		return
	if mode == "image":
		_label(chosen.title, Rect2(91, 91, 1070, 39), 24)
		var scroll := ScrollContainer.new()
		scroll.focus_mode = Control.FOCUS_ALL
		_place(scroll, Rect2(100, 143, 1080, 451))
		var original := _image(chosen, Rect2(0, 0, 960, 1200))
		_content.remove_child(original)
		scroll.add_child(original)
		original.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var dimensions := original.texture.get_size()
		original.custom_minimum_size = dimensions * (1000.0 / dimensions.x)
		var return_button := _button("返回册页", Rect2(996, 611, 178, 43))
		return_button.name = "ReturnFromOriginal"
		return_button.pressed.connect(back)
		return
	if chosen.id != "fd_ticket": _label(chosen.title, Rect2(95, 99, 468, 40), 26)
	if not str(chosen.get("subtitle", "")).is_empty(): _label(chosen.subtitle, Rect2(98, 88 if chosen.id == "fd_ticket" else 132, 470, 24), 15)
	var paper := _image(chosen, Rect2(102, 105, 480, 535) if chosen.id == "fd_ticket" else Rect2(95, 147, 470, 458))
	if chosen.id == "fd_ticket": paper.stretch_mode = TextureRect.STRETCH_SCALE
	if mode == "actions":
		_label("翻查与托话", Rect2(698, 108, 425, 40), 25)
		var y := 196
		for action in model.get("actions", []):
			var b := _button(action.label, Rect2(696, y, 477, 48))
			b.disabled = not action.enabled
			b.pressed.connect(action_requested.emit.bind(action.target_id, action.detail))
			y += 73
		return
	if mode == "detail":
		_label("抄录", Rect2(698, 108, 425, 40), 25)
		_text(chosen.text, Rect2(698, 168, 439, 432), 23)
		_label("翻看旧纸不耗时", Rect2(89, 630, 380, 30), 16)
		var original := _button("展开票面" if chosen.id == "fd_customer_ticket" else "展开原件", Rect2(999, 612, 175, 43))
		original.pressed.connect(func() -> void: mode = "image"; _draw(); _close.grab_focus())
		return
	# The page is selectable, but only the explicit reading intent records discovery.
	if chosen.id == "fd_ticket": _mount(Rect2(118, 128, 450, 496), 39)
	var hit := Button.new()
	hit.name = "DocumentHit"
	hit.flat = true
	_style_document_hit(hit)
	hit.tooltip_text = "翻看 · " + chosen.title
	hit.accessibility_name = hit.tooltip_text
	_place(hit, paper.get_rect())
	hit.pressed.connect(read_requested.emit.bind(selected))
	if page_docs.size() > 1:
		var position_index := page_docs.find(chosen)
		var previous := _button("上一档", Rect2(103, 635, 104, 32))
		var next := _button("下一档", Rect2(434, 635, 104, 32))
		previous.pressed.connect(_select.bind(page_docs[posmod(position_index - 1, page_docs.size())].id))
		next.pressed.connect(_select.bind(page_docs[(position_index + 1) % page_docs.size()].id))
		_label("%d / %d" % [position_index + 1, page_docs.size()], Rect2(277, 636, 100, 29), 16)
	if not model.get("actions", []).is_empty():
		var actions := _button("翻查与托话", Rect2(890, 573, 285, 34))
		actions.pressed.connect(func() -> void: mode = "actions"; _draw(); _close.grab_focus())
	if not str(model.get("outcome", "")).is_empty(): _label(model.outcome, Rect2(696, 578, 190, 45), 16)

func _select(id: String) -> void:
	selected = id
	_draw()
	var b := _content.get_node_or_null("DocumentHit") as Button
	if b != null: b.grab_focus()

func _text(value: String, rect: Rect2, font_size: int) -> void:
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, rect)
	var text := Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_constant_override("line_spacing", 11)
	text.add_theme_color_override("font_color", Color("3b3024"))
	scroll.add_child(text)

func _style_document_hit(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _image(doc: Dictionary, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	if not str(doc.get("art", "")).is_empty(): image.texture = load(doc.art)
	elif ART.has(doc.id): image.texture = load("res://assets/old_shop/%s.png" % ART[doc.id])
	elif doc.id == "fd_mark": image.texture = load("res://assets/first_debt/mark_repair.png")
	elif doc.id == "plan": image.texture = AqiArt.texture("plan")
	else: image.texture = AqiArt.counter_texture("ledger")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, rect)
	if not str(doc.get("ink", "")).is_empty():
		var ink := Label.new()
		ink.text = doc.ink
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Kaiti SC", "STKaiti", "KaiTi"])
		font.fallbacks = [preload("res://assets/fonts/NotoSansSC.ttf")]
		ink.add_theme_font_override("font", font)
		ink.add_theme_font_size_override("font_size", int(rect.size.y * 0.10))
		ink.add_theme_color_override("font_color", Color("30291f"))
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.add_child(ink)
		ink.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		ink.anchor_top = 0.79
		ink.anchor_bottom = 0.79
	return image

func _mount(rect: Rect2, extent: float) -> void:
	var corner := AtlasTexture.new()
	corner.atlas = load("res://assets/old_shop/mounting_corner.png")
	corner.region = Rect2(201, 213, 872, 870)
	for i in 4:
		var image := TextureRect.new()
		image.texture = corner
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.flip_h = i % 2 == 1
		image.flip_v = i >= 2
		_place(image, Rect2(rect.position + Vector2(rect.size.x - extent + 5 if image.flip_h else -5, rect.size.y - extent + 5 if image.flip_v else -5), Vector2.ONE * extent))

func _label(value: String, rect: Rect2, font_size: int, parent: Node = null, color := Color("493b2c")) -> Label:
	var text := Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_font_override("font", CounterTheme.display_font())
	text.add_theme_color_override("font_color", color)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(text, rect, parent)
	return text

func _button(value: String, rect: Rect2, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 19)
	CounterTheme.style_paper_button(button)
	_place(button, rect, parent)
	return button

func _place(node: Control, rect: Rect2, parent: Node = null) -> void:
	(parent if parent != null else _content).add_child(node)
	node.position = rect.position
	node.size = rect.size
