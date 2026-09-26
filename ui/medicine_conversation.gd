class_name MedicineConversation
extends FirstDebtConversation

func bind(value: RunSession, owner_screen: CounterScreen) -> void:
	super.bind(value, owner_screen)
	name = "MedicineConversation"
	for overlay in [screen._receipt,screen._departure,screen._narrative]:
		overlay.visibility_changed.connect(func() -> void: refresh.call_deferred())

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		collapse(); get_viewport().set_input_as_handled()

func refresh() -> void:
	if _committing: return
	var next_model := MedicineStory.dialogue(session._day.state)
	if next_model.is_empty():
		_model = {}; hide(); return
	_model = next_model
	var key: String = session._day.state.run_token + "/" + _model.key
	if key != _auto_seen and not screen._receipt.visible and not screen._departure.visible and not screen._narrative.visible:
		_auto_seen = key
		reopen()

func _acknowledge() -> bool:
	if _model.is_empty(): return true
	_committing = true
	var result := session.execute("medicine_talk", _model.key)
	_committing = false
	if not result.ok:
		_error = result.message; display_page(); return false
	_model = {}; _auto_seen = ""
	return true

func collapse() -> void:
	# Escape advances to the final paragraph first, so the request cannot be silently skipped.
	if not _model.is_empty() and _page < _pages.size()-1:
		_page = _pages.size()-1; display_page(); return
	if not _acknowledge(): return
	hide()
	release_counter()
