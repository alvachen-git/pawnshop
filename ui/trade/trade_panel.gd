class_name TradePanel
extends IntentPanel

var _price: SpinBox
var _submit: Button
var _last_visit := ""
var _last_suggested := 0
var _pawn_price: SpinBox
var _pawn_submit: Button
var _last_pawn_suggested := 0

func _ready() -> void:
	super._ready()
	var caption := Label.new()
	caption.text = "你的报价（可修改；接受即扣款入库）"
	caption.add_theme_font_size_override("font_size", 13)
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
	pawn_caption.text = "活当放款报价（与收购共用议价轮次）"
	pawn_caption.add_theme_font_size_override("font_size", 13)
	_column.add_child(pawn_caption)
	var pawn_row := HBoxContainer.new()
	_column.add_child(pawn_row)
	_pawn_price = SpinBox.new()
	_pawn_price.min_value = 1
	_pawn_price.step = 1
	_pawn_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pawn_row.add_child(_pawn_price)
	_pawn_submit = Button.new()
	_pawn_submit.text = "正式报价并活当"
	_pawn_submit.pressed.connect(_pawn)
	pawn_row.add_child(_pawn_submit)

func render(model: Dictionary) -> void:
	super.render(model)
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

func _pawn() -> void:
	_pawn_price.apply()
	intent.emit("pawn", _visit_id, "", int(_pawn_price.value))
