class_name FanDeskObject
extends Control

signal selected(side: String, point: Vector2)
signal moved
signal grabbed(side: String)
signal detail_requested(side: String, point: Vector2)

var side := ""
var texture: Texture2D
var marker := Vector2(-1, -1)
var limits := Rect2(0, 110, 1600, 600)
var _pressed := false
var _dragging := false
var _origin := Vector2.ZERO
var _press := Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	if texture != null: draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	if marker.x >= 0:
		var point := marker * size
		draw_arc(point + Vector2(1, 2), 25, 0, TAU, 64, Color("271b12"), 3, true)
		draw_arc(point, 25, 0, TAU, 64, Color("e7ba77"), 2, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_RIGHT] and event.pressed:
			detail_requested.emit(side, (event.position / size).clamp(Vector2.ZERO, Vector2.ONE))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grabbed.emit(side)
				_pressed = true
				_dragging = false
				_press = position + event.position
				_origin = position
			else:
				if _pressed and not _dragging:
					marker = (event.position / size).clamp(Vector2.ZERO, Vector2.ONE)
					selected.emit(side, marker)
				_pressed = false
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _pressed:
		# Event-local coordinates also work with viewport-injected input and at
		# every canvas scale; querying the OS cursor loses those synthetic moves.
		var delta: Vector2 = position + event.position - _press
		if delta.length() > 5: _dragging = true
		if _dragging:
			position = (_origin + delta).clamp(limits.position, (limits.end - size).max(limits.position))
			moved.emit()
		accept_event()

func set_marker(point: Vector2) -> void:
	marker = point
	queue_redraw()
