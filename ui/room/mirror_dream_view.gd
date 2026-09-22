class_name MirrorDreamView
extends Control

const PORTRAITS := {
	"waiting": preload("res://assets/mirror_dream/wife_waiting_blood_tears.png"),
	"sorrow": preload("res://assets/mirror_dream/wife_sorrow_blood_tears.png")
}

# Reading position is presentation-only. A restored unfinished dream starts here.
const PAGES := [
	["dream/arrival", "梦中", "你明明已经上床，却又坐在当铺柜后。\n铺里静得出奇，灯火泛着青色。"],
	["dream/voice", "梦中女子", "没听见脚步声，柜前却多了个女子。\n“掌柜，你听得见我吗？”"],
	["dream/waiting", "梦中女子", "“他走的时候，说挣到钱就回来。\n我带着孩子，一直等着。”"],
	["dream/illness", "梦中女子", "“我替人洗衣、缝补，勉强养着孩子。\n后来孩子病了，药钱怎么也凑不够。”"],
	["dream/mirror", "梦中女子", "“这面镜子是我娘留给我的。\n我舍不得，最后还是拿来当了。”"],
	["dream/request", "梦中女子", "“我离不开这面镜子。你能不能帮我找找他？\n我想亲口问问，他为什么一直不回来。”"],
	["dream/ticket", "梦中女子", "女子抬手指向身后的旧柜。\n“我当镜子的时候，铺里留过一张当票。也许还能找到。”"],
	["dream/waking", "梦中", "你一低头，再抬眼时，柜前已经空了。\n她的声音还在耳边，你却醒回了寝屋。"]
]
var _session: RunSession
var _screen: CounterScreen
var _page := 0
var _collapsed := false
var _active := false
var _busy := false
var _error := ""
var _last_press := 0
var _text: RichTextLabel
var _speaker: Label
var _next: Button
var _resume: Button
var _wife: TextureRect
var _audio: AudioStreamPlayer
var _heard := false
var _event_id := ""
var _background: TextureRect
var _choices: HBoxContainer
var _cry: AudioStreamPlayer
var _heard_call := ""

func bind(session: RunSession, screen: CounterScreen) -> void:
	_session = session; _screen = screen
	name = "MirrorDream"; z_index = 17
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	_background = background
	background.texture = preload("res://assets/art04/counter_room.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color(0.22, 0.26, 0.27)
	add_child(background)
	_wife = TextureRect.new()
	_wife.name = "DreamVisitor"
	_wife.texture = PORTRAITS.waiting
	_wife.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wife.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wife.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://ui/art/counter_cutout.gdshader")
	cutout.set_shader_parameter("chroma_key", true)
	cutout.set_shader_parameter("clean_chroma_edges", true)
	cutout.set_shader_parameter("dream_visitor", true)
	_wife.material = cutout
	# Stand in the normal customer lane; the dream never frames her in a mirror.
	add_child(_wife); _bounds(_wife, 0.315, 0.027, 0.68, 0.54)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	add_child(paper); _bounds(paper, 0.06, 0.67, 0.94, 0.97)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	paper.add_child(margin)
	var column := VBoxContainer.new(); margin.add_child(column)
	column.add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new(); column.add_child(header)
	_speaker = Label.new(); header.add_child(_speaker)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color("302719"))
	var close := _button("收起 · Esc"); close.name = "CollapseDream"
	header.add_child(close); close.pressed.connect(collapse)
	_text = RichTextLabel.new(); _text.name = "DreamText"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_color_override("default_color", Color("302719"))
	_text.add_theme_constant_override("line_separation", 4)
	column.add_child(_text)
	_choices = HBoxContainer.new(); _choices.name = "DoorChoices"
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 16)
	column.add_child(_choices)
	for option in [["inspect", "出去看看"], ["ignore", "继续睡"]]:
		var button := _button(option[1]); button.name = option[0]
		_choices.add_child(button)
		button.pressed.connect(_choose_call.bind(option[0]))
	_next = _button("继续 ▸"); _next.name = "AdvanceDream"
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_next); _next.pressed.connect(advance)
	_resume = _button("继续梦境"); _resume.name = "ResumeDream"; _resume.z_index = 16
	screen.add_child(_resume); _bounds(_resume, 0.72, 0.77, 0.92, 0.85)
	_resume.pressed.connect(reopen); _resume.hide()
	_audio = AudioStreamPlayer.new(); add_child(_audio)
	_audio.stream = MirrorReunionStage.make_sound("mirror"); _audio.volume_db = -28
	_cry = AudioStreamPlayer.new(); _cry.name = "DoorSobbing"; add_child(_cry)
	var sobbing := preload("res://assets/mirror_dream/audio/door-sobbing.wav").duplicate() as AudioStreamWAV
	sobbing.loop_begin = 0
	sobbing.loop_end = roundi(sobbing.get_length() * sobbing.mix_rate)
	sobbing.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cry.stream = sobbing
	_cry.volume_db = -8
	session.changed.connect(refresh)
	session.restored.connect(reset)
	hide(); refresh()

func _button(label: String) -> Button:
	var button := Button.new(); button.text = label
	button.custom_minimum_size = Vector2(140, 34)
	button.add_theme_font_size_override("font_size", 18)
	CounterTheme.style_paper_button(button)
	return button

func _bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left; control.anchor_top = top; control.anchor_right = right; control.anchor_bottom = bottom

func reset() -> void:
	_audio.stop(); _cry.stop(); _heard_call = ""; _event_id = ""
	_heard = false; _page = 0; _active = false; _collapsed = false; _error = ""
	refresh()

func refresh() -> void:
	if _busy: return
	var event_id := _session._day.state.pending_event_id
	var pending := event_id in [MirrorDreamService.EVENT, MirrorDreamService.CALL, MirrorDreamService.MORNING] and _session._day.state.risk_pending.is_empty()
	if not pending:
		_active = false; hide(); _resume.hide(); _audio.stop(); _cry.stop(); return
	if not _active or event_id != _event_id:
		_audio.stop(); _cry.stop(); _event_id = event_id
		_active = true; _page = 0; _collapsed = false; _error = ""; _heard = false
	visible = not _collapsed; _resume.visible = _collapsed
	if visible:
		_screen._close_drawer()
		display_page()

func display_page() -> void:
	var calling := _event_id == MirrorDreamService.CALL
	var morning := _event_id == MirrorDreamService.MORNING
	_choices.visible = calling; _next.visible = not calling
	_resume.text = "回到房门前" if calling else "继续回想" if morning else "继续梦境"
	_background.texture = preload("res://assets/bedroom/room-normal.png") if calling or morning else preload("res://assets/art04/counter_room.png")
	_background.modulate = Color(0.35, 0.36, 0.40) if calling else Color(1.0, 0.96, 0.85) if morning else Color(0.22, 0.26, 0.27)
	_wife.visible = not calling and not morning
	if calling:
		_speaker.text = "夜半"
		_text.text = "闭上眼睛，逐渐失去意识，但似乎有个声音。" if _error.is_empty() else _error
		var signature := _session._day.state.run_token + "/" + str(_session._day.state.current_night_index)
		if signature != _heard_call:
			_heard_call = signature; _cry.play()
		_choices.get_child(0).grab_focus()
		return
	if morning:
		_speaker.text = "天亮了 · 我"
		_text.text = ("我竟然还在床上……\n昨夜明明开门下了楼，难道是在做梦？" if _page == 0 else MirrorDreamService.morning_text(_session._day.state)) if _error.is_empty() else _error
		_next.text = "重试起身" if not _error.is_empty() else "继续 ▸" if _page == 0 else "起身"
		_next.grab_focus(); return
	_speaker.text = PAGES[_page][1]
	_text.text = PAGES[_page][2] if _error.is_empty() else _error
	if MirrorDreamService.call_enabled(_session.definition) and _error.is_empty():
		if _page == 0: _text.text = "你披上外衣，推开房门。\n一转眼，已经站在楼下的柜台后。"
		elif _page == 7: _text.text = "你想再问一句，女子的身影却淡了。\n柜前的灯一晃，四周都暗了下来。"
	_text.scroll_to_line(0)
	_wife.texture = PORTRAITS.sorrow if _page in [3, 4] else PORTRAITS.waiting
	_wife.modulate = Color(0.69, 0.79, 0.81, 0.92 if _page in range(1, 7) else 0.0)
	_next.text = "重试醒来" if not _error.is_empty() else "醒来" if _page == 7 else "继续 ▸"
	_next.grab_focus()
	if _page == 1 and not _heard:
		_heard = true; _audio.play()

func collapse() -> void:
	_audio.stop()
	if _event_id != MirrorDreamService.CALL: _cry.stop()
	_collapsed = true; hide(); _resume.show(); _resume.grab_focus()

func reopen() -> void:
	_collapsed = false; refresh()

func advance() -> void:
	if not visible or _busy or Time.get_ticks_msec() - _last_press < 160: return
	if _event_id == MirrorDreamService.CALL: return
	_last_press = Time.get_ticks_msec()
	var morning := _event_id == MirrorDreamService.MORNING
	if _page < (1 if morning else 7):
		_page += 1; display_page(); return
	_busy = true
	var result := _session.event_command(_event_id, "rise" if morning else "wake")
	_busy = false
	if not result.ok:
		_error = result.message
		display_page(); return
	refresh()

func _choose_call(choice: String) -> void:
	if not visible or _busy or _event_id != MirrorDreamService.CALL or Time.get_ticks_msec() - _last_press < 160: return
	_last_press = Time.get_ticks_msec(); _cry.stop(); _busy = true
	var result := _session.event_command(MirrorDreamService.CALL, choice)
	_busy = false
	if not result.ok:
		_error = result.message; display_page(); return
	refresh()

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_cancel"):
		collapse(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		if _event_id == MirrorDreamService.CALL: return
		advance(); get_viewport().set_input_as_handled()
