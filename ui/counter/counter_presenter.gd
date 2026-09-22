class_name CounterPresenter
extends Node

var _session: RunSession
var _view: CounterView

func bind(session: RunSession, view: CounterView) -> void:
	_session = session
	_view = view
	_view.story_choice_requested.connect(_choose_story)
	_view.companion.choice_requested.connect(_choose_companion)
	_session.restored.connect(_view.companion.reset)
	_session.changed.connect(refresh)
	refresh()

func refresh(force := false) -> void:
	# The reunion owns the visible counter. Rebuild this covered surface on collapse.
	if not force and MirrorReunionService.enabled(_session.definition) and MirrorEndingService.active(_session._day.state): return
	_view.render(_session.counter_model())
	_view.bell.render(_session.bell_model())
	var pending: String = _session._day.state.pending_event_id
	var event := _session._counter.catalog.get_definition("events", pending) as EventDefinition if not pending.is_empty() else null
	var story := _session.event_model() if event != null and event.presentation.get("scene", "") == "aqi_counter" else {}
	var state := _session.read_state()
	_view.render_story(story if story.get("presentation", {}).get("scene", "") == "aqi_counter" else {}, state)
	_view.companion.render(_session.companion_model())

func _choose_story(event_id: String, choice_id: String) -> void:
	var result := _session.event_command(event_id, choice_id)
	if not result.ok: _view.story.show_error(result.message)

func _choose_companion(event_id: String, choice_id: String) -> void:
	var result := _session.event_command(event_id, choice_id)
	if not result.ok: _view.companion.dialogue.show_error(result.message)
