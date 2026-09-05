class_name DayFlowPresenter
extends Node

signal status_updated(text: String)
signal route_requested(panel_id: StringName)

const PHASE_LABELS := {"pre_open": "开铺前", "open": "营业中", "closed_processing": "已关门 · 店内处理", "night_resolution": "封铺 · 夜间结算", "shop_resolution": "封铺 · 铺内收尾", "private_room": "回房", "sleep_resolution": "就寝", "day_summary": "日结", "run_ended": "三夜已过", "dead": "命灯已灭", "bankrupt": "铺门已封"}
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
	var event_hint := "\n有待处理的铺中记事，请先查看。" if not state.pending_event_id.is_empty() else ""
	_view.render({"description": "%s\n剩余 %d 分钟 · 查看面板不耗时\n点击柜台上的客人与货物进行接待。\n等待/店内行动也会让顾客继续等候。" % [PHASE_LABELS[state.phase], definition.night_minutes - int(state.game_minutes)] + event_hint, "message": _session.message, "commands": commands})
	_session_menu.render({"has_save": _session.has_save(), "room_flow": state.room_enabled, "in_room": state.room_enabled and state.phase in ["private_room", "sleep_resolution", "dead"]})
	status_updated.emit("第 %d / %d 夜 · %s · %s · 现银 %d" % [state.current_night_index, definition.total_nights, PHASE_LABELS[state.phase], TimeController.clock_text(definition.opening_minute, state.game_minutes), state.cash])
	if state.phase != _last_phase:
		_last_phase = state.phase
		route_requested.emit(&"night" if state.phase in ["night_resolution", "day_summary", "run_ended", "dead", "bankrupt"] else &"day")

func _on_command(command: String) -> void:
	_session.execute(command)

func _on_load() -> void:
	var result := _session.load_checkpoint()
	if _session.definition.private_room and not result.ok: _session_menu.show_load_error(result.message)
