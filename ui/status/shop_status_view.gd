class_name ShopStatusView
extends PanelContainer
var cash_held := false
var _pending_cash := ""

func render_snapshot(state: Dictionary, definition: RunDefinition, intrusion: bool, haunting: bool) -> void:
	%ClockStatus.text = "时辰\n" + TimeController.clock_text(definition.opening_minute, state.game_minutes)
	%NightStatus.text = "夜次\n第 %d / %d 夜" % [state.current_night_index, definition.total_nights]
	_pending_cash = "现银\n%d 大洋" % state.cash
	if not cash_held: %CashStatus.text = _pending_cash
	var arrears := 0
	for row in state.fee_arrears: arrears += int(row.amount)
	%DebtStatus.text = "债务\n本金 %d · 短款 %d" % [definition.fee_policy.principal, arrears] if definition.fee_policy.enabled else "债务\n—"
	%DebtStatus.tooltip_text = "每日利息 %d，铺面开支 %d。短款须在次夜夜末补齐。" % [definition.fee_policy.interest, definition.fee_policy.overhead] if definition.fee_policy.enabled else ""
	var active := 0
	for ticket in state.pawn_tickets:
		if ticket.status == "active": active += 1
	%TicketStatus.text = "在当票据\n%d 张" % active
	%PhaseStatus.text = "铺面\n" + DayFlowPresenter.PHASE_LABELS[state.phase]
	%RiskStatus.text = "财神香直 · 命灯安稳"
	if intrusion: %RiskStatus.text = "香灰倒伏 · 命灯安稳"
	if haunting: %RiskStatus.text = "香灰倒伏 · 命灯偏斜" if intrusion else "财神香直 · 命灯偏斜"
	if state.phase == "dead": %RiskStatus.text = "命灯已灭"
	if definition.private_room: %RiskStatus.text = "香灰倒伏" if intrusion else "香烟直上"
	%RiskStatus.text = "香火\n" + %RiskStatus.text


func show_content_ready(_item_count: int, _customer_count: int) -> void:
	%ContentStatus.text = ""
	%ContentStatus.hide()

func release_cash() -> void:
	cash_held = false
	if not _pending_cash.is_empty(): %CashStatus.text = _pending_cash


func show_content_error(message: String) -> void:
	%ContentStatus.text = "内容加载失败 · %s" % message
	%ContentStatus.show()
