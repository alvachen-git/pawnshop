class_name ShopBgmPlayer
extends AudioStreamPlayer

const STOP_MINUTE := 22 * 60
const FADE_OUT_SECONDS := 5.0
const SILENT_VOLUME_DB := -80.0
# The file starts with 5 seconds of silence and a 1-second radio fade-in.
const RADIO_LOOP_START_SECONDS := 6.0

@export var music_enabled := false

var _session: RunSession
var _shop_screen: Control
var _normal_volume_db: float
var _should_play := false
var _volume_tween: Tween


func _ready() -> void:
	_normal_volume_db = volume_db
	var radio_stream := preload("res://assets/audio/radio/programme.wav").duplicate() as AudioStreamWAV
	radio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	radio_stream.loop_begin = roundi(RADIO_LOOP_START_SECONDS * radio_stream.mix_rate)
	radio_stream.loop_end = roundi(radio_stream.get_length() * radio_stream.mix_rate)
	stream = radio_stream


func bind_session(session: RunSession, shop_screen: Control) -> void:
	_session = session
	_shop_screen = shop_screen
	_session.changed.connect(_refresh)
	_session.restored.connect(_refresh)
	_shop_screen.visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not music_enabled:
		if _volume_tween != null: _volume_tween.kill(); _volume_tween = null
		_should_play = false
		stop()
		return
	var should_play := false
	var state: Dictionary = {}
	var clock_minute := 0
	if _session != null and is_instance_valid(_shop_screen):
		state = _session.read_state()
		clock_minute = _session.definition.opening_minute + int(state.game_minutes)
		var shop_open: bool = _shop_screen.is_visible_in_tree() and state.phase == "open"
		should_play = shop_open and clock_minute < STOP_MINUTE
	_refresh_music(should_play)


func _refresh_music(should_play: bool) -> void:
	if should_play == _should_play:
		return
	_should_play = should_play
	if _volume_tween != null:
		_volume_tween.kill()
		_volume_tween = null
	if should_play:
		if not playing:
			volume_db = _normal_volume_db
			play()
		elif not is_equal_approx(volume_db, _normal_volume_db):
			_volume_tween = create_tween()
			_volume_tween.tween_property(self, "volume_db", _normal_volume_db, 0.4)
	elif playing:
		_volume_tween = create_tween()
		_volume_tween.tween_property(self, "volume_db", SILENT_VOLUME_DB, FADE_OUT_SECONDS)
		_volume_tween.tween_callback(_finish_fade)


func _finish_fade() -> void:
	_volume_tween = null
	if not _should_play:
		stop()
		volume_db = _normal_volume_db
