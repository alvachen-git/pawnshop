class_name AqiCompanionView
extends Control

signal choice_requested(event_id: String, choice_id: String)
signal notification_requested
signal opened
var hotspot: Button
var portrait: TextureRect
var foreground: Polygon2D
var _portrait_light: ShaderMaterial
var dialogue: CounterStoryView
var hint: Label
var _model: Dictionary = {}
var _topic := ""
var _hint_serial := 0
var attention: Label
var _attention_tween: Tween
var _notice: Dictionary = {}
var _hover_tween: Tween

func _ready() -> void:
	name = "AqiCompanion"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait = TextureRect.new()
	portrait.name = "SeatedAqi"
	portrait.texture = preload("res://assets/aqi/companion-side.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_light = ShaderMaterial.new()
	_portrait_light.shader = preload("res://ui/art/aqi_companion_light.gdshader")
	portrait.material = _portrait_light
	add_child(portrait)
	CounterView._bounds(portrait, 0.224, 0.363, 0.326, 0.572)
	# The same painted wood is drawn in front of the body, registered to the
	# room's full-canvas coordinates and sharing its live lighting material.
	var room := get_parent().get_node("Room") as CounterStage
	foreground = Polygon2D.new()
	foreground.name = "PaintedCounterForeground"
	foreground.texture = room._paint.texture
	foreground.material = room._paint.material
	add_child(foreground)
	resized.connect(_register_counter_edge)
	_register_counter_edge()
	hotspot = Button.new()
	hotspot.name = "AqiCompanionHotspot"
	hotspot.flat = true
	# The portrait hover wash supplies feedback without a tooltip over her face.
	hotspot.tooltip_text = ""
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "disabled"]: hotspot.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(hotspot)
	CounterView._bounds(hotspot, 0.225, 0.375, 0.325, 0.532)
	hotspot.pressed.connect(_open)
	hotspot.mouse_entered.connect(_set_hover.bind(true))
	hotspot.mouse_exited.connect(_set_hover.bind(false))
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _clear_hover()
	)
	attention = Label.new()
	attention.name = "AqiAttention"
	attention.text = "!"
	attention.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attention.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attention.add_theme_font_size_override("font_size", 48)
	attention.add_theme_color_override("font_color", Color("efd18c"))
	attention.add_theme_color_override("font_outline_color", Color("392b1c"))
	attention.add_theme_constant_override("outline_size", 5)
	add_child(attention)
	CounterView._bounds(attention, 0.294, 0.326, 0.322, 0.416)
	attention.hide()
	hint = Label.new()
	hint.text = "先招呼客人，等会儿再聊。"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("ead7a8"))
	add_child(hint)
	CounterView._bounds(hint, 0.19, 0.295, 0.43, 0.35)
	hint.hide()
	dialogue = CounterStoryView.new()
	add_child(dialogue)
	dialogue.name = "AqiSmallTalk"
	CounterView._bounds(dialogue, 0.60, 0.095, 0.98, 0.73)
	dialogue.opened.connect(opened.emit)
	dialogue.closed.connect(func() -> void: _notice = {}; hotspot.grab_focus())
	dialogue.choice_requested.connect(_choose)
	hide()

func render(model: Dictionary) -> void:
	var changed_run: bool = model.get("token", "") != _model.get("token", "") or model.get("night", 0) != _model.get("night", 0)
	_model = model
	_set_attention(not model.get("notification", {}).is_empty())
	visible = model.get("visible", false)
	if changed_run or not visible or not model.get("available", false): collapse()
	elif dialogue.visible: _show_page()

func reset() -> void:
	_clear_hover()
	_model = {}
	_set_attention(false)
	collapse()

func collapse() -> bool:
	var was_open := dialogue.visible
	dialogue.hide()
	hint.hide()
	_topic = ""
	_notice = {}
	if was_open and hotspot.is_visible_in_tree(): hotspot.grab_focus()
	return was_open

func _open() -> void:
	if not _model.get("available", false):
		_hint_serial += 1
		var serial := _hint_serial
		hint.show()
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if serial == _hint_serial: hint.hide())
		return
	if not _model.get("notification", {}).is_empty():
		notification_requested.emit()
		return
	_notice = {}
	_topic = ""
	_show_page()
	dialogue.show_dialogue()

func _show_page() -> void:
	if not _notice.is_empty():
		dialogue.render(_notice, JSON.stringify(_notice))
		return
	var page := {"title": "柜边的阿七", "text": "阿七抬起头，朝你笑了笑。", "buttons": []}
	if _topic.is_empty():
		for topic in _model.topics: page.buttons.append({"target_id": "topic", "detail": topic.id, "label": topic.label, "enabled": true})
	else:
		for topic in _model.topics:
			if topic.id != _topic: continue
			page.title = topic.title
			page.text = topic.text
			page.buttons = topic.buttons.duplicate(true)
			if not topic.chosen.is_empty(): page.buttons = [{"target_id": "back", "detail": "back", "label": "接着忙", "enabled": true}]
	dialogue.render(page, JSON.stringify(page))
	dialogue.show()

func _choose(event_id: String, choice_id: String) -> void:
	if event_id == "notice_retry": notification_requested.emit()
	elif event_id == "notice_done":
		_notice = {}
		_topic = ""
		_show_page()
	elif event_id == "topic":
		_topic = choice_id
		_show_page()
	elif event_id == "back": collapse()
	else: choice_requested.emit(event_id, choice_id)

func set_lighting(band: int, atmosphere: int = 0) -> void:
	_portrait_light.set_shader_parameter("night_band", band)
	_portrait_light.set_shader_parameter("atmosphere", atmosphere)

func _register_counter_edge() -> void:
	# Trace the back edge of the existing 1672 x 941 painting, including its chips.
	# CounterStage paints a full-height canvas behind a 90%-height CounterView.
	var edge := PackedVector2Array([
		Vector2(360, 447), Vector2(386, 446), Vector2(402, 445),
		Vector2(419, 447), Vector2(441, 446), Vector2(458, 446),
		Vector2(478, 448), Vector2(500, 447), Vector2(525, 446),
		Vector2(548, 448), Vector2(570, 447),
		Vector2(570, 510), Vector2(360, 510)])
	foreground.uv = edge
	var vertices := PackedVector2Array()
	for point in edge: vertices.append(point * Vector2(size.x / 1672.0, size.y / 0.9 / 941.0))
	foreground.polygon = vertices

func _set_attention(active: bool) -> void:
	if attention.visible == active: return
	attention.visible = active
	if _attention_tween != null: _attention_tween.kill()
	attention.modulate.a = 1.0
	if active:
		_attention_tween = create_tween().set_loops()
		_attention_tween.tween_property(attention, "modulate:a", 0.65, 0.65)
		_attention_tween.tween_property(attention, "modulate:a", 1.0, 0.65)

func show_notification(notice: Dictionary) -> void:
	_notice = {"title": notice.title, "text": notice.text, "buttons": [{"target_id": "notice_done", "detail": "done", "label": "聊点别的", "enabled": true}]}
	_set_attention(false)
	_show_page()
	dialogue.show_dialogue()

func notification_error(message: String) -> void:
	_notice = {"title": "柜边的阿七", "text": message, "buttons": [{"target_id": "notice_retry", "detail": "retry", "label": "重试", "enabled": true}]}
	_show_page()
	dialogue.show_dialogue()

func _set_hover(active: bool) -> void:
	if _hover_tween != null: _hover_tween.kill()
	var current := float(_portrait_light.get_shader_parameter("hover_amount"))
	_hover_tween = create_tween()
	_hover_tween.tween_method(func(amount: float) -> void:
		_portrait_light.set_shader_parameter("hover_amount", amount), current, 1.0 if active else 0.0, 0.14)

func _clear_hover() -> void:
	if _hover_tween != null: _hover_tween.kill()
	_portrait_light.set_shader_parameter("hover_amount", 0.0)
