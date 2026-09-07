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

func bind(session: RunSession, view: RiskPanel) -> void:
	_session = session
	_view = view
	_view.intent.connect(_choose)
	_session.changed.connect(refresh)
	_session.restored.connect(func() -> void: _pending = ""; _phase = ""; _attention = ""; _intrusion = false; _held.clear())
	refresh()

func refresh() -> void:
	var model := _session.risk_model()
	_view.render(model)
	var phase: String = _session.read_state().phase
	var intrusion: bool = model.get("intrusion", false)
	var attention: String = model.get("attention_id", "")
	var needs_attention: bool = (not attention.is_empty() and attention != _attention) or (intrusion and not _intrusion and phase == "closed_processing") or (model.held_ids != _held and not model.held_ids.is_empty()) or (model.pending_id != _pending and not model.pending_id.is_empty()) or (phase == "dead" and _phase != phase)
	_attention = attention
	_held = model.held_ids.duplicate()
	_pending = model.pending_id
	_phase = phase
	_intrusion = intrusion
	if needs_attention and _session.read_state().pending_event_id.is_empty():
		_view.reset_reading_position()
		route_requested.emit(&"risk")

func _choose(command: String, id: String, _detail: String, _amount: int) -> void:
	_session.risk_command(command, id)
