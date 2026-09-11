class_name NightResolutionView
extends FeaturePanel

signal command_requested(command: String)
signal pawn_choice_requested(id: String, choice: String)
var _disposals: VBoxContainer
var _body: Label
var _resolve: Button
var _continue: Button
var _account: VBoxContainer
var _resolve_command := "resolve_night"

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_account = VBoxContainer.new()
	_account.add_theme_constant_override("separation", 6)
	content.add_child(_account)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_disposals = VBoxContainer.new()
	_disposals.add_theme_constant_override("separation", 12)
	content.add_child(_disposals)
	_resolve = Button.new()
	_resolve.disabled = true
	_resolve.text = "结算本夜（占位）并自动保存"
	_resolve.pressed.connect(func() -> void: command_requested.emit(_resolve_command))
	column.add_child(_resolve)
	_continue = Button.new()
	_continue.disabled = true
	_continue.pressed.connect(command_requested.emit.bind("continue_run"))
	column.add_child(_continue)

func render(model: Dictionary) -> void:
	AccountPaper.clear(_disposals)
	for row in model.get("pawn_disposals", []):
		var card := AccountPaper.entry(_disposals)
		AccountPaper.label(card, "当票 " + row.number + " · " + row.item + " / " + row.customer, 18)
		AccountPaper.label(card, "本金 %d 银元 · 转当实收 %d 银元" % [row.principal, row.quote], 16)
		AccountPaper.label(card, "去向：" + {"": "尚未选定", "keep": "撕票留货", "transfer": "折价转给同行"}[row.choice], 15)
		for choice in ["keep", "transfer"]:
			var button := Button.new()
			button.text = "撕票留货" if choice == "keep" else "折价转给同行 · 实收 %d 银元" % row.quote
			button.toggle_mode = true
			button.set_pressed_no_signal(row.choice == choice)
			button.pressed.connect(pawn_choice_requested.emit.bind(row.id, choice))
			card.add_child(button)
	_resolve_command = model.get("resolve_command", "resolve_night")
	AccountPaper.clear(_account)
	var account: Dictionary = model.get("account", {})
	_account.visible = not account.is_empty()
	_body.visible = account.is_empty()
	if not account.is_empty(): _draw_account(account)
	_body.text = model.body
	_resolve.text = model.get("resolve_label", "结算本夜（占位）并自动保存")
	_resolve.disabled = not model.can_resolve
	_resolve.visible = account.is_empty()
	_continue.visible = model.can_continue
	_continue.disabled = not model.can_continue
	_continue.text = model.continue_label

func _draw_account(a: Dictionary) -> void:
	var header := HBoxContainer.new()
	_account.add_child(header)
	AccountPaper.label(header, "第 %d 夜 · 日结" % a.night, 23)
	AccountPaper.stamp(header, "已结")
	AccountPaper.label(_account, a.outcome_text, 16)
	for result in a.get("pawn_results", []): AccountPaper.label(_account, result, 16)
	if not a.arrears_notice.is_empty():
		var notice := AccountPaper.label(_account, a.arrears_notice.strip_edges(), 16)
		notice.name = "ArrearsNotice"
		notice.add_theme_color_override("font_color", Color("8d2a24"))
	AccountPaper.metrics(_account, [["夜末现银", a.closing_cash], ["现金变化", "%+d" % (a.closing_cash - a.opening_cash)], ["经营净收益" if a.fee_enabled else "交易毛利", "%+d" % a.get("operating_profit", a.get("realized_profit", 0))]])
	AccountPaper.rule(_account)
	AccountPaper.label(_account, "现金收支 / 银元", 18)
	var rows := [["开夜现银", a.opening_cash], ["收购支出", -a.get("purchase_spend", 0)], ["活当放款", -a.get("pawn_disbursed", 0)], ["销售收入", a.get("sales_revenue", 0)], ["转当收入", a.get("pawn_transfer_receipts", 0)], ["赎金及续当收入", a.get("redemption_receipts", 0)], ["实际付息费", -a.get("fees_paid", 0)]]
	if a.has("preparation_expense"): rows.append(["准备支出", -a.preparation_expense])
	if a.has("provenance_expense"): rows.append(["来源调查费", -a.provenance_expense])
	for row in rows:
		var line := HBoxContainer.new()
		_account.add_child(line)
		AccountPaper.label(line, row[0], 15)
		var value := AccountPaper.label(line, str(row[1]), 17)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	AccountPaper.rule(_account)
	AccountPaper.label(_account, "现货 %d 件 · 成本占款 %d 银元\n在当本金 %d 银元\n交易毛利 %+d · 当夜息费 %d\n现金进出与经营收益分别记账。" % [a.get("inventory_count", 0), a.get("inventory_cost", 0), a.get("pawn_principal", 0), a.get("realized_profit", 0), a.get("interest_expense", 0) + a.get("shop_expense", 0)], 15)
	if a.get("inventory_loss", 0) > 0: AccountPaper.label(_account, "湿灰损货成本 %d 银元，已计入经营费用；本次没有再支出现金。" % a.inventory_loss, 15)
	if not a.debt.is_empty(): AccountPaper.label(_account, a.debt, 15)
	if not a.get("familiar_notes", "").is_empty(): AccountPaper.label(_account, a.familiar_notes, 15)
	AccountPaper.label(_account, "关门 %s · 耗时行动 %d 次" % [a.closed_clock, a.action_count], 14)
