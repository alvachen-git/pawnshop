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
	_view.visibility_changed.connect(refresh, CONNECT_DEFERRED)
	_session.restored.connect(func() -> void: _pending = "")
	refresh()

func refresh() -> void:
	var state := _session._day.state
	var pending: String = state.pending_event_id if state.risk_pending.is_empty() else ""
	if _view.is_visible_in_tree(): _view.render(_session.event_model())
	if pending != _pending:
		_pending = pending
		if not pending.is_empty():
			var event := _session._counter.catalog.get_definition("events", pending) as EventDefinition
			if event.presentation.is_empty(): route_requested.emit(&"events")

func _choose(_command: String, event_id: String, choice_id: String, _amount: int) -> void:
	_session.event_command(event_id, choice_id)
