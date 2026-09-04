class_name CounterAtmospherePresenter
extends Node

const NORMAL := 0
const LATE := 1
const GHOST := 2
var preview_mode := -1
var current_mode := NORMAL
var _session: RunSession
var _view: CounterView
var _status: ShopStatusView

func bind(session: RunSession, view: CounterView, status: ShopStatusView) -> void:
	_session = session
	_view = view
	_status = status
	_session.changed.connect(refresh)
	refresh()

func set_preview(mode: int) -> void:
	preview_mode = clampi(mode, -1, 2)
	refresh()

func refresh() -> void:
	var state := _session.read_state()
	var risk := _session.risk_model()
	# Ghost-market gameplay is not implemented. Only the review selector uses GHOST.
	# Time darkens the room; actual risk evidence alone bends smoke / flame.
	current_mode = LATE if int(state.game_minutes) >= 300 or state.phase in ["closed_processing", "night_resolution", "day_summary", "dead"] or risk.intrusion else NORMAL
	if state.phase == "pre_open": current_mode = NORMAL
	if preview_mode >= 0: current_mode = preview_mode
	var intrusion: bool = risk.intrusion
	var haunting: bool = not state.risk_pending.is_empty()
	for encounter in state.get("mirror_history", []):
		if encounter.get("night", 0) == state.current_night_index and encounter.get("action", "") == "pursue": haunting = true
	for summary in state.summaries:
		if summary.outcome in ["mirror_scar", "mirror_survived", "mirror_death"]: haunting = true
	_view.set_atmosphere(current_mode, preview_mode >= 0, intrusion, haunting, state.phase == "dead")
	_status.render_snapshot(state, _session.definition, intrusion, haunting)
