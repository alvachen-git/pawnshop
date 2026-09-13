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

func _ready() -> void:
	super._ready()
	_records = OptionButton.new()
	_records.name = "ItemRecords"
	_records.add_theme_font_size_override("font_size", 18)
	_records.item_selected.connect(func(index: int) -> void: record_selected.emit(_record_ids[index]); reset_reading_position())
	_column.add_child(_records)
	_column.move_child(_records, 0)
	_pages = HBoxContainer.new()
	_column.add_child(_pages)
	_column.move_child(_pages, 1)
	_actions_tab = Button.new()
	_actions_tab.text = "照看与处置"
	_actions_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_tab.pressed.connect(func() -> void: show_notes(false))
	_pages.add_child(_actions_tab)
	_notes_tab = Button.new()
	_notes_tab.text = "物品见闻"
	_notes_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_tab.pressed.connect(func() -> void: show_notes(true))
	_pages.add_child(_notes_tab)

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
	if _archive: _notes_open = false
	_pages.visible = not _record_ids.is_empty() and not _archive
	_notes_tab.disabled = _history.text.is_empty() or model.get("requires_response", false)
	if _notes_tab.disabled: _notes_open = false
	_update_page()

func show_notes(value: bool) -> void:
	_notes_open = value and not _notes_tab.disabled
	_update_page()
	reset_reading_position()

func _update_page() -> void:
	_body.visible = not _notes_open
	_buttons.visible = not _notes_open and not _archive
	_history.visible = (_notes_open or _archive) and not _history.text.is_empty()
	_actions_tab.disabled = not _notes_open

func reset_reading_position() -> void:
	var scroll := _column.get_parent() as ScrollContainer
	scroll.set_deferred("scroll_vertical", 0)
