class_name DialoguePanel
extends IntentPanel

var _portrait: TextureRect
var _identity: Label
var _history_toggle: Button
var _history: Label
var _last_visit := ""

func _ready() -> void:
	super._ready()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_column.add_child(header)
	_column.move_child(header, 0)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(78, 94)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_portrait)
	_identity = Label.new()
	_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_identity.add_theme_font_size_override("font_size", 18)
	header.add_child(_identity)
	_body.add_theme_font_size_override("font_size", 16)
	_history_toggle = Button.new()
	_history_toggle.toggle_mode = true
	_history_toggle.toggled.connect(func(pressed: bool) -> void: _history.visible = pressed)
	_column.add_child(_history_toggle)
	_history = Label.new()
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.add_theme_font_size_override("font_size", 14)
	_history.hide()
	_column.add_child(_history)

func render(model: Dictionary) -> void:
	super.render(model)
	var visual: Dictionary = model.get("visual", {})
	_portrait.texture = CounterVisualCatalog.portrait(visual.get("portrait_asset", ""))
	_portrait.visible = _portrait.texture != null
	_identity.text = "" if visual.is_empty() else "%s\n%s · 留到 %s" % [visual.customer_name, visual.attitude, visual.deadline]
	if _last_visit != _visit_id:
		_history_toggle.set_pressed_no_signal(false)
		_history.hide()
	_last_visit = _visit_id
	var speech: Array = visual.get("speech", [])
	_history_toggle.visible = not speech.is_empty()
	_history_toggle.text = "查看已问口供（%d）" % speech.size()
	_history.text = "口供记录 · 尚须与实物核对\n"
	for row in speech: _history.text += "\n" + row.question + "\n" + row.answer + "\n"
	if not visual.is_empty():
		_body.text = visual.introduction if speech.is_empty() else speech.back().question + "\n\n" + speech.back().answer
		_body.text += "\n\n口供须与实物核对。"
		if not visual.message.is_empty() and not _body.text.contains(visual.message):
			_body.text += "\n" + visual.message
