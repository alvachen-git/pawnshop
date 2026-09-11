class_name LedgerPanel
extends IntentPanel

signal panel_requested(panel: StringName)
signal receipt_requested(transaction_id: String)
var _tabs: HBoxContainer
var _pages: Array[VBoxContainer] = []
var _selected := 0
var _night_only := true
var _model: Dictionary = {}
var _heading: VBoxContainer

func _ready() -> void:
	super._ready()
	_heading = VBoxContainer.new()
	_column.add_child(_heading)
	_column.move_child(_heading, 0)
	_tabs = HBoxContainer.new()
	_column.add_child(_tabs)
	_column.move_child(_tabs, 1)
	for title in ["流水", "债务", "当票"]:
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_page.bind(_tabs.get_child_count()))
		_tabs.add_child(button)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.set_meta("reveal_label", title)
		_column.add_child(page)
		_pages.append(page)
	_column.move_child(_body, _column.get_child_count() - 1)
	select_page(0)

func select_page(index: int) -> void:
	_selected = index
	for i in _pages.size():
		_pages[i].visible = index == i
		(_tabs.get_child(i) as Button).set_pressed_no_signal(index == i)
	(_column.get_parent() as ScrollContainer).scroll_vertical = 0

func render(model: Dictionary) -> void:
	_model = model
	if not model.has("visual"):
		super.render(model)
		return
	var v: Dictionary = model.visual
	AccountPaper.clear(_heading)
	AccountPaper.metrics(_heading, [["现银 / 银元", v.cash], ["本夜交易毛利", "%+d" % v.financial.realized_profit], ["在当本金", v.financial.pawn_principal]])
	for page in _pages: AccountPaper.clear(page)
	_draw_entries()
	var debt := AccountPaper.entry(_pages[1])
	AccountPaper.label(debt, "借据与息费", 21)
	AccountPaper.rule(debt)
	AccountPaper.label(debt, v.debt, 17)
	if model.has("cash_flow"): AccountPaper.label(debt, CashFlowReadModel.debt_detail(model.cash_flow), 15)
	AccountPaper.rule(debt)
	AccountPaper.label(debt, "当夜已计息费 %d 银元\n本夜实际付息费 %d 银元\n经营净收益 %+d 银元" % [v.financial.interest_expense + v.financial.shop_expense, v.financial.fees_paid, v.financial.operating_profit], 16)
	AccountPaper.label(debt, "息费在夜末入账。实际付款可能包含以前的短款。", 14)
	if v.financial.get("inventory_loss", 0) > 0: AccountPaper.label(debt, "本夜损货成本 %d 银元，已从经营净收益扣除。" % v.financial.inventory_loss, 16)
	if v.financial.has("preparation_expense"):
		AccountPaper.label(debt, "本夜准备支出 %d 大洋\n准备支出已从经营净收益扣除。" % v.financial.preparation_expense, 16)
	if v.financial.has("provenance_expense"):
		AccountPaper.label(debt, "本夜来源调查费 %d 银元\n调查费列为经营费用，已从经营净收益扣除。" % v.financial.provenance_expense, 16)
	if not v.archive.is_empty(): AccountPaper.label(_pages[1], v.archive, 15)
	if v.tickets.is_empty(): AccountPaper.label(_pages[2], "当票簿尚空。办理活当后，凭票查阅本金、期限与赎回约定。", 17)
	for row in v.tickets:
		var ticket := AccountPaper.entry(_pages[2])
		var head := HBoxContainer.new()
		ticket.add_child(head)
		var title := AccountPaper.label(head, "当  票  ·  " + row.number, 22)
		title.tooltip_text = row.id
		AccountPaper.stamp(head, row.stamp, row.state != "active")
		AccountPaper.rule(ticket)
		AccountPaper.label(ticket, row.item + "  /  " + row.customer, 18)
		AccountPaper.metrics(ticket, [["放款本金 / 银元", row.principal], ["约定赎金 / 银元", row.redemption]])
		AccountPaper.label(ticket, "第%d夜入当    第%d夜到期" % [row.start, row.due], 16)
		AccountPaper.label(ticket, row.request, 15)
		if model.has("cash_flow") and row.state == "active": AccountPaper.label(ticket, "约定收款，尚未入账；不计入当前可周转现银。", 14)
		for entry in model.buttons:
			if entry.target_id == row.id: AccountPaper.action(ticket, entry, _emit_intent)
	_body.text = v.message
	select_page(_selected)

func _emit_intent(command: String, visit_id: String, detail: String) -> void:
	if command == "return_counter": panel_requested.emit(&"trade")
	else: super._emit_intent(command, visit_id, detail)

func _draw_entries() -> void:
	AccountPaper.clear(_pages[0])
	var toggle := Button.new()
	toggle.text = "本夜流水" if _night_only else "全部流水"
	toggle.tooltip_text = "点击切换本夜与全部流水；查账不耗时。"
	toggle.pressed.connect(func() -> void:
		_night_only = not _night_only
		_draw_entries()
	)
	_pages[0].add_child(toggle)
	AccountPaper.label(_pages[0], "金额为现金进出；交易毛利另计，收货与放款并非当场亏损。", 14)
	var count := 0
	var entries: Array = _model.visual.entries.duplicate()
	entries.reverse()
	var shown_receipts: Dictionary = {}
	for row in entries:
		if _night_only and row.night != _model.visual.night: continue
		count += 1
		AccountPaper.rule(_pages[0])
		var line := HBoxContainer.new()
		_pages[0].add_child(line)
		AccountPaper.label(line, row.kind + " · " + row.item, 17)
		var amount := AccountPaper.label(line, "%+d" % row.amount, 21)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		AccountPaper.label(_pages[0], "第%d夜 %s    余额 %d    毛利 %+d" % [row.night, row.clock, row.balance, row.profit], 14)
		var receipt_id := String(row.get("receipt_id", ""))
		if not receipt_id.is_empty() and not shown_receipts.has(receipt_id):
			shown_receipts[receipt_id] = true
			var review := Button.new()
			review.text = "查看本批凭据" if row.get("batch", false) else "查看这笔凭据"
			review.set_meta("receipt_id", receipt_id)
			review.pressed.connect(receipt_requested.emit.bind(receipt_id))
			_pages[0].add_child(review)
	if count == 0: AccountPaper.label(_pages[0], "本页尚无收支。", 17)
