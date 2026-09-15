class_name RiskPanel
extends EventPanel

signal record_selected(id: String)
var _records: OptionButton
var _record_ids: Array[String] = []
var _pages: HBoxContainer
var _actions_tab: Button
var _notes_tab: Button
var _notes_open := false
var _archive := false
var _categories: HBoxContainer
var _journal: VBoxContainer
var _sections: Array = []
var _category := ""
var _expanded: Dictionary = {}
var _structured := false
var _bold: FontVariation

func _ready() -> void:
	super._ready()
	_bold = FontVariation.new()
	_bold.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	_bold.variation_opentype = {0x77676874: 700.0}
	# Keep navigation above the scrolling page, including at long evidence entries.
	var scroll := _column.get_parent() as ScrollContainer
	var margin := scroll.get_parent()
	margin.remove_child(scroll)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	layout.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_records = OptionButton.new()
	_records.name = "ItemRecords"
	_records.add_theme_font_size_override("font_size", 18)
	_records.item_selected.connect(func(index: int) -> void: record_selected.emit(_record_ids[index]); reset_reading_position())
	layout.add_child(_records)
	layout.move_child(_records, 0)
	_pages = HBoxContainer.new()
	layout.add_child(_pages)
	layout.move_child(_pages, 1)
	_actions_tab = Button.new()
	_actions_tab.text = "照看与处置"
	_actions_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_tab.pressed.connect(func() -> void: show_notes(false))
	_pages.add_child(_actions_tab)
	_notes_tab = Button.new()
	_notes_tab.text = "物品见闻"
	_notes_tab.toggle_mode = true
	_notes_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_tab.pressed.connect(func() -> void: show_notes(true))
	_pages.add_child(_notes_tab)
	_categories = HBoxContainer.new()
	_categories.add_theme_constant_override("separation", 4)
	layout.add_child(_categories)
	layout.move_child(_categories, 2)
	_journal = VBoxContainer.new()
	_journal.add_theme_constant_override("separation", 12)
	_column.add_child(_journal)

func render(model: Dictionary) -> void:
	super.render(model)
	_records.clear()
	_record_ids.clear()
	for row in model.get("records", []):
		_record_ids.append(row.id)
		_records.add_item(row.label)
	_records.visible = not _record_ids.is_empty()
	_records.disabled = model.get("requires_response", false)
	var index := _record_ids.find(model.get("record_id", ""))
	if index >= 0: _records.select(index)
	_archive = model.get("record_id", "") == "death_archive"
	_structured = model.has("note_sections")
	var sections: Array = model.get("note_sections", [])
	if sections != _sections:
		_sections = sections.duplicate(true)
		if not _sections.any(func(section: Dictionary) -> bool: return section.id == _category):
			_category = _sections[0].id if not _sections.is_empty() else ""
		_rebuild_journal()
	if _archive: _notes_open = false
	_pages.visible = not _record_ids.is_empty() and not _archive
	_notes_tab.disabled = (_sections.is_empty() if _structured else _history.text.is_empty()) or model.get("requires_response", false)
	if _notes_tab.disabled: _notes_open = false
	_update_page()

func show_notes(value: bool) -> void:
	_notes_open = value and not _notes_tab.disabled
	_update_page()
	reset_reading_position()

func _update_page() -> void:
	_body.visible = not _notes_open
	_buttons.visible = not _notes_open and not _archive
	_history.visible = ((_notes_open and not _structured) or _archive) and not _history.text.is_empty()
	_categories.visible = _notes_open and _structured
	_journal.visible = _notes_open and _structured
	_actions_tab.disabled = not _notes_open
	_notes_tab.set_pressed_no_signal(_notes_open)

func _rebuild_journal() -> void:
	for node in _categories.get_children():
		_categories.remove_child(node)
		node.queue_free()
	for section in _sections:
		var tab := Button.new()
		tab.text = section.title
		tab.toggle_mode = true
		tab.button_pressed = section.id == _category
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 15)
		tab.add_theme_font_override("font", _bold)
		for state in ["normal", "hover", "pressed"]:
			tab.add_theme_stylebox_override(state, CounterTheme.box("b9a47c" if state == "pressed" else "e1d1ad", "9b8560", 6, 8))
		tab.pressed.connect(func() -> void:
			_category = section.id
			_rebuild_journal()
			reset_reading_position())
		_categories.add_child(tab)
	for node in _journal.get_children():
		_journal.remove_child(node)
		node.queue_free()
	for section in _sections:
		if section.id != _category: continue
		_add_heading(section)
		if not _expanded.has(_category): _expanded[_category] = section.entries.back().id
		# Newest material first; each group retains its own expanded entry.
		var entries: Array = section.entries.duplicate()
		entries.reverse()
		for row in entries: _add_entry(row)

func _label(text: String, size: int, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("line_spacing", 5)
	if bold: label.add_theme_font_override("font", _bold)
	return label

func _add_heading(section: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_journal.add_child(row)
	var heading := _label(section.title + "\n%d则记事" % section.entries.size(), 16, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var path := "res://assets/journal/mirror_vignette.png"
	if not ResourceLoader.exists(path): return
	var art := TextureRect.new()
	art.texture = load(path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(180, 60)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

func _add_entry(row: Dictionary) -> void:
	var card := PanelContainer.new()
	card.set_meta("entry_id", row.id)
	card.add_theme_stylebox_override("panel", CounterTheme.box("e4d5b3", "b29b73", 12, 10))
	_journal.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var expanded: bool = _expanded.get(_category, "") == row.id
	var header := Button.new()
	header.text = ("－  " if expanded else "＋  ") + row.title
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_override("font", _bold)
	header.add_theme_font_size_override("font_size", 17)
	header.tooltip_text = "收起这条记事" if expanded else "展开这条记事"
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxEmpty.new()
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		header.add_theme_stylebox_override(state, style)
	header.pressed.connect(func() -> void:
		_expanded[_category] = "" if expanded else row.id
		_rebuild_journal()
		_focus_entry.call_deferred(row.id, not expanded))
	column.add_child(header)
	var source := _label(row.source, 13)
	source.add_theme_color_override("font_color", Color("685940"))
	column.add_child(source)
	if expanded:
		var line := HSeparator.new()
		column.add_child(line)
		column.add_child(_label(row.body, 16))

func _focus_entry(id: String, align_top: bool) -> void:
	await get_tree().process_frame
	for card in _journal.get_children():
		if card.get_meta("entry_id", "") != id: continue
		card.get_child(0).get_child(0).grab_focus()
		if align_top:
			var scroll := _column.get_parent() as ScrollContainer
			scroll.scroll_vertical = int(card.position.y)
		return

func reset_reading_position() -> void:
	var scroll := _column.get_parent() as ScrollContainer
	scroll.set_deferred("scroll_vertical", 0)
