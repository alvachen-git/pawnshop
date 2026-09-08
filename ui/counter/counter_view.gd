class_name CounterView
extends Control

signal bell_requested(mode: String, target_id: String)
signal shop_requested
signal customer_action_requested(panel_id: StringName)
signal item_action_requested(panel_id: StringName)
signal inventory_requested
signal ledger_requested
signal background_requested
signal context_opened(kind: StringName)

var _portrait: TextureRect
var _item_image: TextureRect
var _speech: Label
var _speech_panel: PanelContainer
var _customer_hotspot: Button
var _item_hotspot: Button
var _customer_context: PanelContainer
var _item_context: PanelContainer
var _dialogue_action: Button
var _trade_action: Button
var _appraisal_action: Button
var _active_id := ""
var bell


func _ready() -> void:
	%CounterMessage.hide()
	bell = preload("res://ui/counter/counter_bell.gd").new()
	bell.name = "CounterBell"
	bell.z_index = 5
	add_child(bell)
	_bounds(bell, 0.70, 0.555, 0.765, 0.725)
	bell.rung.connect(bell_requested.emit)
	var backdrop := _make_hotspot("CounterBackdrop", 0.0, 0.0, 1.0, 1.0, "")
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.mouse_default_cursor_shape = Control.CURSOR_ARROW
	backdrop.pressed.connect(_on_background_pressed)
	backdrop.z_index = 1

	_portrait = TextureRect.new()
	_portrait.name = "CustomerPortrait"
	_portrait.unique_name_in_owner = true
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.z_index = 2
	add_child(_portrait)
	_bounds(_portrait, 0.315, 0.027, 0.68, 0.592)

	_item_image = TextureRect.new()
	_item_image.name = "CounterItemImage"
	_item_image.unique_name_in_owner = true
	_item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_image.z_index = 2
	add_child(_item_image)
	_bounds(_item_image, 0.425, 0.62, 0.595, 0.81)

	var shop_hotspot := _make_hotspot("ShopSignHotspot", 0.012, 0.012, 0.167, 0.095, "查看营业安排 · 不耗时")
	shop_hotspot.pressed.connect(shop_requested.emit)
	_customer_hotspot = _make_hotspot("CustomerHotspot", 0.325, 0.025, 0.665, 0.57, "与当前客人交谈或交易 · 不耗时")
	_customer_hotspot.pressed.connect(_toggle_customer_context)
	_item_hotspot = _make_hotspot("ItemHotspot", 0.425, 0.615, 0.595, 0.815, "选择柜台货物 · 不耗时")
	_item_hotspot.pressed.connect(_toggle_item_context)
	var inventory_hotspot := _make_hotspot("InventoryHotspot", 0.02, 0.24, 0.165, 0.62, "查看库存柜 · 不耗时")
	inventory_hotspot.pressed.connect(inventory_requested.emit)
	var ledger_hotspot := _make_hotspot("LedgerHotspot", 0.77, 0.68, 0.905, 0.97, "翻看账本 · 不耗时")
	ledger_hotspot.pressed.connect(ledger_requested.emit)

	_customer_context = _make_context("CustomerContext", 0.40, 0.555, 0.64, 0.645)
	var customer_row := HBoxContainer.new()
	customer_row.add_theme_constant_override("separation", 6)
	_customer_context.add_child(customer_row)
	_dialogue_action = _make_context_button("DialogueContextButton", "对话", &"dialogue")
	_trade_action = _make_context_button("TradeContextButton", "交易", &"trade")
	customer_row.add_child(_dialogue_action)
	customer_row.add_child(_trade_action)

	_item_context = _make_context("ItemContext", 0.595, 0.70, 0.70, 0.79)
	_appraisal_action = _make_context_button("AppraisalContextButton", "鉴定", &"appraisal", false)
	_item_context.add_child(_appraisal_action)

	_speech_panel = PanelContainer.new()
	_speech_panel.name = "CustomerSpeech"
	_speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_panel.z_index = 3
	add_child(_speech_panel)
	_bounds(_speech_panel, 0.17, 0.07, 0.355, 0.27)
	_speech_panel.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_speech_panel.add_child(margin)
	_speech = Label.new()
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.max_lines_visible = 4
	_speech.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speech.add_theme_font_size_override("font_size", 19)
	margin.add_child(_speech)
	_build_painted_controls()
	move_child(bell, get_child_count() - 1)



func _build_painted_controls() -> void:
	for entry in [["InventoryButton", "库存", 0.80], ["LedgerButton", "账本", 0.87]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.z_index = 5
		button.add_theme_font_size_override("font_size", 19)
		button.tooltip_text = "查看" + entry[1] + " · 不耗时"
		CounterTheme.style_paper_button(button)
		add_child(button)
		_bounds(button, 0.925, entry[2], 0.992, entry[2] + 0.064)
		if entry[0] == "InventoryButton": button.pressed.connect(inventory_requested.emit)
		else: button.pressed.connect(ledger_requested.emit)
	$CustomerPanel.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	$CustomerPanel.z_index = 3
	for label in [%ShopTitle, %CustomerText, %ItemText, _speech]:
		label.add_theme_font_override("font", CounterTheme.display_font())
	for node in [$CustomerPanel, $CustomerPanel/CustomerMargin, %CustomerText]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_hotspot(name_value: String, left: float, top: float, right: float, bottom: float, tooltip: String) -> Button:
	var button := Button.new()
	button.name = name_value
	button.unique_name_in_owner = true
	button.text = ""
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", CounterTheme.box("00000000", "00000000", 0, 0))
	button.add_theme_stylebox_override("hover", _outline_style("b78345", 2))
	button.add_theme_stylebox_override("pressed", _outline_style("d8ad6d", 3, "33281f44"))
	button.add_theme_stylebox_override("focus", _outline_style("e1bd7c", 3))
	button.z_index = 5
	add_child(button)
	_bounds(button, left, top, right, bottom)
	return button


func _outline_style(edge: String, width: int, fill := "00000000") -> StyleBoxFlat:
	var style := CounterTheme.box(fill, edge, 0, 0)
	style.set_border_width_all(width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _make_context(name_value: String, left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_value
	panel.unique_name_in_owner = true
	panel.visible = false
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.z_index = 10
	add_child(panel)
	_bounds(panel, left, top, right, bottom)
	return panel


func _make_context_button(name_value: String, label: String, panel_id: StringName, customer := true) -> Button:
	var button := Button.new()
	button.name = name_value
	button.unique_name_in_owner = true
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CounterTheme.style_paper_button(button)
	button.add_theme_font_size_override("font_size", 20)
	if customer:
		button.pressed.connect(_on_customer_action.bind(panel_id))
	else:
		button.pressed.connect(_on_item_action.bind(panel_id))
	return button


func _bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom


func render(model: Dictionary) -> void:
	%CustomerText.text = model.customer
	%ItemText.text = model.item
	%CounterMessage.text = ""
	%CounterMessage.hide()
	var visual: Dictionary = model.get("visual", {})
	var current_active_id := String(model.get("active_id", ""))
	if current_active_id != _active_id:
		dismiss_contexts()
	_active_id = current_active_id
	var active := not _active_id.is_empty()
	var context_actions: Dictionary = model.get("context_actions", {})
	var customer_actions: Array = context_actions.get("customer", [])
	var item_actions: Array = context_actions.get("item", [])
	_customer_hotspot.visible = active and not customer_actions.is_empty()
	_item_hotspot.visible = active and not item_actions.is_empty()
	_apply_action(_dialogue_action, customer_actions, &"dialogue")
	_apply_action(_trade_action, customer_actions, &"trade")
	_apply_action(_appraisal_action, item_actions, &"appraisal")
	if not _customer_hotspot.visible:
		_customer_context.hide()
	if not _item_hotspot.visible:
		_item_context.hide()

	_portrait.texture = CounterVisualCatalog.portrait(visual.get("portrait_asset", ""), visual.get("customer_id", ""))
	_portrait.material = CounterVisualCatalog.portrait_material(_portrait.texture)
	_portrait.visible = active and _portrait.texture != null
	_item_image.texture = CounterVisualCatalog.front(visual.get("item_asset", ""), model.appraisal.get("images", []))
	_item_image.visible = active and _item_image.texture != null
	_speech_panel.visible = active and not visual.is_empty()
	if not visual.is_empty():
		%CustomerText.text = "%s\n%s\n最迟留到 %s" % [visual.customer_name, visual.attitude, visual.deadline]
		if visual.get("pawn_return", false): %CustomerText.text = visual.customer_name + "\n持票回访 · 等候验票"
		_speech.text = visual.introduction
		if not visual.speech.is_empty():
			_speech.text = visual.speech.back().answer
		_speech.tooltip_text = _speech.text
		%ItemText.text = "%s\n已知估值 %s 银元\n已见线索 %d 条" % [visual.item_name, visual.estimate, visual.clues.size()]
	$Room.has_customer = active and _portrait.texture == null
	$Room.has_item = active and _item_image.texture == null
	$Room.queue_redraw()


func _apply_action(button: Button, actions: Array, action_id: StringName) -> void:
	button.visible = false
	for entry in actions:
		if StringName(entry.get("id", "")) != action_id:
			continue
		button.text = String(entry.get("label", button.text))
		button.disabled = not bool(entry.get("enabled", true))
		button.tooltip_text = String(entry.get("reason", ""))
		button.visible = true
		return


func _toggle_customer_context() -> void:
	if not _customer_hotspot.visible:
		return
	var show_context := not _customer_context.visible
	dismiss_contexts()
	_customer_context.visible = show_context
	if show_context:
		context_opened.emit(&"customer")
		_dialogue_action.call_deferred("grab_focus")


func _toggle_item_context() -> void:
	if not _item_hotspot.visible:
		return
	var show_context := not _item_context.visible
	dismiss_contexts()
	_item_context.visible = show_context
	if show_context:
		context_opened.emit(&"item")
		_appraisal_action.call_deferred("grab_focus")


func _on_customer_action(panel_id: StringName) -> void:
	dismiss_contexts()
	customer_action_requested.emit(panel_id)


func _on_item_action(panel_id: StringName) -> void:
	dismiss_contexts()
	item_action_requested.emit(panel_id)


func _on_background_pressed() -> void:
	dismiss_contexts()
	background_requested.emit()


func dismiss_contexts() -> bool:
	var dismissed := _customer_context.visible or _item_context.visible
	_customer_context.hide()
	_item_context.hide()
	return dismissed


func focus_hotspot(kind: StringName) -> void:
	var target := get_hotspot(kind)
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func get_hotspot(kind: StringName) -> Button:
	var targets := {
		&"shop": get_node("ShopSignHotspot"),
		&"customer": _customer_hotspot,
		&"item": _item_hotspot,
		&"inventory": get_node("InventoryHotspot"),
		&"ledger": get_node("LedgerHotspot"),
	}
	return targets.get(kind) as Button


func set_counter_message(message: String) -> void:
	%CounterMessage.text = ""
	%CounterMessage.hide()


func set_atmosphere(mode: int, preview: bool, intrusion: bool, haunting: bool, dead: bool) -> void:
	$Room.atmosphere = mode
	bell.atmosphere = mode
	$Room.smoke_wrong = intrusion or (preview and mode == 1)
	$Room.lamp_wrong = haunting or (preview and mode == 2)
	$Room.lamp_dead = dead
	_portrait.modulate = [Color.WHITE, Color("9aaba9"), Color("b3c9ce")][mode]
	_item_image.modulate = [Color.WHITE, Color("b0b9b5"), Color("c1d2d7")][mode]
	$Room.queue_redraw()
	%AtmosphereLabel.text = ["灯火初上", "夜深了", "禁时 · 鬼市"][mode]
	if preview:
		%AtmosphereLabel.text = "美术预览 · " + ["正常营业", "深夜异常", "禁时鬼市"][mode]
	%AtmosphereLabel.tooltip_text = "仅切换视觉，不推进时间、不改变规则或存档。" if preview else ""
