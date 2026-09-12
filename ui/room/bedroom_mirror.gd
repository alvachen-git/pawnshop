class_name BedroomMirror
extends Control

const DEFAULT_REFLECTION := preload("res://assets/bedroom/mirror/reflection-normal.png")
const MODES := [&"normal", &"ripple", &"fog", &"delayed"]
@onready var reflection: TextureRect = $Glass/Reflection
@onready var phenomena: TextureRect = $Glass/Phenomena
@onready var frame: TextureRect = $Frame
@onready var hit_target: Button = $HitTarget
var _surface: ShaderMaterial
var _state: Dictionary = {}
var _target: Dictionary = {}
var _pending: Dictionary = {}
var _remaining := 0.0

func _ready() -> void:
	frame.material = frame.material.duplicate()
	_surface = reflection.material.duplicate() as ShaderMaterial
	reflection.material = _surface
	reset()

## Presentation only. Story code owns triggers, persistence and player consequences.
func set_state(request: Dictionary) -> void:
	var mode := StringName(request.get("mode", &"normal"))
	if mode not in MODES: mode = &"normal"
	var next := {
		"mode": mode,
		"lamp_lit": bool(request.get("lamp_lit", true)),
		"lamp_light": clampf(float(request.get("lamp_light", 1.0)), 0.0, 1.0),
		"strength": clampf(float(request.get("strength", 0.0)), 0.0, 1.0),
		"delay_seconds": clampf(float(request.get("delay_seconds", 0.65)), 0.0, 3.0),
		"reflection_texture": request.get("reflection_texture") as Texture2D,
		"overlay_texture": request.get("overlay_texture") as Texture2D,
		"overlay_opacity": clampf(float(request.get("overlay_opacity", 1.0)), 0.0, 1.0),
		"description": str(request.get("description", "")),
	}
	if next == _target: return
	_target = next
	_pending.clear()
	set_process(false)
	if mode == &"delayed" and next.delay_seconds > 0.0:
		_pending = next.duplicate()
		_remaining = next.delay_seconds
		set_process(true)
	else:
		_commit(next)

func _commit(state: Dictionary) -> void:
	_state = state.duplicate()
	reflection.texture = state.reflection_texture if state.reflection_texture != null else DEFAULT_REFLECTION
	_surface.set_shader_parameter("lamp_lit", state.lamp_lit)
	_surface.set_shader_parameter("lamp_light", state.lamp_light)
	(frame.material as ShaderMaterial).set_shader_parameter("lamp_light", state.lamp_light)
	_surface.set_shader_parameter("ripple", state.strength if state.mode == &"ripple" else 0.0)
	_surface.set_shader_parameter("fog", state.strength if state.mode == &"fog" else 0.0)
	phenomena.texture = state.overlay_texture
	phenomena.modulate.a = state.overlay_opacity
	phenomena.visible = state.overlay_texture != null and state.overlay_opacity > 0.0

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0: return
	_commit(_pending)
	_pending = {}
	set_process(false)

func reset() -> void:
	_pending = {}
	_target = {}
	_remaining = 0.0
	set_state({})

func current_state() -> Dictionary:
	return _state.duplicate()

func observation_text() -> String:
	if not _state.get("description", "").is_empty(): return _state.description
	match _state.get("mode", &"normal"):
		&"ripple": return "镜里的墙缝微微弯曲，过了一会儿才归回原处。"
		&"fog": return "镜面浮起一层薄雾，对面的墙角渐渐看不清了。"
		&"delayed": return "灯影慢了半拍，才在镜里沉下去。"
	return "镜面蒙着薄灰，映着对面墙的一角。" if _state.get("lamp_lit", true) else "镜里的暖色褪了，只剩一角灰暗的墙。"
