class_name MirrorReunionView
extends Control

var _session: RunSession
var _screen: CounterScreen
var _pages: Array = []
var _page := 0
var _key := ""
var _pending := ""
var _collapsed := false
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _next: Button
var _wife: TextureRect
var _husband: TextureRect
var _notification := false
var _committing := false
var _last_press := 0
var _backdrop: TextureRect

func bind(session: RunSession, screen: CounterScreen) -> void:
	_session = session
	_screen = screen
	name = "MirrorReunion"
	z_index = 14
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = TextureRect.new()
	_backdrop.texture = preload("res://assets/art04/counter_room.png")
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.022, 0.02, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_wife = actor("res://assets/art02/customers/mirror_wife.svg", 0.08, 0.43)
	_husband = actor("res://assets/art02/customers/hawker.svg", 0.58, 0.91)
	var paper := PanelContainer.new()
	add_child(paper)
	bounds(paper, 0.06, 0.67, 0.94, 0.97)
	paper.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	paper.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_speaker = Label.new()
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.add_theme_font_size_override("font_size", 23)
	_speaker.add_theme_color_override("font_color", Color("302719"))
	header.add_child(_speaker)
	var close := Button.new()
	close.name = "CollapseDialogue"
	close.text = "收起 · Esc"
	close.custom_minimum_size = Vector2(128, 36)
	close.add_theme_font_size_override("font_size", 18)
	CounterTheme.style_paper_button(close)
	close.pressed.connect(collapse)
	header.add_child(close)
	_text = RichTextLabel.new()
	_text.name = "ReunionText"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_color_override("default_color", Color("302719"))
	_text.add_theme_constant_override("line_separation", 6)
	column.add_child(_text)
	_next = Button.new()
	_next.name = "AdvanceDialogue"
	_next.custom_minimum_size = Vector2(160, 38)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.add_theme_font_size_override("font_size", 20)
	CounterTheme.style_paper_button(_next)
	_next.pressed.connect(advance)
	column.add_child(_next)
	_choices = VBoxContainer.new()
	_choices.name = "ReunionChoices"
	add_child(_choices)
	bounds(_choices, 0.54, 0.43, 0.94, 0.65)
	_choices.add_theme_constant_override("separation", 8)
	session.changed.connect(func() -> void: refresh.call_deferred())
	session.restored.connect(reset)
	screen.get_node("%ScreenFlowCoordinator").active_panel_changed.connect(func(id: StringName) -> void:
		if id == &"risk" and MirrorEndingService.active(_session._day.state): reopen.call_deferred()
	)
	hide()
	refresh()

func bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left; control.anchor_top = top; control.anchor_right = right; control.anchor_bottom = bottom

func actor(path: String, left: float, right: float) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = load(path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	bounds(portrait, left, 0.025, right, 0.67)
	return portrait

func reset() -> void:
	_key = ""; _pending = ""; _page = 0; _notification = false; _collapsed = false
	hide()
	refresh.call_deferred()

func collapse() -> void:
	_collapsed = true
	hide()
	_screen._close_drawer()

func reopen() -> void:
	_collapsed = false
	refresh()

func refresh() -> void:
	if _committing: return
	var state := _session._day.state
	if not MirrorEndingService.active(state):
		if not _notification: hide()
		return
	var row := state.mirror_resolution
	var key: String = row.visit_id + "/" + str(row.step)
	if key != _key:
		_key = key; _pending = ""; _page = 0; _collapsed = false; _notification = false
		_pages = [["", "铜镜摆在柜前。丈夫站在一旁，等你开口。"]] if row.history.is_empty() else MirrorReunionService.pages(row.history.back().action, state)
	if _collapsed: return
	_screen._close_drawer()
	show()
	display_page()

func display_page() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child); child.queue_free()
	var line: Array = _pages[_page]
	_speaker.text = "镜前" if line[0].is_empty() else line[0]
	_text.text = line[1]
	_text.scroll_to_line(0)
	_wife.modulate = Color.WHITE if line[0] == "女子" else Color(0.60, 0.65, 0.62)
	_husband.modulate = Color.WHITE if line[0] == "丈夫" else Color(0.60, 0.60, 0.55)
	_wife.visible = _session._day.state.mirror_resolution.get("step", 0) > 0
	var last := _page == _pages.size() - 1
	_husband.visible = true
	if _notification or (last and not _pending.is_empty()):
		var ending: String = _session._day.state.mirror_resolution.ending if _notification else _pending
		_wife.visible = ending == "resentment"
		_husband.visible = ending != "resentment"
	_next.visible = not last or not _pending.is_empty() or _notification
	_next.text = "继续 ▸" if not last else ("收好记事" if _notification else "结束这段对话")
	if _next.visible: _next.grab_focus()
	if not last or not _pending.is_empty() or _notification: return
	for action in MirrorReunionService.actions(_session._day.state): add_choice(action[0], action[1] + " · 5分钟")
	# Keep the physical warning together with the lethal choice.
	if _session._day.state.mirror_resolution.get("husband", "") == "angry":
		_text.text = "女子的手穿过镜面，抓住丈夫的影子。他后退却挣不开。\n女子：你不肯回来，那就跟我走！"

func add_choice(command: String, label: String) -> void:
	var button := Button.new()
	button.name = "Reunion_" + command
	button.text = label
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 20)
	CounterTheme.style_paper_button(button)
	_choices.add_child(button)
	var error := MirrorEndingService.reason(_session._day, _session._counter.catalog, command, _session._day.state.mirror_resolution.visit_id)
	button.tooltip_text = error
	button.disabled = true
	var reference: WeakRef = weakref(button)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		var current := reference.get_ref() as Button
		if current != null:
			current.disabled = not error.is_empty()
			if current.get_index() == 0 and current.is_visible_in_tree() and not current.disabled: current.grab_focus()
	)
	button.pressed.connect(func() -> void: choose(command))

func choose(command: String) -> void:
	var id: String = _session._day.state.mirror_resolution.visit_id
	var error := MirrorEndingService.reason(_session._day, _session._counter.catalog, command, id)
	if not error.is_empty(): _text.text = error; return
	if command in MirrorReunionService.ENDINGS:
		# Read the final scene before the single atomic domain commit. No preview
		# changes the item, person, time, journal, resources or save file.
		_pending = command; _page = 0
		_pages = MirrorReunionService.pages(command, _session._day.state)
		display_page()
		return
	var result := _session.mirror_resolution_command(command, id)
	if not result.ok: _text.text = result.message; return
	if command == "pause": _collapsed = true; _pending = ""; hide(); _screen._close_drawer()
	else: refresh()

func advance() -> void:
	if Time.get_ticks_msec() - _last_press < 180: return
	_last_press = Time.get_ticks_msec()
	if _page < _pages.size() - 1:
		_page += 1; display_page(); return
	if _notification:
		_notification = false; _pending = ""; collapse(); return
	if _pending.is_empty(): return
	_committing = true
	var result := _session.mirror_resolution_command(_pending, _session._day.state.mirror_resolution.visit_id)
	_committing = false
	if not result.ok: _text.text = result.message; return
	_pending = ""; _notification = true; _page = 0
	var notice := MirrorReunionService.note(_session._day.state).split("\n\n", false, 1)
	_pages = [[notice[0], notice[1]]]
	display_page()
	show()

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_cancel"):
		collapse(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _next.visible and get_viewport().gui_get_focus_owner() == _next:
		advance(); get_viewport().set_input_as_handled()
