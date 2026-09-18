extends ColorRect

# Presentation only. A successful outer save emits changed; loading only resets.
var _session: RunSession
var _known := ""
var _fade: Tween
var _sound := AudioStreamPlayer.new()
var play_count := 0

func bind(session: RunSession) -> void:
	_session = session
	name = "MirrorEndingEffect"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 15
	color = Color(0.34, 0.055, 0.04, 0.0)
	# Only the counter half receives the passing shadow; the paper stays legible.
	anchor_right = 0.59
	add_child(_sound)
	_sound.volume_db = -14
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(22050 * 2)
	for i in 22050:
		var time := float(i) / 22050.0
		var wave := (sin(TAU * 63.0 * time) + 0.35 * sin(TAU * 94.0 * time)) * sin(PI * time) * (1.0 - time)
		samples.encode_s16(i * 2, int(wave * 16000))
	stream.data = samples
	_sound.stream = stream
	_session.changed.connect(_refresh)
	_session.restored.connect(_reset)
	_reset()

func _reset() -> void:
	_known = _session._day.state.mirror_resolution.get("ending", "")
	if _fade != null: _fade.kill()
	_sound.stop()
	color.a = 0.0

func _refresh() -> void:
	var ending: String = _session._day.state.mirror_resolution.get("ending", "")
	if ending == _known: return
	_known = ending
	if ending.is_empty() or _session.replaying: return
	# v26 and later already performed the scene before the atomic commit.
	if MirrorReunionService.enabled(_session.definition): return
	play_count += 1
	var angry := ending == "resentment"
	color = Color(0.34, 0.055, 0.04, 0.0) if angry else Color(0.86, 0.82, 0.67, 0.0)
	_fade = create_tween()
	_fade.tween_property(self, "color:a", 0.45 if angry else 0.2, 0.18)
	_fade.tween_property(self, "color:a", 0.0, 1.1)
	_sound.pitch_scale = 0.8 if angry else 1.6
	_sound.play()
