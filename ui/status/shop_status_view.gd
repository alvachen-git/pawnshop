class_name ShopStatusView
extends PanelContainer
var cash_held := false
var _pending_cash := ""

func _ready() -> void:
	var row := $StatusMargin/StatusRow
	row.add_theme_constant_override("separation", 12)
	var fields := [
		[%ClockStatus, preload("res://assets/ui/icons/clock.svg"), "时辰"],
		[%NightStatus, preload("res://assets/ui/icons/moon.svg"), "夜次"],
		[%CashStatus, preload("res://assets/ui/icons/coins.svg"), "现银"],
		[%DebtStatus, preload("res://assets/ui/icons/receipt.svg"), "债务"],
		[%TicketStatus, preload("res://assets/ui/icons/ticket.svg"), "在当票据"],
		[%ActionPointsStatus, preload("res://assets/ui/icons/action-points.svg"), "行动点"],
	]
	for field in fields:
		var label: Label = field[0]
		if field != fields[0]:
			var separator := VSeparator.new()
			separator.custom_minimum_size = Vector2(1, 34)
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var stroke := StyleBoxLine.new()
			stroke.vertical = true
			stroke.color = Color("897557")
			stroke.thickness = 1
			separator.add_theme_stylebox_override("separator", stroke)
			row.add_child(separator)
		var group := HBoxContainer.new()
		group.name = String(label.name) + "Field"
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 10)
		row.add_child(group)
		var icon := TextureRect.new()
		icon.texture = field[1]
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color("302a24")
		icon.tooltip_text = field[2]
		group.add_child(icon)
		label.reparent(group)
		label.add_theme_font_override("font", CounterTheme.display_font())
		label.add_theme_font_size_override("font_size", 20)
		label.tooltip_text = field[2]
		label.accessibility_name = field[2]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	%PhaseStatus.hide()

func render_snapshot(state: Dictionary, definition: RunDefinition, action_points: int) -> void:
	%ClockStatus.text = TimeController.clock_text(definition.opening_minute, state.game_minutes)
	%NightStatus.text = "第 %d 夜" % state.current_night_index if FirstDebt.enabled(definition) else "第 %d / %d 夜" % [state.current_night_index, definition.total_nights]
	_pending_cash = "%d 大洋" % state.cash
	if not cash_held: %CashStatus.text = _pending_cash
	if definition.fee_policy.enabled:
		var arrears := 0
		for row in state.fee_arrears: arrears += int(row.amount)
		var nightly_fee := definition.fee_policy.interest + definition.fee_policy.overhead
		%DebtStatus.text = "本金 %d · 欠费 %d" % [definition.fee_policy.principal, arrears] if arrears > 0 else "本金 %d · 息费 %d" % [definition.fee_policy.principal, nightly_fee]
		%DebtStatus.tooltip_text = "每夜夜末结利息%d、铺费%d。短款是未付清的息费，先补旧欠。" % [definition.fee_policy.interest, definition.fee_policy.overhead]
		if arrears > 0:
			var earliest_due := int(state.fee_arrears[0].due_night)
			for row in state.fee_arrears: earliest_due = mini(earliest_due, int(row.due_night))
			%DebtStatus.tooltip_text += "现欠%d银元，最迟第%d夜夜末补齐。" % [arrears, earliest_due]
	else:
		%DebtStatus.text = "—"
		%DebtStatus.tooltip_text = ""
	var active := 0
	for ticket in state.pawn_tickets:
		if ticket.status == "active": active += 1
	%TicketStatus.text = "%d 张" % active
	%PhaseStatus.text = "铺面\n" + DayFlowPresenter.PHASE_LABELS[state.phase]
	%ShopTitle.get_parent().get_node("ShopSignHotspot").tooltip_text = DayFlowPresenter.PHASE_LABELS[state.phase] + "\n查看营业安排 · 不耗时"
	%ActionPointsStatus.text = "行动点 —" if action_points < 0 else "行动点 %d/2" % action_points
	%ActionPointsStatus.tooltip_text = "开铺前可用行动点办事；每夜2点，次夜恢复。"
	%ActionPointsStatus.accessibility_name = %ActionPointsStatus.text


func show_content_ready(_item_count: int, _customer_count: int) -> void:
	%ContentStatus.text = ""
	%ContentStatus.hide()

func release_cash() -> void:
	cash_held = false
	if not _pending_cash.is_empty(): %CashStatus.text = _pending_cash


func show_content_error(message: String) -> void:
	%ContentStatus.text = "内容加载失败 · %s" % message
	%ContentStatus.show()
