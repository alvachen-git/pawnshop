class_name DayFlowPresenter
extends Node

signal status_updated(text: String)
signal route_requested(panel_id: StringName)

const PHASE_LABELS := {"pre_open": "开铺前", "open": "营业中", "closed_processing": "已关门 · 店内处理", "night_resolution": "封铺 · 夜间结算", "shop_resolution": "封铺 · 铺内收尾", "private_room": "回房", "sleep_resolution": "就寝", "day_summary": "日结", "run_ended": "经营告一段落", "dead": "命灯已灭", "bankrupt": "铺门已封"}
var _session: RunSession
var _view: DayFlowPanel
var _session_menu: SessionMenuView
var _last_phase := ""

func bind(session: RunSession, view: DayFlowPanel, session_menu: SessionMenuView) -> void:
	_session = session
	_view = view
	_session_menu = session_menu
	_view.command_requested.connect(_on_command)
	_session_menu.new_requested.connect(_session.new_run)
	_session_menu.load_requested.connect(_on_load)
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var state := _session.read_state()
	var definition := _session.definition
	var commands: Array = []
	for entry in [{"id": "open_shop", "label": "开铺"}, {"id": "close_shop", "label": "关门（本夜不可重开）"}]:
		entry.enabled = _session.can_execute(entry.id)
		commands.append(entry)
	for action in definition.actions:
		commands.append({"id": action.id, "label": "%s · %d 分钟" % [action.label, action.minutes], "enabled": _session.can_execute(action.id)})
	commands.append({"id": "wait_until_seal", "label": "等到封铺（消耗全部剩余时间）", "enabled": _session.can_execute("wait_until_seal")})
	if SevenNightPlan.enabled(definition):
		for entry in commands:
			if state.phase == "pre_open" and entry.id != "open_shop": entry.visible = false
		commands.append({"id": "read_seven_notes", "label": "查看已知消息 · 不耗次数", "enabled": true, "visible": state.current_night_index >= 4})
		for entry in [{"id": "prep_investigate", "label": "调查收货消息 · 准备1次"}, {"id": "prep_contact", "label": "联系收货人 · 准备1次"}, {"id": "prep_visitors", "label": "打听今晚来客 · 准备1次"}, {"id": "prep_finish", "label": "结束准备"}]:
			entry.enabled = _session.can_execute(entry.id)
			entry.visible = state.current_night_index >= 4 and state.phase == "pre_open"
			commands.append(entry)
	var appointment_hint := ""
	if not state.buyer_appointment.is_empty(): appointment_hint = "\n" + OrdinarySamplePlan.notice(_session._day.state)
	if SevenNightPlan.enabled(definition):
		appointment_hint += "\n" + _session.seven_notice()
		if state.current_night_index >= 4 and state.phase == "pre_open": appointment_hint = "\n今夜准备剩余%d次，开铺后不可返回。\n收货传闻与来客口信记在铺中记事里。" % (2 - PreparationService.count(_session._day.state))
	var event_hint := "\n有待处理的铺中记事，请先查看。" if not state.pending_event_id.is_empty() else ""
	var description := "%s\n剩余 %d 分钟 · 查看面板不耗时\n点击柜台上的客人与货物进行接待。\n等待/店内行动也会让顾客继续等候。" % [PHASE_LABELS[state.phase], definition.night_minutes - int(state.game_minutes)] + event_hint + appointment_hint
	if SevenNightPlan.enabled(definition) and state.phase == "pre_open" and state.current_night_index >= 4:
		description = "开铺前\n今夜准备剩余%d次，开铺后不可返回。\n收货与来客消息可免费复看。" % (2 - PreparationService.count(_session._day.state))
	_view.render({"description": description, "message": _session.message, "commands": commands})
	_session_menu.render({"has_save": _session.has_save(), "room_flow": state.room_enabled, "in_room": state.room_enabled and state.phase in ["private_room", "sleep_resolution", "dead"]})
	status_updated.emit("第 %d / %d 夜 · %s · %s · 现银 %d" % [state.current_night_index, definition.total_nights, PHASE_LABELS[state.phase], TimeController.clock_text(definition.opening_minute, state.game_minutes), state.cash])
	if state.phase != _last_phase:
		_last_phase = state.phase
		route_requested.emit(&"night" if state.phase in ["night_resolution", "day_summary", "run_ended", "dead", "bankrupt"] else &"day")

func _on_command(command: String) -> void:
	if command == "read_seven_notes":
		route_requested.emit(&"events")
		return
	_session.execute(command)

func _on_load() -> void:
	var result := _session.load_checkpoint()
	if _session.definition.private_room and not result.ok: _session_menu.show_load_error(result.message)
