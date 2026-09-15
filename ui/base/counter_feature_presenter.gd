class_name CounterFeaturePresenter
extends Node

var _session: RunSession
var _view: IntentPanel

func feature_key() -> String:
	return ""

func bind(session: RunSession, view: IntentPanel) -> void:
	_session = session
	_view = view
	_view.intent.connect(_on_intent)
	_session.changed.connect(refresh)
	_view.visibility_changed.connect(refresh)
	refresh()

func refresh() -> void:
	# Hidden drawers read current state when opened; no eager rebuild per action.
	if not _view.is_visible_in_tree(): return
	_view.render(_session.counter_model()[feature_key()])

func _on_intent(command: String, visit_id: String, detail: String, amount: int) -> void:
	_session.counter_command(command, visit_id, detail, amount)
