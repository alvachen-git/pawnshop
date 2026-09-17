class_name MirrorReunionStage
extends Control

# All art is loaded during screen construction, never inside a page transition.
const PORTRAITS := {
	"wife_waiting": preload("res://assets/mirror_reunion/portraits/wife_waiting.png"),
	"wife_questioning": preload("res://assets/mirror_reunion/portraits/wife_questioning.png"),
	"wife_sorrow": preload("res://assets/mirror_reunion/portraits/wife_sorrow.png"),
	"wife_relief": preload("res://assets/mirror_reunion/portraits/wife_relief.png"),
	"wife_disappointed": preload("res://assets/mirror_reunion/portraits/wife_disappointed.png"),
	"wife_reaching": preload("res://assets/mirror_reunion/portraits/wife_reaching.png"),
	"husband_surprise": preload("res://assets/mirror_reunion/portraits/husband_surprise.png"),
	"husband_evasive": preload("res://assets/mirror_reunion/portraits/husband_evasive.png"),
	"husband_remorse": preload("res://assets/mirror_reunion/portraits/husband_remorse.png"),
	"husband_angry": preload("res://assets/mirror_reunion/portraits/husband_angry.png"),
	"husband_terrified": preload("res://assets/mirror_reunion/portraits/husband_terrified.png"),
}
const ILLUSTRATIONS := {
	"acknowledged": preload("res://assets/mirror_reunion/endings/acknowledged.png"),
	"released": preload("res://assets/mirror_reunion/endings/released.png"),
	"resentment": preload("res://assets/mirror_reunion/endings/resentment.png"),
	"disappointed": preload("res://assets/mirror_reunion/endings/disappointed.png"),
}
var wife: TextureRect
var husband: TextureRect
var _previous_wife: TextureRect
var _previous_husband: TextureRect
var _cg: TextureRect
var _previous_cg: TextureRect
var _wash: ColorRect
var _mirror: TextureRect
var _sound := AudioStreamPlayer.new()
var _sounds: Dictionary = {}
var _normal: Texture2D
var _played: Dictionary = {}
var cue: Dictionary = {}
var _duration := 0.0
var _elapsed := 0.0
var _wife_changed := false
var _husband_changed := false
var _cg_changed := false
var sound_count := 0
var max_apply_usec := 0
var max_animation_frame_ms := 0.0
var opening_frame_max_ms := 0.0
var illustration_frame_max_ms := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_wash)
	_mirror = sprite(0.10, 0.40)
	_mirror.texture = CounterVisualCatalog.front("asset.weeping_mirror")
	_mirror.modulate = Color(0.65, 0.60, 0.47, 0.5)
	_previous_wife = sprite(0.075, 0.445)
	_previous_husband = sprite(0.555, 0.925)
	wife = sprite(0.075, 0.445)
	husband = sprite(0.555, 0.925)
	wife.texture = PORTRAITS.wife_waiting
	# Same identity entry point as the ordinary counter and investigation visit.
	_normal = CounterVisualCatalog.portrait("asset.customer_hawker", "mirror_husband", InvestigationService.PERSON)
	husband.texture = _normal
	_previous_cg = illustration()
	_cg = illustration()
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://ui/art/counter_cutout.gdshader")
	cutout.set_shader_parameter("chroma_key", true)
	cutout.set_shader_parameter("clean_chroma_edges", true)
	for actor in [wife, husband, _previous_wife, _previous_husband]: actor.material = cutout
	add_child(_sound)
	_sound.volume_db = -24
	for kind in ["cloth", "mirror", "attack"]: _sounds[kind] = make_sound(kind)
	reset()

func sprite(left: float, right: float) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(result)
	result.anchor_left = left; result.anchor_right = right
	result.anchor_top = 0.01; result.anchor_bottom = 1.0
	return result

func illustration() -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func reset() -> void:
	stop()
	cue = {}; _played.clear(); sound_count = 0
	for actor in [wife, husband, _previous_wife, _previous_husband, _cg, _previous_cg]: actor.modulate.a = 0.0
	_wash.color = Color.TRANSPARENT

func animating() -> bool:
	return _elapsed < _duration

func stop() -> void:
	_sound.stop()
	finish()

func finish() -> void:
	_elapsed = _duration
	if not cue.is_empty(): paint()

func present(next_cue: Dictionary, animate := true) -> void:
	if cue.get("id", "") == next_cue.id:
		if not animate: stop()
		return
	var started := Time.get_ticks_usec()
	finish()
	_previous_wife.texture = wife.texture
	_previous_husband.texture = husband.texture
	_previous_cg.texture = _cg.texture
	cue = next_cue.duplicate()
	wife.texture = PORTRAITS["wife_" + cue.wife]
	husband.texture = PORTRAITS["husband_" + cue.husband] if cue.husband != "normal" else _normal
	_cg.texture = ILLUSTRATIONS.get(cue.cg)
	_wife_changed = wife.texture != _previous_wife.texture
	_husband_changed = husband.texture != _previous_husband.texture
	_cg_changed = _cg.texture != _previous_cg.texture
	_duration = 0.2
	if _cg_changed: _duration = 0.6
	if cue.motion in ["appear", "grasp", "release", "attack", "empty"]: _duration = 0.9
	if cue.motion in ["depart", "depart_slump"]: _duration = 1.5
	_elapsed = 0.0 if animate else _duration
	_sound.stop()
	if animate and not cue.sound.is_empty() and not _played.has(cue.id):
		_played[cue.id] = true
		_sound.stream = _sounds[cue.sound]
		_sound.play(); sound_count += 1
	paint()
	max_apply_usec = maxi(max_apply_usec, Time.get_ticks_usec() - started)

func _process(delta: float) -> void:
	if not visible or not animating(): return
	max_animation_frame_ms = maxf(max_animation_frame_ms, delta * 1000.0)
	if cue.id == "reveal/0": opening_frame_max_ms = maxf(opening_frame_max_ms, delta * 1000.0)
	if not cue.cg.is_empty(): illustration_frame_max_ms = maxf(illustration_frame_max_ms, delta * 1000.0)
	_elapsed = minf(_duration, _elapsed + delta)
	paint()

func paint() -> void:
	var p := smoothstep(0.0, _duration, _elapsed)
	var expression := smoothstep(0.0, 0.2, _elapsed)
	var cg_blend := smoothstep(0.0, 0.6, _elapsed) if _cg_changed else 1.0
	var departing: bool = cue.motion in ["depart", "depart_slump"]
	var empty: bool = cue.motion == "empty"
	var wife_alpha := (1.0 - p) if departing else (p if cue.motion == "appear" else 1.0)
	var husband_alpha := 0.0 if empty else 1.0
	var dim := Color(0.74, 0.77, 0.74)
	wife.modulate = Color.WHITE if cue.speaker in ["女子", ""] else dim
	husband.modulate = Color.WHITE if cue.speaker in ["丈夫", ""] else dim
	wife.modulate.a = wife_alpha * (expression if _wife_changed else 1.0)
	husband.modulate.a = husband_alpha * (expression if _husband_changed else 1.0)
	_previous_wife.modulate = Color(wife.modulate, wife_alpha * (1.0 - expression) if _wife_changed else 0.0)
	_previous_husband.modulate = Color(husband.modulate, husband_alpha * (1.0 - expression) if _husband_changed else 0.0)
	_previous_cg.modulate.a = 1.0 - cg_blend if _previous_cg.texture != null and _cg_changed else 0.0
	_cg.modulate.a = cg_blend if _cg.texture != null else 0.0
	# Stable sprite rectangles; motions translate without stretching or rescaling.
	var shift := -18.0 * p if departing else (12.0 * p if cue.motion == "grasp" else 0.0)
	wife.offset_left = shift; wife.offset_right = shift
	_previous_wife.offset_left = shift; _previous_wife.offset_right = shift
	var slump := 55.0 * p if cue.motion == "depart_slump" else 0.0
	husband.offset_top = slump; husband.offset_bottom = slump
	_previous_husband.offset_top = slump; _previous_husband.offset_bottom = slump
	wife.visible = wife_alpha > 0.0
	husband.visible = not empty
	_mirror.visible = not departing or p < 1.0
	var warm: bool = cue.id.begins_with("acknowledged/") or cue.id.begins_with("released/")
	_wash.color = Color(0.65, 0.48, 0.25, 0.07 * p) if warm else Color(0.15, 0.22, 0.28, 0.07)

static func make_sound(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var seconds := 0.32 if kind == "attack" else (0.45 if kind == "cloth" else 0.8)
	var samples := PackedByteArray()
	var count := int(seconds * stream.mix_rate)
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9187
	var noise := 0.0
	for i in count:
		var t := float(i) / stream.mix_rate
		var envelope := sin(PI * float(i) / count)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.08)
		var wave := noise * 0.6 if kind == "cloth" else (sin(TAU * 92.0 * t) * 0.24 + sin(TAU * 139.0 * t) * 0.08)
		if kind == "attack": wave = wave * 0.7 + noise * 0.8
		samples.encode_s16(i * 2, int(wave * envelope * 12000))
	stream.data = samples
	return stream
