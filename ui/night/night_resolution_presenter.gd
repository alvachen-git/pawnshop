class_name NightResolutionPresenter
extends Node

var _session: RunSession
var _view: NightResolutionView

func bind(session: RunSession, view: NightResolutionView) -> void:
	_session = session
	_view = view
	_view.command_requested.connect(_on_command)
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var state := _session.read_state()
	var risk_enabled := not _session.definition.ghost_rule_ids.is_empty()
	var body := "夜深了\n\n关门前，再看一眼柜里的东西。" if risk_enabled else "夜间结算\n\n封铺后在此结算。本阶段未接入鬼货规则、风险与死亡记录。"
	if state.phase == "night_resolution":
		body = "已封铺\n\n" + ("街上的脚步声散了，铺里还剩最后一点灯火。" if risk_enabled else "当夜行动已结束。点击结算，生成占位平安夜结果与日结。")
	elif state.phase in ["day_summary", "run_ended", "dead"]:
		var summary: Dictionary = state.summaries.back()
		var outcome: String = RiskManager.LABELS.get(summary.outcome, "平安夜（占位，未计算鬼货风险）")
		body = "第 %d 夜 · 日结\n\n%s\n开夜现金：%d\n夜末现金：%d\n本夜现金变化：%+d\n耗时行动：%d 次\n关门时刻：%s\n\n现货：%d件 · 成本占款 %d\n在当本金：%d\n收购支出：%d · 活当放款：%d\n销售收入：%d · 赎金/续当收入：%d\n本夜已实现盈亏：%+d\n\n现金流不等于利润；在当到期未赎自动转现货。" % [summary.night, outcome, summary.opening_cash, summary.closing_cash, summary.closing_cash - summary.opening_cash, summary.action_count, TimeController.clock_text(_session.definition.opening_minute, summary.closed_at), summary.inventory_count, summary.inventory_cost, summary.pawn_principal, summary.purchase_spend, summary.pawn_disbursed, summary.sales_revenue, summary.redemption_receipts, summary.realized_profit]
		body += "柜里的动静，还得留心。" if risk_enabled else "鬼货风险留至后续里程碑。"
		if state.phase == "run_ended": body += "\n\n三夜已过，天色将明。账册合上，铺门外又响起了车铃。"
		if state.phase == "dead": body += "\n\n灯盏已经冷透。《绝当录》上，多了一笔。"
	if not state.risk_pending.is_empty(): body += "\n\n镜中来客尚未离开，请到「鬼货与绝当录」应对后再继续。"
	if state.phase == "dead":
		body = "命灯熄灭\n\n灯盏已经冷透。《绝当录》上，多了一笔。"
	elif not state.risk_pending.is_empty():
		body = "镜中来客\n\n账页还摊着，镜子那边却传来了一声轻响。"
	elif not risk_enabled:
		body += "\n\n" + _session.message
	_view.render({"resolve_label": "合上今夜的账册" if risk_enabled else "结算本夜（占位）并自动保存", "body": body, "can_resolve": _session.can_execute("resolve_night"), "can_continue": _session.can_execute("continue_run"), "continue_label": ("合卷" if risk_enabled else "结束本轮试玩") if state.current_night_index == _session.definition.total_nights else "进入下一夜"})

func _on_command(command: String) -> void:
	_session.execute(command)
