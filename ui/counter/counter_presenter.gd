class_name CounterPresenter
extends Node

var _session: RunSession
var _view: CounterView

func bind(session: RunSession, view: CounterView) -> void:
	_session = session
	_view = view
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	_view.render(_session.counter_model())
