class_name FacilitiesNavigation
extends Node

const HOVER_SECONDS := 0.35
const FADE_SECONDS := 0.18
var screen: CounterScreen
var session: RunSession
var room: FacilitiesRoomView
var entry: Button
var in_room := false
var transitioning := false
var _hover_seconds := 0.0
var _edge_armed := true
var _tween: Tween
var _last_size := Vector2.ZERO
var _pointer := Vector2(-1, -1)
var _transition_guard: Control

func bind(value: CounterScreen, current: RunSession) -> void:
	screen = value
	session = current
	screen.clip_contents = true
	room = FacilitiesRoomView.new()
	room.name = "FacilitiesRoom"
	screen.add_child(room)
	screen.move_child(room, screen._counter_view.get_index() + 1)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.anchor_bottom = 0.9
	room.hide()
	room.bind(session)
	_transition_guard = Control.new()
	_transition_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_guard.z_index = 20
	screen.add_child(_transition_guard)
	FacilitiesRoomView.bounds(_transition_guard, Rect2(0, 0, 1, 0.9))
	_transition_guard.hide()
	room.return_requested.connect(func() -> void: leave())
	room.counter_requested.connect(func() -> void: leave())
	entry = Button.new()
	entry.name = "FacilitiesEntry"
	entry.accessibility_name = "进入铺内"
	screen.add_child(entry)
	screen.move_child(entry, screen.get_node("%Drawer").get_index())
	FacilitiesRoomView.bounds(entry, Rect2(0.004, 0.39, 0.095, 0.06))
	FacilitiesRoomView.navigation_arrow(entry, true)
	entry.pressed.connect(func() -> void: enter())
	session.changed.connect(_sync)
	session.restored.connect(reset)
	get_viewport().mouse_exited.connect(_clear_pointer)
	get_window().focus_exited.connect(_clear_pointer)
	get_window().size_changed.connect(_settle_resize)
	_sync()

func available() -> bool:
	if session == null or not session._day.state.shop_growth_enabled: return false
	if session._day.state.phase not in [&"pre_open", &"open", &"closed_processing"]: return false
	return not ShopGrowthService.blocked(session._day)

func blocked() -> bool:
	if not screen.is_visible_in_tree() or screen.process_mode == Node.PROCESS_MODE_DISABLED: return true
	if screen._bell_blocked(): return true
	if screen._room != null and screen._room.visible: return true
	return screen._counter_view._customer_context.visible or screen._counter_view._item_context.visible

func enter(section := "", animate := true) -> bool:
	if not available() or transitioning: return false
	if not in_room and blocked(): return false
	if in_room:
		if not section.is_empty(): room.select(section)
		return true
	in_room = true
	_hover_seconds = 0.0
	_edge_armed = false
	screen._counter_view.dismiss_contexts()
	screen._close_menu()
	screen.get_node("%Drawer").hide()
	room.show()
	room.refresh()
	entry.hide()
	_fade(true, animate)
	if not section.is_empty(): room.select(section)
	return true

func leave(animate := true) -> void:
	if not in_room and not transitioning: return
	in_room = false
	_hover_seconds = 0.0
	_edge_armed = false
	room.close_sheet()
	screen._counter_view.show()
	_fade(false, animate)

func reset() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	transitioning = false
	in_room = false
	_transition_guard.hide()
	_hover_seconds = 0.0
	_edge_armed = false
	if room != null:
		room.close_sheet()
		room.hide()
		room.position.x = 0
	screen._counter_view.position.x = 0
	screen._counter_view.modulate.a = 1
	_sync()

func _fade(entering: bool, animate: bool) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	transitioning = true
	if not animate:
		_finish(entering)
		return
	_transition_guard.show()
	var focused := screen.get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	room.position.x = 0
	screen._counter_view.position.x = 0
	room.modulate.a = 0.0 if entering else 1.0
	screen._counter_view.modulate.a = 1.0 if entering else 0.0
	_tween.tween_property(room, "modulate:a", 1.0 if entering else 0.0, FADE_SECONDS)
	_tween.tween_property(screen._counter_view, "modulate:a", 0.0 if entering else 1.0, FADE_SECONDS)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button in room.hotspots.values(): button.disabled = true
	room.return_button.disabled = true
	room.return_button.hide()
	_tween.chain().tween_callback(_finish.bind(entering))

func _finish(entering: bool) -> void:
	transitioning = false
	_transition_guard.hide()
	room.position.x = 0
	room.modulate.a = 1
	screen._counter_view.modulate.a = 1
	screen._counter_view.position.x = 0
	room.visible = entering
	room.mouse_filter = Control.MOUSE_FILTER_STOP
	for button in room.hotspots.values(): button.disabled = false
	room.return_button.disabled = false
	room.return_button.show()
	screen._counter_view.visible = not entering and (screen._room == null or not screen._room.visible)
	if entering: room.hotspots.archive.grab_focus()
	elif screen.is_visible_in_tree(): entry.grab_focus()
	_sync()

func _sync() -> void:
	if room == null: return
	if in_room and (not available() or (screen._room != null and screen._room.visible)):
		leave(false)
		return
	entry.visible = available() and not in_room and not transitioning and not blocked()
	if in_room and not transitioning: screen._counter_view.hide()
	if screen._market_notice != null and in_room: screen._market_notice.hide()

func _process(delta: float) -> void:
	if room == null: return
	if screen.size != _last_size:
		_last_size = screen.size
		if transitioning:
			if _tween != null: _tween.kill()
			_finish(in_room)
	_sync()
	if transitioning or not available() or blocked() or (in_room and room.sheet.visible):
		_hover_seconds = 0.0
		return
	var mouse := _pointer
	var edge_width := maxf(24, screen.size.x * 0.02)
	var edge := mouse.x >= screen.size.x - edge_width if in_room else mouse.x <= edge_width
	var inside := mouse.x >= 0 and mouse.x <= screen.size.x and mouse.y >= 75 and mouse.y < screen.size.y * 0.86
	if not edge or not inside:
		_hover_seconds = 0.0
		_edge_armed = true
		return
	if not _edge_armed: return
	_hover_seconds += delta
	if _hover_seconds >= HOVER_SECONDS:
		if in_room: leave()
		else: enter()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and screen != null:
		_pointer = screen.get_global_transform().affine_inverse() * event.position

func _clear_pointer() -> void:
	_pointer = Vector2(-1, -1)
	_hover_seconds = 0.0

func _settle_resize() -> void:
	_clear_pointer()
	if transitioning:
		if _tween != null and _tween.is_valid(): _tween.kill()
		_finish(in_room)

func cancel() -> bool:
	if transitioning: return true
	if not in_room: return false
	if room.sheet.visible: room.close_sheet()
	else: leave()
	return true
