class_name TradeReceiptView
extends Control

signal dismissed(destination: String)
var _title: Label
var _item: Label
var _amount: Label
var _cash: Label
var _clock: Label
var _note: Label
var _detail: Label
var _picture: TextureRect
var _primary: Button
var _secondary: Button
var _paper: PanelContainer
var _destination := ""
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Counter children use z indices up to 10; both shade and paper must
	# cover them when the next customer is already waiting behind a receipt.
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("171611b8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_paper = PanelContainer.new()
	_paper.custom_minimum_size.x = 590
	_paper.add_theme_stylebox_override("panel", CounterTheme.box("e5d5b3", "a38b63", 30, 24))
	center.add_child(_paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_paper.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var caption := _label(top, "当 铺 · 成 交 凭 据", 16)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock = _label(top, "", 14)
	column.add_child(HSeparator.new())
	_title = _label(column, "", 32)
	_title.add_theme_color_override("font_color", Color("425440"))
	var goods := HBoxContainer.new()
	goods.add_theme_constant_override("separation", 22)
	column.add_child(goods)
	_picture = TextureRect.new()
	_picture.custom_minimum_size = Vector2(110, 106)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goods.add_child(_picture)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 7)
	goods.add_child(info)
	_item = _label(info, "", 24)
	_note = _label(info, "", 17)
	_amount = _label(column, "", 37)
	_cash = _label(column, "", 18)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "ReceiptDetails"
	detail_scroll.custom_minimum_size.y = 120
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(detail_scroll)
	_detail = _label(detail_scroll, "", 16)
	column.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	_secondary = Button.new()
	_secondary.text = "查看库存"
	_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary.custom_minimum_size.y = 48
	_secondary.add_theme_stylebox_override("normal", CounterTheme.box("dfcdaa", "897557", 14, 10))
	_secondary.add_theme_color_override("font_color", Color("493c30"))
	_secondary.pressed.connect(func() -> void: dismiss(_destination))
	actions.add_child(_secondary)
	_primary = Button.new()
	_primary.text = "收好凭据"
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.custom_minimum_size.y = 48
	_primary.pressed.connect(func() -> void: dismiss(""))
	actions.add_child(_primary)
	for button in [_primary, _secondary]:
		var other: Button = _secondary if button == _primary else _primary
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		for side in ["left", "right", "top", "bottom"]: button.set("focus_neighbor_" + side, button.get_path_to(other))
	hide()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func present(receipt: Dictionary) -> void:
	_title.text = receipt.title
	_item.text = receipt.item
	_clock.text = receipt.clock
	_note.text = receipt.note
	_detail.text = receipt.detail
	_detail.visible = not receipt.detail.is_empty()
	_detail.get_parent().visible = _detail.visible
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0
	_amount.text = "%s  %d 银元" % ["实付" if receipt.amount < 0 else "实收", absi(receipt.amount)]
	_cash.text = "现银  %d → %d 银元" % [receipt.before, receipt.after]
	_picture.texture = CounterVisualCatalog.front(receipt.item_asset, receipt.images)
	_picture.visible = _picture.texture != null
	_destination = receipt.destination
	_secondary.text = "查看当票" if receipt.destination == "ledger" else "查看库存"
	_secondary.visible = receipt.can_inspect
	# Keep keyboard focus inside this information page, including when details
	# are unavailable because a story/risk event needs attention next.
	_primary.focus_next = _primary.get_path_to(_secondary if _secondary.visible else _primary)
	_primary.focus_previous = _primary.focus_next
	for side in ["left", "right", "top", "bottom"]: _primary.set("focus_neighbor_" + side, _primary.focus_next)
	show()
	_primary.grab_focus()
	if _tween != null: _tween.kill()
	_paper.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_paper, "modulate:a", 1.0, 0.16)

func dismiss(destination: String = "") -> void:
	if not visible: return
	hide()
	dismissed.emit(destination)
