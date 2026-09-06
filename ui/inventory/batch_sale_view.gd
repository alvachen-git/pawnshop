class_name BatchSaleView
extends VBoxContainer

signal submitted(buyer_id: String, item_ids: Array)
var _model: Dictionary = {}
var _buyer := ""
var _selected: Array = []
var _total: Label
var _submit: Button
var _token := ""

func render(model: Dictionary) -> void:
	if _token != model.run_token:
		_buyer = ""
		_selected.clear()
		_token = model.run_token
	_model = model
	_rebuild()

func _rebuild() -> void:
	AccountPaper.clear(self)
	AccountPaper.label(self, "卖货 · 先选买家，再选货", 22)
	AccountPaper.label(self, "同一买家，一趟20分钟，件数不限。店里有客时先接待周全。", 15)
	var current: Dictionary = {}
	for buyer in _model.buyers:
		if not _buyer.is_empty() and buyer.id != _buyer: continue
		if buyer.id == _buyer: current = buyer
		var entry := AccountPaper.entry(self)
		var button := Button.new()
		button.text = "选择买家 · " + buyer.name
		button.toggle_mode = true
		button.set_pressed_no_signal(buyer.id == _buyer)
		button.custom_minimum_size.y = 38
		button.pressed.connect(_choose.bind(buyer.id))
		entry.add_child(button)
		AccountPaper.label(entry, "收%s · %s · 不限量" % [buyer.wanted, buyer.window], 15)
		if not buyer.reason.is_empty(): AccountPaper.label(entry, buyer.reason, 14)
	if not current.is_empty():
		var change := Button.new()
		change.text = "更换买家"
		change.pressed.connect(func() -> void: _selected.clear(); _buyer = ""; _rebuild())
		add_child(change)
		var available: Array = []
		for row in current.stock:
			if row.reason.is_empty(): available.append(row.id)
		_selected = _selected.filter(func(id: String) -> bool: return id in available)
		AccountPaper.rule(self)
		AccountPaper.label(self, current.name + " · 货单", 20)
		AccountPaper.label(self, current.note, 15)
		var all := Button.new()
		all.text = "选中全部可售货物"
		all.disabled = available.is_empty()
		all.pressed.connect(func() -> void: _selected = available.duplicate(); _rebuild())
		add_child(all)
		for row in current.stock:
			var box := CheckBox.new()
			box.text = row.name
			box.name = "Pick_" + row.id.replace("/", "_")
			box.disabled = not row.reason.is_empty()
			box.set_pressed_no_signal(row.id in _selected)
			box.toggled.connect(_toggle.bind(row.id))
			add_child(box)
			if row.reason.is_empty():
				AccountPaper.label(self, "报价%d · 成本%d · 差额%+d 银元\n其中来源溢价%d 银元" % [row.price, row.cost, row.price - row.cost, row.premium], 15)
			else: AccountPaper.label(self, row.reason, 14)
		if current.stock.is_empty(): AccountPaper.label(self, "柜里没有可带走的自有现货。", 16)
		_total = AccountPaper.label(self, "", 16)
		AccountPaper.label(self, "交易毛利未扣来源调查费与每日息费。", 14)
		_submit = Button.new()
		_submit.text = "完成交易 · 20分钟"
		_submit.custom_minimum_size.y = 44
		_submit.pressed.connect(func() -> void: submitted.emit(_buyer, _selected.duplicate()))
		add_child(_submit)
		var cancel := Button.new()
		cancel.text = "取消选货"
		cancel.pressed.connect(func() -> void: _selected.clear(); _buyer = ""; _rebuild())
		add_child(cancel)
		_totals()
	var history := Button.new()
	history.text = "查看往来口信"
	history.toggle_mode = true
	add_child(history)
	var text := AccountPaper.label(self, _model.history, 14)
	text.hide()
	history.toggled.connect(text.set_visible)

func _choose(id: String) -> void:
	_buyer = id
	_selected.clear()
	_rebuild()

func _toggle(checked: bool, id: String) -> void:
	if checked and id not in _selected: _selected.append(id)
	elif not checked: _selected.erase(id)
	_totals()

func _totals() -> void:
	var income := 0
	var cost := 0
	var reason := ""
	for buyer in _model.buyers:
		if buyer.id != _buyer: continue
		reason = buyer.reason
		for row in buyer.stock:
			if row.id in _selected: income += row.price; cost += row.cost
	_total.text = "已选%d件 · 收入%d · 成本%d 银元\n预计交易毛利%+d 银元\n当前%s → 预计回店%s · 往返20分钟" % [_selected.size(), income, cost, income - cost, _model.clock, _model.return_clock]
	_submit.disabled = _selected.is_empty() or not reason.is_empty()
	_submit.tooltip_text = "请先选择货物。" if _selected.is_empty() else reason
	if not reason.is_empty(): _total.text += "\n" + reason
