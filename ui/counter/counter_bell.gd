extends Button

signal rung(mode: String, target_id: String)
const HOLD_SECONDS := 1.0
var blocked: Callable
var _model := {"mode": "", "target_id": "", "enabled": false, "hint": "开铺后才能招呼客人。"}
var _holding := false
var _elapsed := 0.0
var _pressed_mode := ""
var _pressed_target := ""

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(64, 70)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button_down.connect(_begin)
	button_up.connect(_release)
	mouse_exited.connect(cancel)
	focus_exited.connect(cancel)
	get_window().focus_exited.connect(cancel)
	visibility_changed.connect(cancel)

func render(model: Dictionary) -> void:
	if model.mode != _model.mode or model.target_id != _model.target_id or not model.enabled: cancel()
	_model = model.duplicate()
	_update_enabled()
	queue_redraw()

func _update_enabled() -> void:
	var covered: bool = blocked.is_valid() and blocked.call()
	disabled = not _model.enabled or covered
	tooltip_text = "先收好眼前的页面，再摇铃。" if covered and _model.enabled else _model.hint
	if disabled: cancel()

func _begin() -> void:
	_update_enabled()
	if disabled: return
	_holding = true
	_elapsed = 0
	_pressed_mode = _model.mode
	_pressed_target = _model.target_id

func _release() -> void:
	if not _holding: return
	var tap := _pressed_mode == "wait"
	var target := _pressed_target
	cancel()
	_update_enabled()
	if tap and not disabled and _model.mode == "wait": rung.emit("wait", target)

func cancel() -> void:
	_holding = false
	_elapsed = 0
	queue_redraw()

func _process(delta: float) -> void:
	_update_enabled()
	if _holding:
		_elapsed += delta
		if _pressed_mode == "dismiss" and _elapsed >= HOLD_SECONDS:
			var target := _pressed_target
			cancel()
			rung.emit("dismiss", target)
	queue_redraw()

func _draw() -> void:
	var scale_value := minf(size.x / 80.0, size.y / 88.0)
	draw_set_transform((size - Vector2(80, 88) * scale_value) / 2, 0, Vector2.ONE * scale_value)
	var brass := Color("b09760") if not disabled else Color("74674b")
	var edge := Color("dec590") if not disabled else Color("968360")
	draw_ellipse_shadow()
	# Hand bell: wooden grip, worn brass shoulder and flared lip.
	draw_line(Vector2(40, 13), Vector2(40, 34), Color("37281e"), 11, true)
	draw_line(Vector2(37, 14), Vector2(37, 30), Color("997549"), 2, true)
	draw_circle(Vector2(40, 11), 6, brass)
	draw_colored_polygon(PackedVector2Array([Vector2(33, 32), Vector2(47, 32), Vector2(55, 40), Vector2(58, 55), Vector2(67, 64), Vector2(13, 64), Vector2(22, 55), Vector2(25, 40)]), brass)
	draw_polyline(PackedVector2Array([Vector2(33, 34), Vector2(28, 42), Vector2(25, 55), Vector2(20, 60)]), edge, 2, true)
	draw_line(Vector2(14, 65), Vector2(66, 65), Color("51422c"), 4, true)
	draw_circle(Vector2(40, 69), 4, edge)
	if is_hovered() or has_focus(): draw_arc(Vector2(40, 44), 36, 0, TAU, 48, Color("c9ab72"), 1.5, true)
	if _holding and _pressed_mode == "dismiss": draw_arc(Vector2(40, 44), 37, -PI / 2, -PI / 2 + TAU * minf(1, _elapsed / HOLD_SECONDS), 48, Color("e7bd6d"), 3, true)

func draw_ellipse_shadow() -> void:
	draw_set_transform_matrix(get_draw_transform_for_shadow())
	draw_circle(Vector2.ZERO, 1, Color(0.07, 0.055, 0.04, 0.35))
	var unit := minf(size.x / 80.0, size.y / 88.0)
	draw_set_transform((size - Vector2(80, 88) * unit) / 2, 0, Vector2.ONE * unit)

func get_draw_transform_for_shadow() -> Transform2D:
	var unit := minf(size.x / 80.0, size.y / 88.0)
	return Transform2D(Vector2(32 * unit, 0), Vector2(0, 7 * unit), (size - Vector2(80, 88) * unit) / 2 + Vector2(40, 74) * unit)
