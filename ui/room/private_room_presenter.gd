class_name PrivateRoomPresenter
extends Node

var _session: RunSession
var _view: PrivateRoomView
var _error := ""
var _position := ""

func bind(session: RunSession, view: PrivateRoomView) -> void:
	_session = session
	_view = view
	_view.command_requested.connect(_execute)
	_session.changed.connect(refresh)
	refresh()

func _execute(command: String) -> void:
	_error = ""
	var result := _session.execute(command)
	if not result.ok: _error = result.message
	refresh()

func refresh() -> void:
	var state := _session.read_state()
	var position: String = state.run_token + "/" + state.phase
	if position != _position: _error = ""
	_position = position
	var haunting := false
	for row in state.mirror_history:
		if row.action == "pursue": haunting = true
	for summary in state.summaries:
		if summary.outcome in ["mirror_scar", "mirror_survived", "mirror_death"]: haunting = true
	var lamp := "命灯的火苗安稳，灯油里没有声响。"
	if "INTRO_LIFE_LAMP_SEEN" in state.narrative_flags: lamp = "火稳，色暖。"
	if haunting: lamp = "灯芯向一边歪着。你换了个位置，它又慢慢偏了过来。"
	if state.phase == "dead": lamp = "灯盏冷了，灯芯再没有亮起来。"
	var body := "铺门已经落闩。楼板下偶尔传来木头收缩的轻响。\n\n可以看看书桌与命灯，也可以就寝。"
	if state.phase == "sleep_resolution": body = "更声隔着窗纸传来。你躺下来，等这座城慢慢安静。"
	if state.phase == "dead": body = "灯盏已经冷透。床边那张旧当票，再没有人伸手去接。"
	_view.render({"visible": state.room_enabled and (state.phase in ["private_room", "sleep_resolution"] or (state.phase == "dead" and not state.room_history.is_empty() and state.room_history.back().action == "personal_defy")), "phase": state.phase, "night": state.current_night_index, "body": body, "lamp": lamp, "haunting": haunting, "dead": state.phase == "dead", "pending": not state.risk_pending.is_empty(), "can_sleep": _session.can_execute("sleep"), "can_finish": _session.can_execute("finish_sleep"), "error": _error, "gu_letter": "INTRO_LETTER_STORED" in state.narrative_flags, "photo_placed": "INTRO_MANQING_PHOTO_PLACED" in state.narrative_flags})
