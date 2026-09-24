class_name AppraisalPanel
extends IntentPanel

var _image: TextureRect
var _views: HBoxContainer
var _images: Array = []
var _selected := "front"
var _last_visit := ""
var _summary: Label
var _known_clues: Array = []
var _new_clues: Array = []

func _ready() -> void:
	super._ready()
	var study := HBoxContainer.new()
	study.add_theme_constant_override("separation", 14)
	_column.add_child(study)
	_column.move_child(study, 0)
	_image = TextureRect.new()
	_image.name = "ItemStudyImage"
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

func render(model: Dictionary) -> void:
	super.render(model)
	var visual: Dictionary = model.get("visual", {})
	_summary.visible = not visual.is_empty()
	if not visual.is_empty():
		var ids: Array = visual.clues.map(func(clue: Dictionary) -> String: return clue.id)
		if _last_visit != _visit_id:
			_known_clues = ids.duplicate()
			_new_clues.clear()
		elif ids != _known_clues:
			_new_clues = ids.filter(func(id: String) -> bool: return id not in _known_clues)
			_known_clues = ids.duplicate()
		_summary.text = "%s\n证据估值 %s" % [visual.item_name, visual.estimate]
		_body.text = "已见线索\n"
		if visual.clues.is_empty(): _body.text += "尚未取证。可从下方选择检查。"
		for clue in visual.clues: _body.text += ("本次发现 · " if clue.id in _new_clues else "• ") + clue.text + "\n"
		if visual.get("condition_enabled", false):
			_summary.text = "%s · 参考价值 %s" % [visual.item_name, visual.estimate]
			_body.text = visual.item_description + "\n"
		if not visual.get("guest_warning", "").is_empty(): _body.text = visual.guest_warning + "\n\n" + _body.text
		if not visual.get("goods_note", "").is_empty(): _body.text += "\n" + visual.goods_note + "\n"
		if not visual.get("provenance", "").is_empty(): _body.text += "\n" + visual.provenance + "\n"
		if not visual.message.is_empty() and not _body.text.contains(visual.message) and not (visual.get("condition_enabled", false) and visual.message.begins_with(String(visual.get("condition_note", "")))):
			_body.text += "\n" + visual.message
	var known := CounterVisualCatalog.images(visual, model.get("images", []))
	var gained_view := _last_visit == _visit_id and known.size() > _images.size()
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
		button.pressed.connect(_select_image.bind(row.id))
		_views.add_child(button)
	if visual.get("condition_enabled", false) and visual.get("item_asset", "") != "goods.folding_fan": _views.hide()
	_show_image(_selected)
	if gained_view: _reveal_image.call_deferred()
	if visual.has("tiered_atlas"):
		# Atlas views own their material; ordinary cutouts keep the study shader.
		_image.material = null
		_image.texture = TieredArt.cell(visual.tiered_atlas,int(visual.tiered_exterior),0)
		if visual.get("watch_art",false):
			_image.texture = WatchArt.cell([0,3,4][int(visual.tiered_exterior)])
			_image.material = WatchArt.material()
		_image.visible = _image.texture != null
		_image.tooltip_text = "物品外观"
		_views.hide()

func _select_image(id: String) -> void:
	_show_image(id)
	_reveal_image.call_deferred()

func _reveal_image() -> void:
	var scroll := _column.get_parent() as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0

func _show_image(id: String) -> void:
	var changed_view := id != _selected
	for index in _images.size():
		var row: Dictionary = _images[index]
		if row.id == id:
			_selected = id
			_image.texture = load(row.path) if not row.path.is_empty() else null
			_image.material = CounterVisualCatalog.study_material(_image.texture)
			_image.visible = _image.texture != null
			_image.tooltip_text = row.label + " · 复看不耗时"
			for button_index in _views.get_child_count():
				(_views.get_child(button_index) as Button).set_pressed_no_signal(button_index == index)
			if changed_view: _reveal_image.call_deferred()
			return
	_image.texture = null
	_image.hide()
