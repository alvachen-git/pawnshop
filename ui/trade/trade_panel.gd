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
var _rounds_value: Label
var _feedback: Label
var _forms: Array[Control] = []

func _ready() -> void:
	super._ready()
	_metrics = HBoxContainer.new()
	_metrics.add_theme_constant_override("separation", 12)
	_column.add_child(_metrics)
	_column.move_child(_metrics, 0)
	_ask_value = _metric("顾客要价")
	_estimate_value = _metric("证据估值")
	_rounds_value = _metric("剩余议价")
	var caption := Label.new()
	caption.text = "收购报价 · 接受后扣款入库"
	caption.add_theme_font_size_override("font_size", 15)
	_column.add_child(caption)
	var row := HBoxContainer.new()
	_column.add_child(row)
	_price = SpinBox.new()
	_price.min_value = 1
	_price.step = 1
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_price)
	_submit = Button.new()
	_submit.text = "正式报价并收购"
	_submit.disabled = true
	_submit.pressed.connect(_offer)
	row.add_child(_submit)
	var pawn_caption := Label.new()
	pawn_caption.text = "活当放款 · 与收购共用议价轮次"
	pawn_caption.add_theme_font_size_override("font_size", 15)
	_column.add_child(pawn_caption)
	var pawn_row := HBoxContainer.new()
	_column.add_child(pawn_row)
	_forms.assign([caption, row, pawn_caption, pawn_row])
	_pawn_price = SpinBox.new()
	_pawn_price.min_value = 1
	_pawn_price.step = 1
	_pawn_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pawn_row.add_child(_pawn_price)
	_pawn_submit = Button.new()
	_pawn_submit.text = "正式报价并活当"
	_pawn_submit.pressed.connect(_pawn)
	pawn_row.add_child(_pawn_submit)
	_column.move_child(_buttons, _column.get_child_count() - 1)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 15)
	_column.add_child(_feedback)
	_column.move_child(_feedback, 2)

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

func render(model: Dictionary) -> void:
	super.render(model)
	for control in _forms: control.visible = not _visit_id.is_empty() and not model.get("pawn_return", false)
	var visual: Dictionary = model.get("visual", {})
	_metrics.visible = not visual.is_empty()
	_feedback.text = visual.get("message", "")
	_feedback.visible = not _feedback.text.is_empty()
	if not visual.is_empty():
		_ask_value.text = str(visual.asking)
		_estimate_value.text = visual.estimate
		_rounds_value.text = "%d 轮" % visual.rounds_left
		_body.text = "%s · %s\n最迟留到 %s\n报价 %d分钟 · 施压 %d分钟\n活当：%s" % [visual.item_name, visual.attitude, visual.deadline, visual.quote_minutes, visual.pressure_minutes, visual.pawn_terms]
		if not String(visual.get("visit_constraint", "")).is_empty(): _body.text += "\n" + String(visual.visit_constraint)
		_body.text += "\n线索未必是毛病，牵强压价可能惹恼客人。"
		if not String(visual.get("bargaining_cue", "")).is_empty(): _body.text += "\n" + String(visual.bargaining_cue)
	_style_bargaining(model)
	_pawn_price.max_value = model.max_input
	_pawn_submit.disabled = not model.get("can_pawn", false)
	if _last_visit != _visit_id or int(_pawn_price.value) == _last_pawn_suggested:
		_pawn_price.value = model.get("pawn_asking", 1)
	_last_pawn_suggested = model.get("pawn_asking", 1)
	_price.max_value = model.max_input
	_submit.disabled = not model.can_offer
	if _last_visit != _visit_id or int(_price.value) == _last_suggested:
		_last_visit = _visit_id
		_price.value = model.asking_price
	_last_suggested = model.asking_price

func _offer() -> void:
	_price.apply()
	intent.emit("offer", _visit_id, "", int(_price.value))

func _style_bargaining(model: Dictionary) -> void:
	# Only this panel uses evidence cards; other IntentPanel layouts stay unchanged.
	var buttons := _buttons.get_children()
	var entries: Array = model.get("buttons", [])
	for index in buttons.size():
		var button := buttons[index] as Button
		button.set_meta("trade_command", entries[index].command)
		button.set_meta("trade_detail", entries[index].detail)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not entries[index].has("evidence"): continue
		var evidence := Label.new()
		evidence.name = "Evidence_" + String(entries[index].detail)
		evidence.text = "已知线索：" + String(entries[index].evidence)
		evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evidence.add_theme_font_size_override("font_size", 14)
		evidence.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buttons.add_child(evidence)
		_buttons.move_child(evidence, button.get_index() + 1)

func _pawn() -> void:
	_pawn_price.apply()
	intent.emit("pawn", _visit_id, "", int(_pawn_price.value))
