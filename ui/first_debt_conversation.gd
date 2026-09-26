class_name FirstDebtConversation
extends Control

# Uses the mirror reunion's existing paper, bottom dialogue and separate choices.
# Page cursors are presentation only. All choices use the atomic event command.
var session: RunSession
var screen: CounterScreen
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _next: Button
var _pages: Array[String] = []
var _page := 0
var _model: Dictionary = {}
var _auto_seen := ""
var _result := false
var _committing := false
var _last_press := 0
var _error := ""
var _result_speaker := ""
var _close_after_result := false
var _pre_open_result := false

func bind(value: RunSession, owner_screen: CounterScreen) -> void:
	session = value; screen = owner_screen
	name = "FirstDebtConversation"
	z_index = 13
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := PanelContainer.new()
	add_child(paper)
	CounterView._bounds(paper, 0.06, 0.67, 0.94, 0.90)
	paper.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	paper.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_speaker = Label.new()
	_speaker.text = "陈小满"
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color("302719"))
	header.add_child(_speaker)
	var close := Button.new()
	close.text = "收起 · Esc"
	close.custom_minimum_size = Vector2(120, 30)
	CounterTheme.style_paper_button(close)
	close.pressed.connect(collapse)
	header.add_child(close)
	_text = RichTextLabel.new()
	_text.name = "CaseText"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_color_override("default_color", Color("302719"))
	_text.add_theme_constant_override("line_separation", 5)
	column.add_child(_text)
	_next = Button.new()
	_next.name = "CaseAdvance"
	_next.custom_minimum_size = Vector2(150, 32)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	CounterTheme.style_paper_button(_next)
	_next.pressed.connect(advance)
	column.add_child(_next)
	_choices = VBoxContainer.new()
	_choices.name = "CaseChoices"
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 6)
	add_child(_choices)
	CounterView._bounds(_choices, 0.57, 0.38, 0.94, 0.655)
	session.changed.connect(func() -> void: refresh.call_deferred())
	session.restored.connect(func() -> void: _auto_seen = ""; _result = false; release_counter(); hide(); refresh.call_deferred())
	hide()

static func pages(text: String, short_sentences: bool = false) -> Array[String]:
	var result: Array[String] = []
	for paragraph in text.split("\n", false):
		var line := ""
		for index in paragraph.length():
			var character := paragraph[index]
			line += character
			var closing_quote_next := index + 1 < paragraph.length() and paragraph[index + 1] in ["”", "’"]
			if (short_sentences or line.length() >= 65) and character in ["。", "；", "？", "！", "”", "’"] and not closing_quote_next:
				result.append(line); line = ""
		if not line.is_empty(): result.append(line)
	if result.is_empty(): result.append("陈小满在柜前等你开口。")
	return result

func refresh() -> void:
	if _committing: return
	var next_model: Dictionary = session.counter_model().get("case_dialogue", {})
	if _result:
		if not _result_context_valid():
			_result = false; release_counter(); hide()
		return
	if next_model.is_empty():
		_model = {}; _result = false; hide(); return
	_model = next_model
	if _model.auto_open:
		var key: String = session._day.state.run_token + "/" + _model.key
		if key != _auto_seen and not screen._receipt.visible and not screen._departure.visible and not screen._narrative.visible:
			_auto_seen = key
			reopen()

func reopen() -> void:
	if _model.is_empty(): return
	screen._close_drawer()
	screen._counter_view.dismiss_contexts()
	if not _result:
		_pages = pages(_model.text, _model.get("sentence_pages", false)); _page = 0; _error = ""
	show(); display_page()

func collapse() -> void:
	if not _acknowledge(): return
	_result = false
	release_counter()
	hide()
	var target := screen._counter_view.get_hotspot(&"customer")
	if not target.visible: target = screen._counter_view.get_hotspot(&"shop")
	target.grab_focus()

func focus_action() -> void:
	if _next.visible: _next.grab_focus()
	elif _choices.get_child_count() > 0: _choices.get_child(0).grab_focus()

func display_page() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child); child.queue_free()
	var text := _pages[_page]
	_speaker.text = _result_speaker if _result and not _result_speaker.is_empty() else str(_model.get("speaker", speaker_for(_pages, _page)))
	if not _result and _model.has("narration_speaker"):
		var quote_depth := 0
		for previous in range(_page):
			quote_depth += _pages[previous].count("‘") + _pages[previous].count("“") - _pages[previous].count("’") - _pages[previous].count("”")
		if quote_depth <= 0 and not text.begins_with("‘") and not text.begins_with("“"):
			_speaker.text = _model.narration_speaker
	_text.text = text + ("\n" + _error if not _error.is_empty() else "")
	_text.scroll_to_line(0)
	var last := _page == _pages.size() - 1
	_next.visible = not last or _result or _model.get("buttons", []).is_empty()
	_next.text = "继续 ▸" if not last else "说完了"
	if _next.visible: _next.grab_focus()
	if not last or _result: return
	for entry in _model.buttons:
		var button := Button.new()
		button.text = entry.label
		if not entry.enabled and not str(entry.reason).is_empty():
			button.text += "（" + str(entry.reason).trim_suffix("。") + "）"
		button.name = "Case_" + entry.target_id + "_" + entry.detail
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size", 18)
		CounterTheme.style_paper_button(button)
		button.disabled = not entry.enabled
		button.tooltip_text = entry.reason
		button.pressed.connect(func() -> void: choose(entry))
		_choices.add_child(button)
	if _choices.get_child_count() > 0: _choices.get_child(0).grab_focus()

func choose(entry: Dictionary) -> void:
	if _committing: return
	_last_press = Time.get_ticks_msec(); _committing = true
	screen._counter_view.conversation_held = true
	var result := session.counter_command(entry.get("command", "fd_event"), entry.target_id, entry.detail)
	_committing = false
	if not result.ok:
		release_counter(); _error = result.message; display_page(); return
	_close_after_result = entry.target_id in ["fd_search_motive", "fd_dragon_deal"] or (DragonSearch.enabled(session._day.state) and entry.target_id in ["fd_settle", "fd_followup", "fd_meeting_end"])
	_pre_open_result = bool(_model.get("pre_open_story", false))
	_result_speaker = str(_model.get("narration_speaker", _model.get("speaker", "")))
	_model = session.counter_model().get("case_dialogue", {})
	if _pre_open_result and not _model.is_empty():
		_auto_seen = session._day.state.run_token + "/" + str(_model.key)
	# Sun's intermediate replies are already the next authored speech.
	if _pre_open_result and result.message.is_empty():
		_result = false; release_counter()
		if _model.is_empty(): hide()
		else: reopen()
		return
	# The action may admit the next ordinary guest. Finish this short reply
	# against Chen's retained counter art, then reveal the unchanged new visit.
	if not _result_context_valid():
		_result = false; release_counter(); hide(); return
	_pages = pages(result.message, _pre_open_result); _page = 0; _result = true; _error = ""
	display_page()

func _result_context_valid() -> bool:
	var state := session._day.state
	if not state.risk_pending.is_empty() or session.mirror_pending(): return false
	if _pre_open_result:
		return state.phase == &"pre_open" and (state.pending_event_id.is_empty() or MilitaryIntroduction.active(state) or LuIntroduction.active(state) or SilverPolicy.active(state))
	return state.phase == &"open" and state.pending_event_id.is_empty()

func _acknowledge() -> bool:
	var id: String = _model.get("ack_event", "")
	if id.is_empty() or not PhoenixRecovery.hint_due(session._day.state): return true
	_committing = true
	var result := session.event_command(id, "heard")
	_committing = false
	if not result.ok:
		_error = result.message; display_page(); return false
	_model = {}; _auto_seen = ""
	return true

func advance() -> void:
	if Time.get_ticks_msec() - _last_press < 180: return
	_last_press = Time.get_ticks_msec()
	if _page < _pages.size() - 1:
		_page += 1; display_page(); return
	if not _acknowledge(): return
	_result = false
	release_counter()
	if _close_after_result or _model.get("buttons", []).is_empty():
		_close_after_result = false
		collapse(); return
	_pages = pages(_model.text, _model.get("sentence_pages", false)); _page = 0; display_page()

func release_counter() -> void:
	screen._counter_view.conversation_held = false
	screen._counter_view.release_feedback()

static func speaker_for(lines: Array[String], index: int) -> String:
	if not lines[index].begins_with("“") and not lines[index].begins_with("‘"): return "柜前"
	for previous in range(index - 1, -1, -1):
		if lines[previous].begins_with("你"): return "掌柜"
		if lines[previous].begins_with("陈小满") or lines[previous].begins_with("她"): return "陈小满"
	return "陈小满"
