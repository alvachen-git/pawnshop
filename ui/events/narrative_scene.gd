class_name NarrativeScene
extends Control

signal menu_requested

var _session: RunSession
var _title: Label
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _skip: Button
var _menu_button: Button
var _scene := ""
var _signature := ""
var _model: Dictionary = {}
var _dialogue_page := 0
var _audio: AudioStreamPlayer
var _door_audio: AudioStreamPlayer
var _heard_scene := ""
var _backdrop: Control
var _shade: ColorRect
var _brand: Label
var _reading: PanelContainer

const OpeningBackdrop = preload("res://ui/events/opening_backdrop.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 15
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -23
	add_child(_audio)
	_door_audio = AudioStreamPlayer.new()
	_door_audio.stream = preload("res://assets/opening/wooden_door_open.wav")
	_door_audio.volume_db = -10
	add_child(_door_audio)
	_backdrop = OpeningBackdrop.new()
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://ui/events/narrative_shade.gdshader")
	_shade.material = shade_material
	add_child(_shade)
	_reading = PanelContainer.new()
	_reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reading.add_theme_stylebox_override("panel", CounterTheme.box("201f1aec", "00000000", 0, 0))
	add_child(_reading)
	_brand = _label(self, 28, "ead8b4")
	_brand.text = "鬼 市 当 铺"
	_title = _label(self, 18, "c9b68f")
	_speaker = _label(self, 14, "bdaa84")
	_text = RichTextLabel.new()
	_text.name = "NarrativeText"
	_text.add_theme_font_override("normal_font", CounterTheme.display_font())
	_text.add_theme_color_override("default_color", Color("eee1c8"))
	_text.add_theme_constant_override("line_separation", 5)
	_text.bbcode_enabled = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.language = "zh_CN"
	_text.clip_contents = true
	add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "NarrativeChoices"
	_choices.add_theme_constant_override("separation", 8)
	add_child(_choices)
	_skip = Button.new()
	_skip.text = tr("opening.skip")
	_style_quiet_button(_skip)
	_skip.pressed.connect(_skip_prologue)
	add_child(_skip)
	_menu_button = Button.new()
	_menu_button.text = "菜单"
	_style_quiet_button(_menu_button)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(_menu_button)
	resized.connect(_layout)
	_layout()
	hide()

func _style_quiet_button(button: Button) -> void:
	button.add_theme_font_override("font", CounterTheme.display_font())
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, CounterTheme.box("1b1b18aa" if state == "normal" else "37362cee", "00000000", 12, 6))
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", Color("eee1c8"))
	button.add_theme_color_override("font_focus_color", Color("fff0ce"))

func _layout() -> void:
	if _text == null or size.x <= 0 or size.y <= 0: return
	var scale := minf(size.x / 1280.0, size.y / 720.0)
	var margin := 46.0 * scale
	var body_font := maxi(18, roundi(22.0 * scale))
	_text.add_theme_font_size_override("normal_font_size", body_font)
	_title.add_theme_font_size_override("font_size", roundi(18 * scale))
	_speaker.add_theme_font_size_override("font_size", roundi(14 * scale))
	_brand.add_theme_font_size_override("font_size", roundi(28 * scale))
	_brand.position = Vector2(24, 16) * scale
	_brand.size = Vector2(290, 46) * scale
	_menu_button.position = Vector2(size.x - 100 * scale, 18 * scale)
	_menu_button.size = Vector2(78, 38) * scale
	_menu_button.add_theme_font_size_override("font_size", roundi(18 * scale))
	_skip.position = Vector2(size.x - 332 * scale, 18 * scale)
	_skip.size = Vector2(218, 38) * scale
	_skip.add_theme_font_size_override("font_size", roundi(16 * scale))
	var count := _choices.get_child_count()
	for button in _choices.get_children():
		button.custom_minimum_size.y = 44 * scale
		button.add_theme_font_size_override("font_size", roundi(22 * scale))
	_choices.add_theme_constant_override("separation", roundi(8 * scale))
	var long_letter := _scene == "letter"
	_reading.visible = long_letter
	_shade.visible = not long_letter
	if long_letter:
		_speaker.show()
		# The inherited letter remains a scrollable document; short scenes use subtitles.
		_reading.position = Vector2(size.x * 0.49, 76 * scale)
		_reading.size = Vector2(size.x * 0.47, size.y - 110 * scale)
		var left := _reading.position.x + 26 * scale
		var width := _reading.size.x - 52 * scale
		_title.position = Vector2(left, 99 * scale)
		_title.size = Vector2(width, 28 * scale)
		_speaker.position = Vector2(left, 132 * scale)
		_speaker.size = Vector2(width, 24 * scale)
		_text.position = Vector2(left, 175 * scale)
		_text.size = Vector2(width, size.y - 298 * scale)
		_choices.position = Vector2(left, size.y - 95 * scale)
		_choices.size = Vector2(width, 48 * scale)
		return
	var has_dialogue_pages: bool = not _model.get("presentation", {}).get("dialogue_pages", []).is_empty()
	var actions_width := (350.0 if has_dialogue_pages else (302.0 if count > 1 else 204.0)) * scale
	var text_width := size.x - margin * 3 - actions_width
	var lines := 0
	var font := CounterTheme.display_font()
	for paragraph in _text.text.split("\n"):
		lines += maxi(1, ceili(font.get_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, -1, body_font).x / text_width))
	var line_height := font.get_height(body_font) + 5.0
	var text_height := clampf(lines * line_height + 8 * scale, 110 * scale, size.y * 0.29)
	var actions_height := count * 44 * scale + maxi(0, count - 1) * 8 * scale
	var height := maxf(text_height + 70 * scale, actions_height + 38 * scale)
	var top := size.y - height
	_shade.position = Vector2(0, top - 30 * scale)
	_shade.size = Vector2(size.x, height + 30 * scale)
	_title.position = Vector2(margin, top + 10 * scale)
	_title.size = Vector2(text_width, 27 * scale)
	_speaker.position = Vector2(margin, top - 15 * scale)
	_speaker.size = Vector2(text_width, 20 * scale)
	# Location already carries the scene context; speaker shown only where meaningful.
	_speaker.visible = _scene in ["factory", "memory", "stamp", "customer"]
	_text.position = Vector2(margin, top + 47 * scale)
	_text.size = Vector2(text_width, height - 60 * scale)
	_choices.position = Vector2(size.x - margin - actions_width, size.y - actions_height - 28 * scale)
	_choices.size = Vector2(actions_width, actions_height)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		_audio.stop()
		_heard_scene = ""
		return
	if _scene != _heard_scene:
		_heard_scene = _scene
		var sound: String = {"factory": "factory", "key": "key", "customer": "clock", "sleep": "floor"}.get(_scene, "paper")
		if _scene == "exterior" or _door_audio.playing:
			_audio.stop()
			return
		_audio.stream = load("res://assets/opening/" + sound + ".wav")
		_audio.play()
	elif _scene == "factory" and not _audio.playing:
		_audio.play()

func bind(session: RunSession) -> void:
	_session = session
	_session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var pending: String = _session._day.state.pending_event_id
	var event := _session._counter.catalog.get_definition("events", pending) as EventDefinition if not pending.is_empty() else null
	if event == null or not _session._day.state.risk_pending.is_empty() or event.presentation.is_empty() or event.presentation.get("scene", "") in ["aqi_counter", "mirror_dream"]:
		hide(); _signature = ""; return
	_model = _session.event_model()
	visible = not _model.presentation.is_empty() and _model.presentation.get("scene", "") not in ["aqi_counter", "mirror_dream"]
	if not visible:
		_signature = ""
		return
	_scene = _model.presentation.scene
	var state := _session.read_state()
	var signature: String = state.run_token + "/" + _model.pending_id + "/" + str(state.event_history.size())
	if _scene == "inspection":
		var meta := ConfigFile.new()
		meta.set_value("opening", "seen", true)
		meta.save(_session._save.path + ".meta")
	var meta := ConfigFile.new()
	_skip.visible = _model.presentation.get("repeat_skip", false) and meta.load(_session._save.path + ".meta") == OK and meta.get_value("opening", "seen", false)
	if signature == _signature: return
	_signature = signature
	_dialogue_page = 0
	_title.text = _model.title
	_speaker.text = _model.speaker
	var body: String = _model.text + ("\n\n" + _model.feedback if not _model.feedback.is_empty() else "")
	_text.text = body if _scene == "letter" else body.replace("\n\n", "\n")
	_text.scroll_to_line(0)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for entry in _model.buttons:
		var button := Button.new()
		button.name = "Choice_" + entry.detail
		button.text = entry.label
		button.custom_minimum_size.y = 44
		CounterTheme.style_paper_button(button)
		button.disabled = not entry.enabled
		button.pressed.connect(_choose.bind(entry.target_id, entry.detail))
		_choices.add_child(button)
	if _choices.get_child_count() > 0: _choices.get_child(0).grab_focus()
	var focusable: Array[Control] = []
	for button in _choices.get_children(): focusable.append(button)
	if _skip.visible: focusable.append(_skip)
	focusable.append(_menu_button)
	for index in focusable.size():
		var button := focusable[index]
		button.focus_next = button.get_path_to(focusable[(index + 1) % focusable.size()])
		button.focus_previous = button.get_path_to(focusable[(index - 1 + focusable.size()) % focusable.size()])
	_backdrop.present(_scene, state.narrative_flags, String(_model.pending_id).begins_with("evt_intro_gu_"))
	_present_dialogue_page()
	_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _present_dialogue_page() -> void:
	var pages: Array = _model.get("presentation", {}).get("dialogue_pages", [])
	if pages.is_empty(): return
	var prefix: String = pages[_dialogue_page]
	_title.text = tr(prefix + ".title")
	_speaker.text = tr(prefix + ".speaker")
	_text.text = tr(prefix + ".body")
	_text.scroll_to_line(0)
	if _choices.get_child_count() == 1:
		_choices.get_child(0).text = tr(prefix + ".continue")

func _choose(id: String, choice: String) -> void:
	var pages: Array = _model.get("presentation", {}).get("dialogue_pages", [])
	if _dialogue_page + 1 < pages.size():
		_dialogue_page += 1
		_present_dialogue_page()
		_layout()
		return
	var opens_door: bool = _model.get("pending_id", "") == "evt_intro_shop_arrival" and choice == "enter"
	var result := _session.event_command(id, choice)
	if result.ok and opens_door:
		_audio.stop()
		_door_audio.play()
	if not result.ok: _text.text += "\n\n" + result.message

func _skip_prologue() -> void:
	# Replay the same zero-cost choices; preserve flags and checkpoint validation.
	for step in 40:
		var model := _session.event_model()
		if not model.presentation.get("repeat_skip", false) or model.buttons.is_empty(): break
		var first: Dictionary = model.buttons[0]
		var result := _session.event_command(first.target_id, first.detail)
		if not result.ok:
			_text.text += "\n\n" + result.message
			break

func _label(parent: Node, font_size: int, color: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_font_override("font", CounterTheme.display_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
