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
	_session.restored.connect(_view.close_private_panels)
	refresh()

func _execute(command: String) -> void:
	_error = ""
	var result := _session.execute("finish_sleep" if command == "relax_sleep" else command)
	if result.ok and command == "relax_sleep":
		var state := _session.read_state()
		# Keep ending summaries and pending story choices; otherwise wake next day.
		if state.phase == "day_summary" and state.current_night_index < _session.definition.total_nights and _session.can_execute("continue_run"):
			result = _session.execute("continue_run")
	if not result.ok: _error = result.message
	refresh()
	if result.ok and command in RoomKeepsakes.COMMANDS: _view.close_private_panels()
	if not result.ok and not _view.visible: _view.show_transition_error(result.message)

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
	var grade := NightMarketRisk.lamp_level(_session._day.state)
	if grade > 0 and state.phase != "dead": lamp = NightMarketRisk.LAMPS[grade]
	var lamp_state: Dictionary = PersonalRisk.lamp_state(_session._day.state) if state.get("personal_risk_enabled", false) else {}
	if not lamp_state.is_empty():
		lamp = lamp_state.description
		haunting = lamp_state.damage > 0
	var body := "铺门已经落闩。楼板下偶尔传来木头收缩的轻响。\n\n可以看看书桌与命灯，也可以就寝。"
	if state.phase == "sleep_resolution": body = "更声隔着窗纸传来。你躺下来，等这座城慢慢安静。"
	if state.phase == "dead": body = "灯盏已经冷透。床边那张旧当票，再没有人伸手去接。"
	if state.get("personal_risk_enabled", false):
		if state.phase == "dead" and not state.death_archive.is_empty(): body = state.death_archive.back().cause
		elif state.phase == "sleep_resolution" and RoomFlow.response(_session._day.state, int(state.current_night_index), "personal") == "defy": body = "你捂着胸口喘了许久。床边那道影子退开了，寒意却还留在骨头里。"
	if state.phase == "dead" and grade == 5: body = "柜下传来湿布展开的声音。窗纸透出一点白，屋里却已经没有自己的影子。"
	if grade > 0: body += "\n\n" + lamp
	var bedroom_death: bool = state.phase == "dead" and (state.get("personal_death_phase", "") in ["private_room", "sleep_resolution"] if state.get("personal_risk_enabled", false) else not state.room_history.is_empty() and state.room_history.back().action in ["personal_defy", "finish_sleep"])
	var keepsakes := RoomKeepsakes.read_model(_session._day.state)
	keepsakes.available = keepsakes.available and not _session.mirror_pending()
	_view.render({"keepsakes": keepsakes, "lamp_state": lamp_state, "lamp_grade": grade, "visible": state.room_enabled and (state.phase in ["private_room", "sleep_resolution"] or bedroom_death), "phase": state.phase, "night": state.current_night_index, "body": body, "lamp": lamp, "haunting": haunting or grade > 0, "dead": state.phase == "dead", "pending": not state.risk_pending.is_empty(), "can_sleep": _session.can_execute("sleep"), "can_finish": _session.can_execute("finish_sleep"), "error": _error, "gu_letter": "INTRO_LETTER_STORED" in state.narrative_flags, "photo_placed": keepsakes.photo_placed})
