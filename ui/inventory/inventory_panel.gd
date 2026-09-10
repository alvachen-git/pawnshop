class_name InventoryPanel
extends IntentPanel

signal panel_requested(panel: StringName)
signal batch_submitted(buyer_id: String, item_ids: Array)
var _sale_view: BatchSaleView
var _sheet: VBoxContainer
var _tabs: HBoxContainer
var _filter := 0
var _model: Dictionary = {}
var _expanded: Dictionary = {}

func _ready() -> void:
	super._ready()
	_tabs = HBoxContainer.new()
	_column.add_child(_tabs)
	_column.move_child(_tabs, 0)
	for title in ["铺中货物", "出柜记录", "卖货"]:
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select.bind(_tabs.get_child_count()))
		_tabs.add_child(button)
	_sheet = VBoxContainer.new()
	_sheet.add_theme_constant_override("separation", 12)
	_column.add_child(_sheet)
	_sale_view = BatchSaleView.new()
	_sale_view.submitted.connect(func(buyer: String, ids: Array) -> void: batch_submitted.emit(buyer, ids))
	_column.add_child(_sale_view)
	_column.move_child(_body, _column.get_child_count() - 1)

func render(model: Dictionary) -> void:
	_model = model
	_tabs.get_child(2).visible = model.has("sales")
	if not model.has("sales") and _filter == 2: _filter = 0
	if not model.has("visual"):
		super.render(model)
		return
	_draw()

func _select(index: int) -> void:
	_filter = index
	_draw()
	(_column.get_parent() as ScrollContainer).scroll_vertical = 0

func open_buyer(buyer_id: String) -> void:
	_select(2)
	_sale_view._choose(buyer_id)

func _draw() -> void:
	AccountPaper.clear(_sheet)
	var visual: Dictionary = _model.visual
	var financial: Dictionary = visual.financial
	for index in _tabs.get_child_count(): (_tabs.get_child(index) as Button).set_pressed_no_signal(index == _filter)
	_sale_view.visible = _filter == 2 and _model.has("sales")
	if _model.has("sales"): _sale_view.render(_model.sales)
	_body.text = _model.visual.message
	if _sale_view.visible: return
	AccountPaper.metrics(_sheet, [["现货 / 件", financial.inventory_count], ["现货占款 / 银元", financial.inventory_cost], ["在当本金 / 银元", financial.pawn_principal]])
	AccountPaper.label(_sheet, "估值供判断，出售后才成为现银。在当货物须按当票办理。", 14)
	var count := 0
	for row in visual.stock:
		var held: bool = row.state in ["owned", "pledged"]
		if held != (_filter == 0): continue
		count += 1
		var column := AccountPaper.entry(_sheet)
		var header := HBoxContainer.new()
		column.add_child(header)
		var texture := CounterVisualCatalog.front(row.asset)
		if texture != null:
			var picture := TextureRect.new()
			picture.texture = texture
			picture.custom_minimum_size = Vector2(68, 60)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			header.add_child(picture)
		AccountPaper.label(header, row.name, 19)
		AccountPaper.stamp(header, row.stamp, row.state != "pledged")
		AccountPaper.label(column, "第%d夜入柜 · 原始%s %d 银元\n已知估值 %s 银元" % [row.night, row.cost_label, row.cost, row.estimate], 15)
		var toggle := Button.new()
		toggle.text = "查看货物 · " + row.name
		toggle.tooltip_text = "展开已见物证、出售去向或当票入口；查看不耗时。"
		toggle.toggle_mode = true
		column.add_child(toggle)
		var detail := VBoxContainer.new()
		detail.add_theme_constant_override("separation", 8)
		detail.set_meta("reveal_label", toggle.text)
		column.add_child(detail)
		detail.visible = _expanded.get(row.id, false)
		toggle.set_pressed_no_signal(detail.visible)
		toggle.toggled.connect(func(open: bool) -> void:
			_expanded[row.id] = open
			detail.visible = open
		)
		if not row.get("provenance", "").is_empty(): AccountPaper.label(detail, row.provenance, 15)
		var evidence := AccountPaper.label(detail, "已见物证\n" + ("尚无鉴定记录。" if row.clues.is_empty() else "\n".join(row.clues)), 15)
		if row.state == "owned":
			AccountPaper.rule(detail)
			AccountPaper.label(detail, "出货去向", 17)
			for entry in _model.buttons:
				if entry.target_id == row.id and not (_model.has("sales") and entry.command == "sell"):
					AccountPaper.action(detail, entry, _emit_intent)
					AccountPaper.label(detail, row.buyers.get(entry.detail, ""), 14)
			if _model.has("sales"):
				var sell := Button.new()
				sell.text = "选择买家卖货"
				sell.pressed.connect(_select.bind(2))
				detail.add_child(sell)
		elif row.state == "pledged":
			var ticket := Button.new()
			ticket.text = "查看当票"
			ticket.pressed.connect(panel_requested.emit.bind(&"ledger"))
			detail.add_child(ticket)
		if held and row.ghost:
			var risk := Button.new()
			risk.text = "查看存放与规矩"
			risk.pressed.connect(panel_requested.emit.bind(&"risk"))
			detail.add_child(risk)
		detail.move_child(evidence, detail.get_child_count() - 1)
	if count == 0: AccountPaper.label(_sheet, "柜中暂无货物。收购或活当后，货签会记在这里。" if _filter == 0 else "尚无出柜记录。", 17)
	_body.text = visual.message

func _emit_intent(command: String, target: String, detail: String) -> void:
	if command == "inquire":
		for entry in _model.buttons:
			if entry.command == command and entry.target_id == target:
				ProvenanceConfirmation.show_for(self, _confirmed_inquiry, target, entry.label)
				return
	else: super._emit_intent(command, target, detail)

func _confirmed_inquiry(command: String, target: String, detail: String) -> void:
	super._emit_intent(command, target, detail)
