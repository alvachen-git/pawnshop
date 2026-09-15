class_name CounterPresenter
extends Node

var _session: RunSession
var _view: CounterView

func bind(session: RunSession, view: CounterView) -> void:
	_session = session
	_view = view
	_view.story_choice_requested.connect(_choose_story)
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	_view.render(_session.counter_model())
	_view.bell.render(_session.bell_model())
	var story := _session.event_model()
	var state := _session.read_state()
	_view.render_story(story if story.get("presentation", {}).get("scene", "") == "aqi_counter" else {}, state)

func _choose_story(event_id: String, choice_id: String) -> void:
	var result := _session.event_command(event_id, choice_id)
	if not result.ok: _view.story.show_error(result.message)
