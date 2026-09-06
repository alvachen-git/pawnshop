class_name AppraisalPanel
extends IntentPanel

var _image: TextureRect
var _views: HBoxContainer
var _images: Array = []
var _selected := "front"
var _last_visit := ""
var _summary: Label
var _judgements: GridContainer

func _ready() -> void:
	super._ready()
	var study := HBoxContainer.new()
	study.add_theme_constant_override("separation", 14)
	_column.add_child(study)
	_column.move_child(study, 0)
	_image = TextureRect.new()
	_image.name = "ItemStudyImage"
	_image.custom_minimum_size = Vector2(160, 132)
	_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	study.add_child(_image)
	_summary = Label.new()
	_summary.name = "AppraisalSummary"
	_summary.custom_minimum_size.x = 180
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 18)
	study.add_child(_summary)
	_views = HBoxContainer.new()
	_column.add_child(_views)
	_column.move_child(_views, 1)
	_judgements = GridContainer.new()
	_judgements.columns = 2
	_judgements.add_theme_constant_override("h_separation", 6)
	_judgements.add_theme_constant_override("v_separation", 6)
	_column.add_child(_judgements)

func render(model: Dictionary) -> void:
	for child in _judgements.get_children():
		_judgements.remove_child(child)
		child.queue_free()
	super.render(model)
	var visual: Dictionary = model.get("visual", {})
	_summary.visible = not visual.is_empty()
	if not visual.is_empty():
		_summary.text = "%s\n证据估值 %s\n你的判断：%s" % [visual.item_name, visual.estimate, visual.judgement]
		_body.text = "已见线索\n"
		if visual.clues.is_empty(): _body.text += "尚未取证。可从下方选择检查。"
		for clue in visual.clues: _body.text += "• " + clue.text + "\n"
		if not visual.get("provenance", "").is_empty(): _body.text += "\n" + visual.provenance + "\n"
		if not visual.message.is_empty() and not _body.text.contains(visual.message):
			_body.text += "\n" + visual.message
	var buttons := _buttons.get_children()
	var entries: Array = model.get("buttons", [])
	for index in entries.size():
		if entries[index].command == "judge":
			var button := buttons[index] as Button
			_buttons.remove_child(button)
			_judgements.add_child(button)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 14)
	var known := CounterVisualCatalog.images(visual, model.get("images", []))
	if _last_visit != _visit_id: _selected = "front"
	elif known.size() > _images.size(): _selected = known.back().id
	_last_visit = _visit_id
	_images = known.duplicate(true)
	for child in _views.get_children():
		_views.remove_child(child)
		child.queue_free()
	_image.visible = not known.is_empty()
	_views.visible = known.any(func(row: Dictionary) -> bool: return not row.path.is_empty())
	for row in known:
		var button := Button.new()
		button.text = row.label
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_image.bind(row.id))
		_views.add_child(button)
	_show_image(_selected)

func _show_image(id: String) -> void:
	for index in _images.size():
		var row: Dictionary = _images[index]
		if row.id == id:
			_selected = id
			_image.texture = load(row.path) if not row.path.is_empty() else null
			_image.visible = _image.texture != null
			_image.tooltip_text = row.label + " · 复看不耗时"
			for button_index in _views.get_child_count():
				(_views.get_child(button_index) as Button).set_pressed_no_signal(button_index == index)
			return
	_image.texture = null
	_image.hide()
