class_name EventPresenter
extends Node

signal route_requested(panel_id: StringName)
var _session: RunSession
var _view: EventPanel
var _pending := ""

func bind(session: RunSession, view: EventPanel) -> void:
	_session = session
	_view = view
	_view.intent.connect(_choose)
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var model := _session.event_model()
	_view.render(model)
	if model.pending_id != _pending:
		_pending = model.pending_id
		if not _pending.is_empty(): route_requested.emit(&"events")

func _choose(_command: String, event_id: String, choice_id: String, _amount: int) -> void:
	_session.event_command(event_id, choice_id)
