extends Button

signal rung(mode: String, target_id: String)
const HOLD_SECONDS := 1.0
var blocked: Callable
var _art: TextureRect
var atmosphere := 0
var _model := {"mode": "", "target_id": "", "enabled": false, "hint": "开铺后才能招呼客人。"}
var _holding := false
var _elapsed := 0.0
var _pressed_mode := ""
var _pressed_target := ""

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(72, 100)
	_art = TextureRect.new()
	_art.name = "HandBellArt"
	_art.texture = preload("res://assets/art04/props/handbell.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if _art != null:
		var tint: Color = [Color.WHITE, Color("b1bab4"), Color("b8cdd0")][atmosphere]
		_art.modulate = tint * (Color("b8b2a5") if disabled else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	# Only functional hover/focus and hold progress are drawn in code.
	# The bell itself is a separate matte gouache painting.
	var body := Vector2(size.x * 0.5, size.y * 0.72)
	var radius := minf(size.x * 0.46, size.y * 0.36)
	if is_hovered() or has_focus():
		draw_arc(body, radius, 0, TAU, 48, Color("c9b991"), 1.5, true)
	if _holding and _pressed_mode == "dismiss":
		draw_arc(body, radius + 3, -PI / 2, -PI / 2 + TAU * minf(1, _elapsed / HOLD_SECONDS), 48, Color("d4b876"), 3, true)
