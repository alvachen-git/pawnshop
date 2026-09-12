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
var _feedback_heading: Label
var _price_change: Label
var _reaction_history: VBoxContainer
const PRICE_DOWN := Color("315f48")
const PRICE_UP := Color("8d2a24")
const PRICE_UNCHANGED := Color("302a24")
var _forms: Array[Control] = []
var _purchase_mode: Button
var _pawn_mode: Button
var _bargain_toggle: Button
var _bargain_popup: BargainDialog
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
	_feedback.add_theme_font_size_override("font_size", 17)
	_column.add_child(_feedback)
	_column.move_child(_feedback, 0)
	_feedback_heading = Label.new()
	_feedback_heading.add_theme_font_size_override("font_size", 14)
	_column.add_child(_feedback_heading)
	_column.move_child(_feedback_heading, 0)
	_price_change = Label.new()
	_price_change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price_change.add_theme_font_size_override("font_size", 17)
	_column.add_child(_price_change)
	_column.move_child(_price_change, 2)
	_reaction_history = VBoxContainer.new()
	_reaction_history.add_theme_constant_override("separation", 8)
	_column.add_child(_reaction_history)

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
	# Replies scroll independently of the transaction controls.
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
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _bargain_popup.hide()
	)


func _metric(title: String) -> Label:
	var column := HBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metrics.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	_bargain_popup = BargainDialog.new()
	_bargain_popup.name = "BargainPopup"
	layer.add_child(_bargain_popup)
	_bargain_scroll = _bargain_popup.scroll
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 10)
	_bargain_scroll.add_child(_buttons)
	_bargain_popup.choices = _buttons
	_bargain_popup.dismissed.connect(func() -> void:
		if _bargain_toggle.is_visible_in_tree(): _bargain_toggle.grab_focus()
	)


func render(model: Dictionary) -> void:
	_bargain_popup.hide()
	_content_scroll.scroll_vertical = 0
	super.render(model)
	var pawn_return := bool(model.get("pawn_return", false))
	for control in _forms:
		control.visible = not _visit_id.is_empty() and not pawn_return
	var visual: Dictionary = model.get("visual", {})
	_metrics.visible = not visual.is_empty() and not pawn_return
	_body.visible = visual.is_empty() or pawn_return
	_render_reactions(model.get("reactions", []), visual, pawn_return)
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
	# Keep actionable pawn context and supernatural warnings from current main,
	# without bringing back the duplicated ordinary item/appraisal summary.
	var context_lines: PackedStringArray = []
	var pawn_background := String(visual.get("pawn_background", "")).strip_edges()
	if not pawn_background.is_empty(): context_lines.append(pawn_background)
	if not String(model.get("night_policy", "")).is_empty():
		context_lines.append(String(visual.get("visit_constraint", "")).strip_edges())
	_body.text = "\n".join(context_lines)
	_body.visible = not _body.text.is_empty()
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


func _render_reactions(rows: Array, visual: Dictionary, pawn_return: bool) -> void:
	for child in _reaction_history.get_children():
		_reaction_history.remove_child(child)
		child.queue_free()
	var active := not visual.is_empty() and not pawn_return
	_feedback.visible = active
	_feedback_heading.visible = active
	_price_change.visible = active and not rows.is_empty()
	_reaction_history.visible = active and rows.size() > 1
	_ask_value.add_theme_color_override("font_color", PRICE_UNCHANGED)
	if not active: return
	_feedback_heading.text = "刚才的回应" if not rows.is_empty() else "客人态度"
	_feedback.text = _reaction_text(rows[0]) if not rows.is_empty() else String(visual.get("attitude", "尚愿意交谈"))
	if rows.is_empty(): return
	_style_price_change(_price_change, rows[0])
	_ask_value.add_theme_color_override("font_color", _change_color(rows[0]))
	if rows.size() <= 1: return
	_reaction_history.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "先前的回应"
	heading.add_theme_font_size_override("font_size", 14)
	_reaction_history.add_child(heading)
	for index in range(1, rows.size()):
		var reply := Label.new()
		reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reply.add_theme_font_size_override("font_size", 15)
		reply.text = _reaction_text(rows[index])
		_reaction_history.add_child(reply)
		var change := Label.new()
		change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		change.add_theme_font_size_override("font_size", 15)
		_style_price_change(change, rows[index])
		_reaction_history.add_child(change)

func _reaction_text(row: Dictionary) -> String:
	var text := _player_feedback(String(row.message))
	# The public price transition gets its own accessible, color-coded line.
	return text.replace("要价 %d → %d 银元。" % [row.before, row.after], "").strip_edges()

func _change_color(row: Dictionary) -> Color:
	return PRICE_DOWN if row.after < row.before else PRICE_UP if row.after > row.before else PRICE_UNCHANGED

func _style_price_change(label: Label, row: Dictionary) -> void:
	label.text = "要价未变 · %d 银元" % row.after if row.before == row.after else "%s · %d → %d 银元" % ["要价调低" if row.after < row.before else "要价调高", row.before, row.after]
	label.add_theme_color_override("font_color", _change_color(row))


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
		button.custom_minimum_size.y = 52
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
			evidence.add_theme_font_size_override("font_size", 16)
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
	var visual: Dictionary = _availability_model.get("visual", {})
	_bargain_popup.present("%s · 顾客要价 %s 银元 · 证据估值 %s" % [visual.get("item_name", ""), _ask_value.text, _estimate_value.text])


func _emit_intent(command: String, visit_id: String, detail: String) -> void:
	_bargain_popup.hide()
	super._emit_intent(command, visit_id, detail)


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
