class_name RiskPresenter
extends Node

signal route_requested(panel_id: StringName)
var _session: RunSession
var _view: RiskPanel
var _held: Array = []
var _pending := ""
var _phase := ""
var _intrusion := false
var _attention := ""
var _record_id := ""

func bind(session: RunSession, view: RiskPanel) -> void:
	_session = session
	_view = view
	_view.intent.connect(_choose)
	_view.record_selected.connect(func(id: String) -> void: _record_id = id; refresh())
	_session.restored.connect(func() -> void: _record_id = "")
	_session.changed.connect(refresh)
	_view.visibility_changed.connect(func() -> void:
		if _view.is_visible_in_tree(): refresh()
	, CONNECT_DEFERRED)
	_session.restored.connect(func() -> void: _pending = ""; _phase = ""; _attention = ""; _intrusion = false; _held.clear(); _view.show_notes(false))
	refresh()

func refresh() -> void:
	var model := _session.risk_signal_model()
	var reunion := MirrorReunionService.enabled(_session.definition) and MirrorEndingService.active(_session._day.state)
	if _view.is_visible_in_tree() and not reunion:
		var page := _session.risk_model(_record_id)
		_record_id = page.record_id
		_view.render(page)
	var phase: String = _session._day.state.phase
	var intrusion: bool = model.get("intrusion", false)
	var attention: String = model.get("attention_id", "")
	var needs_attention: bool = (not attention.is_empty() and attention != _attention) or (intrusion and not _intrusion and phase == "closed_processing") or (model.held_ids != _held and not model.held_ids.is_empty()) or (model.pending_id != _pending and not model.pending_id.is_empty()) or (phase == "dead" and _phase != phase)
	_attention = attention
	_held = model.held_ids.duplicate()
	_pending = model.pending_id
	_phase = phase
	_intrusion = intrusion
	if needs_attention and not reunion and _session._day.state.pending_event_id.is_empty():
		_view.show_notes(false)
		_view.reset_reading_position()
		route_requested.emit(&"risk")

func _choose(command: String, id: String, _detail: String, _amount: int) -> void:
	if command == "open_investigation": route_requested.emit(&"investigation"); return
	var result := _session.risk_command(command, id, _detail)
	_view.show_notes(command == "study" and result.ok)
