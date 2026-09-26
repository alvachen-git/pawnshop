class_name LuSaleView
extends Control

signal dismissed
signal submitted(buyer_id: String, item_ids: Array, pairs: Array)

var buyer_id := "buyer_lu"
var _model: Dictionary = {}
var _buyer: Dictionary = {}
var _visual: Dictionary = {}
var _selected: Array = []
var _pairs: Array = []
var _token := ""
var _market := ""
var _page := 0
var _only_saleable := false
var _details := false
var _error := ""
var _canvas: Control
var _close: Button
var _submit: Button
var _total: Label
var _preview: Dictionary = {}

func _ready() -> void:
	theme = CounterTheme.build()
	z_index = 14
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit)
	hide()

func present(inventory: Dictionary, target_buyer := "buyer_lu") -> void:
	if buyer_id != target_buyer: reset_draft()
	buyer_id = target_buyer
	_error = ""
	render(inventory)
	show()
	_close.grab_focus()

func render(inventory: Dictionary) -> void:
	_model = inventory.get("sales", {})
	_buyer = {}
	for row in _model.get("buyers", []):
		if row.id == buyer_id: _buyer = row
	var draft_key: String = _buyer.get("draft_key", "") if _buyer.get("preopen", false) else _model.get("market_id", "")
	if _token != _model.get("run_token", "") or _market != draft_key: reset_draft()
	_token = _model.get("run_token", "")
	_market = draft_key
	_visual = {}
	for row in inventory.get("visual", {}).get("stock", []): _visual[row.id] = row
	_rebuild()

func reset_draft() -> void:
	_selected.clear()
	_pairs.clear()
	_page = 0
	_details = false
	_error = ""

func show_error(message: String) -> void:
	_error = message
	_rebuild()

func _fit() -> void:
	if _canvas == null: return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1280, 720) * factor) / 2.0

func _place(node: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _label(parent: Node, value: String, rect: Rect2, font_size := 20, ink := Color("302a24")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", CounterTheme.display_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, parent, rect)
	return label

func _button(parent: Node, value: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	CounterTheme.style_paper_button(button)
	button.add_theme_font_size_override("font_size", 19)
	_place(button, parent, rect)
	button.pressed.connect(callback)
	return button

func _paper(parent: Node, rect: Rect2) -> Panel:
	var paper := Panel.new()
	paper.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(paper, parent, rect)
	return paper

func _rule(parent: Node, y: float) -> void:
	var rule := HSeparator.new()
	_place(rule, parent, Rect2(25, y, 358, 2))

func _check(parent: Node, value: String, rect: Rect2, checked: bool, callback: Callable) -> Button:
	var check := Button.new()
	check.toggle_mode = true
	check.text = value
	check.icon = get_theme_icon("checked" if checked else "unchecked", "CheckBox")
	var icon_tint := _selection_tint(checked)
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		check.add_theme_color_override("icon_" + state + "_color", icon_tint)
	check.add_theme_constant_override("h_separation", 8)
	check.accessibility_name = value
	check.add_theme_font_override("font", CounterTheme.display_font())
	check.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "disabled"]:
		check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		check.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color("f2e0bb"))
	check.set_pressed_no_signal(checked)
	_place(check, parent, rect)
	check.toggled.connect(callback)
	return check

func _selection_tint(checked: bool) -> Color:
	# Godot's unchecked asset is near-black at half opacity; compensate for
	# those source pixels so both native icons read as the same warm paper.
	return Color("e8c294") if checked else Color(8.4, 7.4, 5.8, 1.9)

func _rebuild(focus_name := "") -> void:
	if _canvas != null:
		remove_child(_canvas)
		_canvas.queue_free()
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	_fit()
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/art04/counter_room.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(backdrop, _canvas, Rect2(0, 0, 1280, 648))
	var available: Array = []
	for row in _buyer.get("stock", []):
		if row.reason.is_empty(): available.append(row.id)
	_selected = _selected.filter(func(id: String) -> bool: return id in available)
	_pairs = _pairs.filter(func(ids: Array) -> bool: return ids.all(func(id: String) -> bool: return id in _selected) and _buyer.get("pairs", []).any(func(pair: Dictionary) -> bool: return pair.ids == ids))
	_close = _button(_canvas, "收起 · Esc", Rect2(1128, 67, 126, 40), func() -> void: dismissed.emit())
	var stock_heading := _paper(_canvas, Rect2(30, 94, 150, 42))
	var stock_title := _label(stock_heading, "铺中现货", Rect2(0, 0, 150, 42), 25)
	stock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check(_canvas, "只看可售", Rect2(548, 95, 144, 36), _only_saleable, func(on: bool) -> void:
		_only_saleable = on; _page = 0; _rebuild("SaleFilter")).name = "SaleFilter"
	var all := _check(_canvas, "全选", Rect2(717, 95, 102, 36), not available.is_empty() and _selected.size() == available.size(), func(on: bool) -> void:
		_selected = available.duplicate() if on else []; _error = ""; _rebuild("SelectAll"))
	all.name = "SelectAll"
	all.disabled = available.is_empty()
	var rows: Array = _buyer.get("stock", []).filter(func(row: Dictionary) -> bool: return not _only_saleable or row.reason.is_empty())
	var pages := maxi(1, ceili(rows.size() / 6.0))
	_page = clampi(_page, 0, pages - 1)
	for index in 6:
		var at := _page * 6 + index
		_slot(rows[at] if at < rows.size() else {}, Rect2(30 + (index % 3) * 267, 143 + (index / 3) * 224, 267, 224))
	if rows.is_empty():
		var empty := _paper(_canvas, Rect2(167, 318, 524, 78))
		_label(empty, "暂无符合收货需求的现货" if _only_saleable else "柜里还没有自有现货", Rect2(22, 16, 480, 42), 24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pages > 1:
		_button(_canvas, "上一页", Rect2(259, 600, 110, 35), func() -> void: _page -= 1; _rebuild()).disabled = _page == 0
		_label(_canvas, "%d / %d" % [_page + 1, pages], Rect2(385, 599, 65, 36), 20, Color("f1dfb9")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(_canvas, "下一页", Rect2(466, 600, 110, 35), func() -> void: _page += 1; _rebuild()).disabled = _page == pages - 1
	_receipt()
	if _details: _price_details()
	if not focus_name.is_empty():
		var target := _canvas.find_child(focus_name, true, false) as Control
		if target != null: target.grab_focus()

func _slot(row: Dictionary, rect: Rect2) -> void:
	var cell := Panel.new()
	# TextureRect preserves the painted wood/felt proportions at this small size.
	var background := TextureRect.new()
	background.texture = preload("res://assets/lu_sale/tray_slot.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(cell, _canvas, rect)
	_place(background, cell, Rect2(Vector2.ZERO, rect.size))
	cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if row.is_empty(): return
	var selected: bool = row.id in _selected
	var texture := CounterVisualCatalog.front(_visual.get(row.id, {}).get("asset", ""))
	var picture := TextureRect.new()
	picture.texture = texture
	picture.material = CounterVisualCatalog.study_material(texture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(picture, cell, Rect2(40, 18, 187, 139))
	if not row.reason.is_empty(): picture.modulate = Color("999687")
	if _buyer.get("silver", false) and not row.reason.is_empty():
		var refusal := _paper(cell, Rect2(18, 119, 231, 44))
		var words := _label(refusal, row.reason, Rect2(8, 3, 215, 38), 14, Color("713122"))
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size = Vector2(215, 38)
		words.max_lines_visible = 2
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag := _paper(cell, Rect2(12, 165, 243, 46))
	var tag_line := HBoxContainer.new()
	tag_line.add_theme_constant_override("separation", 8)
	tag_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(tag_line, tag, Rect2(10, 0, 223, 46))
	var name_label := _label(tag_line, _visual.get(row.id, {}).get("name", row.name), Rect2(), 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var price_label := _label(tag_line, "%d 银元" % row.price if row.reason.is_empty() else "暂不收", Rect2(), 20, Color("873e2c") if selected else Color("554630"))
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pick := Button.new()
	pick.name = "Pick_" + String(row.id).replace("/", "_")
	pick.toggle_mode = true
	pick.set_pressed_no_signal(selected)
	pick.disabled = not row.reason.is_empty()
	pick.tooltip_text = row.name + ("\n" + row.reason if not row.reason.is_empty() else "\n点击加入或移出货单")
	pick.accessibility_name = row.name + ("，报价%d银元" % row.price if row.reason.is_empty() else "，" + row.reason)
	for state in ["normal", "disabled"]: pick.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "pressed", "focus"]:
		var border := CounterTheme.box("00000000", "b28b4e" if state == "hover" else "9b4933", 0, 0)
		border.set_border_width_all(3)
		pick.add_theme_stylebox_override(state, border)
	_place(pick, cell, Rect2(8, 8, 251, 208))
	pick.toggled.connect(func(on: bool) -> void:
		if on: _selected.append(row.id)
		else: _selected.erase(row.id)
		_error = ""; _rebuild(pick.name))
	if row.reason.is_empty():
		# The native icon contains both the square and its centred tick.
		var mark := TextureRect.new()
		mark.texture = get_theme_icon("checked" if selected else "unchecked", "CheckBox")
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.modulate = _selection_tint(selected)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(mark, cell, Rect2(221, 18, 24, 24))

func _receipt() -> void:
	var paper := _paper(_canvas, Rect2(846, 114, 408, 526))
	if buyer_id == "buyer_lu" or _buyer.get("silver", false):
		var avatar := TextureRect.new()
		var crop := AtlasTexture.new()
		crop.atlas = preload("res://assets/art04/customers/special/silver_owner_v48.png") if _buyer.get("silver", false) else preload("res://assets/first_debt/lu_zhangyan_elderly_v43.png")
		crop.region = Rect2(210, 0, 510, 570) if _buyer.get("silver", false) else Rect2(305, 0, 620, 660)
		avatar.texture = crop
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(avatar, paper, Rect2(27, 15, 126, 130))
		_label(paper, "街口银楼" if _buyer.get("silver", false) else "陆掌眼", Rect2(171, 29, 210, 42), 30 if _buyer.get("silver", false) else 34)
		_label(paper, "今日银价 %d%%" % _buyer.daily_rate if _buyer.get("silver", false) else "收" + String(_buyer.get("wanted", "货")), Rect2(171, 83, 210, 32), 23 if _buyer.get("silver", false) else 25, Color("843b2b"))
	else:
		var sign := _paper(paper, Rect2(27, 24, 354, 78))
		var title := _label(sign, "杂货回收" if buyer_id == RecyclerPolicy.BUYER else _buyer.get("name", "收货约定"), Rect2(12, 10, 330, 58), 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label(paper, "各货各价 · 当日为准" if _buyer.get("preopen", false) else _buyer.get("window", ""), Rect2(30, 115, 300, 27), 19)
		var stamp := Panel.new()
		var seal := StyleBoxFlat.new()
		seal.bg_color = Color("ead3a400")
		seal.border_color = Color("873e2c")
		seal.set_border_width_all(2)
		stamp.add_theme_stylebox_override("panel", seal)
		stamp.rotation = -0.06
		_place(stamp, paper, Rect2(326, 107, 52, 36))
		var seal_text := _label(stamp, "收货", Rect2(0, 0, 52, 36), 20, Color("873e2c"))
		seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rule(paper, 152)
	_label(paper, "本次货单", Rect2(27, 164, 300, 30), 25)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, paper, Rect2(27, 205, 354, 115))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	if _selected.is_empty(): AccountPaper.label(list, "从左边挑选要交的货。", 18)
	for row in _buyer.get("stock", []):
		if row.id not in _selected: continue
		var line := HBoxContainer.new()
		list.add_child(line)
		var item := AccountPaper.label(line, _visual.get(row.id, {}).get("name", row.name), 21)
		item.autowrap_mode = TextServer.AUTOWRAP_OFF
		item.custom_minimum_size = Vector2(175, 36)
		item.add_theme_font_override("font", CounterTheme.display_font())
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.tooltip_text = row.name
		var price := AccountPaper.label(line, "%d 银元" % row.price, 20)
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		price.size_flags_horizontal = Control.SIZE_SHRINK_END
	for pair in _buyer.get("pairs", []):
		if not pair.ids.all(func(id: String) -> bool: return id in _selected): continue
		var check := CheckBox.new()
		check.text = pair.label + " +%d" % pair.bonus
		check.add_theme_font_size_override("font_size", 16)
		check.set_pressed_no_signal(pair.ids in _pairs)
		check.disabled = _pairs.any(func(ids: Array) -> bool: return ids != pair.ids and (pair.ids[0] in ids or pair.ids[1] in ids))
		check.toggled.connect(func(on: bool) -> void:
			if on: _pairs.append(pair.ids.duplicate())
			else: _pairs.erase(pair.ids)
			_rebuild())
		list.add_child(check)
	_preview = CashFlowReadModel.sale_preview(_model.get("cash_flow", {"cash": 0, "reserve": 0}), _buyer, _selected)
	for pair in _buyer.get("pairs", []):
		if pair.ids in _pairs and _preview.valid:
			for key in ["income", "profit", "cash", "balance"]: _preview[key] += int(pair.bonus)
	_rule(paper, 326)
	_total = _label(paper, "收款  %d 银元" % _preview.get("income", 0), Rect2(27, 333, 354, 43), 34, Color("713122"))
	_label(paper, ("已选%d件 · 交货1行动点 · 余%d点" % [_selected.size(), maxi(0, _buyer.get("action_points", 0))] if _buyer.get("preopen", false) else "已选%d件 · 往返20分钟" % _selected.size()), Rect2(27, 380, 354, 26), 17)
	var details := _button(paper, "价目明细", Rect2(27, 447, 171, 46), func() -> void: _details = true; _rebuild())
	details.add_theme_font_size_override("font_size", 24)
	var reason: String = _error if not _error.is_empty() else _buyer.get("reason", "")
	if not _preview.valid: reason = _preview.reason
	var status := _label(paper, reason, Rect2(27, 407, 354, 36), 14, Color("823b2c"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.tooltip_text = reason
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	_submit = _button(paper, "确认交货", Rect2(210, 447, 171, 46), func() -> void: submitted.emit(buyer_id, _selected.duplicate(), _pairs.duplicate(true)))
	_submit.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed"]:
		_submit.add_theme_stylebox_override(state, CounterTheme.painted_paper(Color("8b4232") if state != "hover" else Color("a35a42")))
		_submit.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color("f5e6c9"))
	_submit.disabled = _selected.is_empty() or not _buyer.get("reason", "").is_empty() or not _preview.valid
	_submit.tooltip_text = "请先挑选货物。" if _selected.is_empty() else reason

func _price_details() -> void:
	var panel := _paper(_canvas, Rect2(253, 143, 566, 445))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(panel, "价目明细", Rect2(28, 20, 400, 36), 26)
	_button(panel, "收起明细", Rect2(410, 22, 128, 34), func() -> void: _details = false; _rebuild())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, panel, Rect2(28, 73, 510, 340))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for row in _buyer.get("stock", []):
		if row.id in _selected:
			if _buyer.get("silver", false):
				AccountPaper.label(list, "%s\n今日银价%d%% · 报价%d银元" % [row.name, row.daily_rate, row.price], 18)
			elif _buyer.get("preopen", false):
				AccountPaper.label(list, "%s\n基础价%s × 当日%d%% → %d银元" % [row.name, String.num(row.base_value, 2), row.daily_rate, row.price], 18)
			else:
				AccountPaper.label(list, "%s\n报价%d · 成本%d · 来源溢价%d" % [row.name, row.price, row.cost, row.premium], 18)
	if _buyer.has("fixed_pair") and _buyer.fixed_pair.all(func(id: String) -> bool: return id in _selected): AccountPaper.label(list, "龙凤成对加价 %d 银元" % _buyer.fixed_bonus, 18)
	for pair in _buyer.get("pairs", []):
		if pair.ids in _pairs: AccountPaper.label(list, pair.label + " · 加价%d 银元" % pair.bonus, 18)
	AccountPaper.rule(list)
	if _preview.valid:
		var trip_text := "交货消耗1行动点" if _buyer.get("preopen", false) else "%s 出门 → %s 回店" % [_model.get("clock", ""), _model.get("return_clock", "")]
		AccountPaper.label(list, "收款%d · 成本%d · 交易毛利%+d 银元\n%s" % [_preview.income, _preview.cost, _preview.profit, trip_text], 18)
		if _model.has("cash_flow"): AccountPaper.label(list, "成交后现银%d 银元\n%s" % [_preview.cash, CashFlowReadModel.balance_text(_preview.balance, true)], 17)
	AccountPaper.label(list, "交易毛利未扣调查、复核、寻货及每日费用。", 15)

func cancel() -> void:
	if _details: _details = false; _rebuild()
	else: dismissed.emit()
