class_name TradePanel
extends IntentPanel

var _price: SpinBox
var _submit: Button
var _last_visit := ""
var _last_suggested := 0
var _pawn_price: SpinBox
var _pawn_submit: Button
var _last_pawn_suggested := 0
var _metrics: HBoxContainer
var _ask_value: Label
var _estimate_value: Label
var _feedback: Label
var _forms: Array[Control] = []
var _purchase_mode: Button
var _pawn_mode: Button
var _bargain_toggle: Button
var _bargain_popup: PanelContainer
var _bargain_scroll: ScrollContainer
var _reject: Button
var _mode := "offer"
var _reject_command := ""
var _reject_detail := ""
var _availability: Label
var _terms: Label
var _availability_model: Dictionary = {}
var _amount_caption: Label
var _content_scroll: ScrollContainer


func _ready() -> void:
	super._ready()
	_column.add_theme_constant_override("separation", 8)
	_metrics = HBoxContainer.new()
	_metrics.add_theme_constant_override("separation", 28)
	_column.add_child(_metrics)
	_column.move_child(_metrics, 0)
	_ask_value = _metric("顾客要价")
	_estimate_value = _metric("证据估值")

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 15)
	_column.add_child(_feedback)
	_column.move_child(_feedback, 2)

	var separator := HSeparator.new()
	_column.add_child(separator)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 0)
	_column.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false
	_purchase_mode = _mode_button("收购", mode_group, "offer")
	_pawn_mode = _mode_button("活当", mode_group, "pawn")
	mode_row.add_child(_purchase_mode)
	mode_row.add_child(_pawn_mode)
	_terms = Label.new()
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terms.add_theme_font_size_override("font_size", 14)
	_column.add_child(_terms)
	_availability = Label.new()
	_availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_availability.add_theme_font_size_override("font_size", 14)
	_column.add_child(_availability)

	_bargain_toggle = Button.new()
	_bargain_toggle.name = "BargainMenuButton"
	_bargain_toggle.text = "商量价钱"
	_bargain_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bargain_toggle.custom_minimum_size.y = 40
	_bargain_toggle.pressed.connect(_toggle_bargain_menu)
	_column.add_child(_bargain_toggle)
	_build_bargain_popup()

	var amount_caption := Label.new()
	_amount_caption = amount_caption
	amount_caption.text = "出价（银元）"
	amount_caption.add_theme_font_size_override("font_size", 15)
	_column.add_child(amount_caption)
	var amount_row := HBoxContainer.new()
	_column.add_child(amount_row)
	_price = _amount_input()
	_pawn_price = _amount_input()
	amount_row.add_child(_price)
	amount_row.add_child(_pawn_price)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	_column.add_child(action_row)
	_submit = _primary_button("正式报价并收购", _offer)
	_pawn_submit = _primary_button("正式报价并活当", _pawn)
	_reject = Button.new()
	_reject.name = "RejectTradeButton"
	_reject.text = "拒收"
	_reject.custom_minimum_size = Vector2(118, 44)
	_reject.pressed.connect(_reject_offer)
	action_row.add_child(_submit)
	action_row.add_child(_pawn_submit)
	action_row.add_child(_reject)
	_forms.assign([separator, mode_row, _terms, _availability, _bargain_toggle, amount_caption, amount_row, action_row])
	_price.value_changed.connect(func(_value: float) -> void: _refresh_amount_availability())
	_pawn_price.value_changed.connect(func(_value: float) -> void: _refresh_amount_availability())
	# Evidence and replies scroll independently of the transaction controls.
	_content_scroll = _column.get_parent() as ScrollContainer
	var margin := _content_scroll.get_parent()
	margin.remove_child(_content_scroll)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	layout.add_child(_content_scroll)
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	layout.add_child(form)
	for control in [separator, mode_row, _terms, _bargain_toggle, amount_caption, amount_row, action_row]:
		control.reparent(form)
	_sync_mode()


func _metric(title: String) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metrics.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.add_theme_font_size_override("font_size", 14)
	column.add_child(caption)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 23)
	column.add_child(value)
	return value


func _mode_button(title: String, group: ButtonGroup, mode: String) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_mode.bind(mode))
	return button


func _amount_input() -> SpinBox:
	var input := SpinBox.new()
	input.min_value = 1
	input.step = 1
	input.custom_minimum_size.y = 44
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return input


func _primary_button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.disabled = true
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _build_bargain_popup() -> void:
	_column.remove_child(_buttons)
	_bargain_popup = PanelContainer.new()
	_bargain_popup.name = "BargainPopup"
	_bargain_popup.visible = false
	_bargain_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bargain_popup.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	_column.add_child(_bargain_popup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_bargain_popup.add_child(margin)
	_bargain_scroll = ScrollContainer.new()
	_bargain_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bargain_scroll.follow_focus = true
	margin.add_child(_bargain_scroll)
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 6)
	_bargain_scroll.add_child(_buttons)


func render(model: Dictionary) -> void:
	_bargain_popup.hide()
	_content_scroll.scroll_vertical = 0
	super.render(model)
	var pawn_return := bool(model.get("pawn_return", false))
	for control in _forms:
		control.visible = not _visit_id.is_empty() and not pawn_return
	var visual: Dictionary = model.get("visual", {})
	_metrics.visible = not visual.is_empty() and not pawn_return
	_feedback.text = _player_feedback(String(visual.get("message", "")))
	_feedback.visible = not _feedback.text.is_empty()
	if pawn_return:
		_move_buttons_to(_column)
		_buttons.show()
		return
	_move_buttons_to(_bargain_scroll)
	_buttons.show()
	if visual.is_empty():
		_bargain_toggle.hide()
		_reject.hide()
		return

	var new_visit := _last_visit != _visit_id
	if new_visit:
		_mode = "offer"
	_ask_value.text = str(visual.asking)
	_estimate_value.text = visual.estimate
	_body.text = _trade_summary(visual)
	if _feedback.visible and _body.text.contains(_feedback.text.strip_edges()):
		_feedback.hide()
	_style_bargaining(model)

	_pawn_price.max_value = model.max_input
	_pawn_submit.disabled = not model.get("can_pawn", false)
	if new_visit or int(_pawn_price.value) == _last_pawn_suggested:
		_pawn_price.value = model.get("pawn_asking", 1)
	_last_pawn_suggested = model.get("pawn_asking", 1)
	_price.max_value = model.max_input
	_submit.disabled = not model.can_offer
	if new_visit or int(_price.value) == _last_suggested:
		_price.value = model.asking_price
	_last_suggested = model.asking_price
	_last_visit = _visit_id
	_amount_caption.text = "出价（银元）"

	var pawn_terms := String(visual.get("pawn_terms", ""))
	_pawn_mode.text = "活当"
	_pawn_mode.disabled = not visual.get("pawn_allowed", pawn_terms != "此客不办理活当")
	_purchase_mode.disabled = not visual.get("offer_allowed", true)
	_terms.text = pawn_terms if not _pawn_mode.disabled else "不接受活当：本次只按收购交货。"
	if _purchase_mode.disabled: _terms.text += "\n不接受收购：客人只愿押物，日后赎回。"
	_pawn_submit.tooltip_text = visual.get("pawn_reason", "")
	_submit.tooltip_text = visual.get("offer_reason", "")
	_availability.text = ""
	for pair in [["收购", "offer_reason", _purchase_mode.disabled], ["活当", "pawn_reason", _pawn_mode.disabled]]:
		if not pair[2] and not String(visual.get(pair[1], "")).is_empty():
			_availability.text += "%s暂不可用：%s\n" % [pair[0], visual[pair[1]]]
	_availability.visible = not _availability.text.is_empty()
	if _mode == "pawn" and _pawn_mode.disabled:
		_mode = "offer"
	if _mode == "offer" and _purchase_mode.disabled and not _pawn_mode.disabled: _mode = "pawn"
	_availability_model = model
	_refresh_amount_availability()
	_sync_mode()
	if not String(model.get("night_policy", "")).is_empty():
		_pawn_mode.hide()
		_terms.hide()
	else:
		_pawn_mode.show()

func _refresh_amount_availability() -> void:
	if _availability_model.is_empty(): return
	var visual: Dictionary = _availability_model.visual
	var lines: PackedStringArray = []
	for entry in [["收购", "offer_reason", _price, _submit, _purchase_mode.disabled, "can_offer"], ["活当", "pawn_reason", _pawn_price, _pawn_submit, _pawn_mode.disabled, "can_pawn"]]:
		var reason := String(visual.get(entry[1], ""))
		if reason.is_empty() and int(entry[2].value) > int(visual.get("cash", 1000000)): reason = "现银不足，未提交报价。"
		entry[3].tooltip_text = reason
		entry[3].disabled = not _availability_model.get(entry[5], false) or not reason.is_empty()
		if not entry[4] and not reason.is_empty(): lines.append("%s暂不可用：%s" % [entry[0], reason])
	_availability.text = "\n".join(lines)
	_availability.visible = not lines.is_empty()


func _trade_summary(visual: Dictionary) -> String:
	var evidence: Array[String] = []
	for clue in visual.get("clues", []):
		var text := String(clue.get("text", "")).strip_edges()
		if not text.is_empty() and text not in evidence:
			evidence.append(text)
	if evidence.is_empty():
		evidence.append("尚未掌到足够线索。")
	var summary := "%s · %s · %s\n掌眼所见\n%s" % [visual.item_name, visual.get("intent", ""), visual.attitude, "\n".join(evidence)]
	for key in ["pawn_background", "visit_constraint"]:
		var detail := String(visual.get(key, "")).strip_edges()
		if not detail.is_empty(): summary += "\n" + detail
	return summary


func _player_feedback(message: String) -> String:
	if message == "操作完成。":
		return ""
	return message.replace("耐心耗尽，顾客离场。", "客人不愿再谈，已经离场。").replace("议价轮次用尽，顾客离场。", "价钱没谈拢，客人已经离场。")


func _style_bargaining(model: Dictionary) -> void:
	_reject_command = ""
	_reject_detail = ""
	var bargain_count := 0
	var buttons := _buttons.get_children()
	var entries: Array = model.get("buttons", [])
	for index in mini(buttons.size(), entries.size()):
		var button := buttons[index] as Button
		var entry: Dictionary = entries[index]
		button.set_meta("trade_command", entry.command)
		button.set_meta("trade_detail", entry.detail)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _compact_action_label(String(entry.label))
		if entry.command == "reject":
			button.hide()
			_reject_command = entry.command
			_reject_detail = entry.detail
			_reject.text = String(entry.label).replace("拒绝收货", "拒收")
			_reject.disabled = not bool(entry.enabled)
			_reject.tooltip_text = String(entry.reason)
			continue
		button.show()
		bargain_count += 1
		if entry.has("evidence"):
			var evidence := Label.new()
			evidence.name = "Evidence_" + String(entry.detail)
			evidence.text = "已知线索：" + String(entry.evidence)
			evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			evidence.add_theme_font_size_override("font_size", 14)
			evidence.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_buttons.add_child(evidence)
			_buttons.move_child(evidence, button.get_index() + 1)
	_bargain_toggle.visible = bargain_count > 0
	_bargain_toggle.disabled = bargain_count == 0
	_reject.visible = not _reject_command.is_empty()


func _compact_action_label(label: String) -> String:
	return label.replace(" · 议价一轮", "")


func _select_mode(mode: String) -> void:
	_mode = mode
	_bargain_popup.hide()
	_content_scroll.scroll_vertical = 0
	_sync_mode()


func _sync_mode() -> void:
	var pawn_selected := _mode == "pawn"
	_purchase_mode.button_pressed = not pawn_selected
	_pawn_mode.button_pressed = pawn_selected
	_price.visible = not pawn_selected
	_submit.visible = not pawn_selected
	_pawn_price.visible = pawn_selected
	_pawn_submit.visible = pawn_selected


func _toggle_bargain_menu() -> void:
	if _bargain_popup.visible:
		_bargain_popup.hide()
		_content_scroll.scroll_vertical = 0
	else:
		open_bargain_menu()


func open_bargain_menu() -> void:
	if not _bargain_toggle.is_visible_in_tree() or _bargain_toggle.disabled:
		return
	var popup_height := _bargain_menu_height()
	_bargain_popup.custom_minimum_size.y = popup_height
	_bargain_scroll.custom_minimum_size.y = maxf(0.0, popup_height - 16.0)
	_bargain_popup.show()
	_reveal_bargain_menu.call_deferred()


func _reveal_bargain_menu() -> void:
	await get_tree().process_frame
	if _bargain_popup.visible:
		_content_scroll.ensure_control_visible(_bargain_popup)


func _bargain_menu_height() -> float:
	var height := 16.0
	var separation := float(_buttons.get_theme_constant("separation"))
	var visible_count := 0
	for child in _buttons.get_children():
		if child is Control and child.visible:
			height += 42.0 if child is Button else 34.0
			visible_count += 1
	if visible_count > 1:
		height += separation * float(visible_count - 1)
	return clampf(height, 64.0, maxf(64.0, minf(220.0, _content_scroll.size.y)))


func _move_buttons_to(parent: Control) -> void:
	if _buttons.get_parent() == parent:
		return
	_buttons.reparent(parent)


func _offer() -> void:
	_price.apply()
	intent.emit("offer", _visit_id, "", int(_price.value))


func _pawn() -> void:
	_pawn_price.apply()
	intent.emit("pawn", _visit_id, "", int(_pawn_price.value))


func _reject_offer() -> void:
	if _reject_command.is_empty():
		return
	intent.emit(_reject_command, _visit_id, _reject_detail, 0)
