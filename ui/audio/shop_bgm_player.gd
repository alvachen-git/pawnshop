class_name ShopBgmPlayer
extends AudioStreamPlayer

const STOP_MINUTE := 22 * 60
const FADE_OUT_SECONDS := 5.0
const SILENT_VOLUME_DB := -80.0
const CLOCK_VOLUME_DB := -12.0

var _session: RunSession
var _shop_screen: Control
var _normal_volume_db: float
var _should_play := false
var _volume_tween: Tween
var _clock_player: AudioStreamPlayer
var _clock_should_play := false
var _clock_tween: Tween


func _ready() -> void:
	_normal_volume_db = volume_db
	stream = preload("res://assets/audio/pawnshop_night.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	var clock_stream := preload("res://assets/audio/shop_clock_loop.wav").duplicate() as AudioStreamWAV
	clock_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	clock_stream.loop_begin = 0
	clock_stream.loop_end = roundi(clock_stream.get_length() * clock_stream.mix_rate)
	_clock_player = AudioStreamPlayer.new()
	_clock_player.name = "LateNightClock"
	_clock_player.stream = clock_stream
	_clock_player.bus = bus
	_clock_player.volume_db = SILENT_VOLUME_DB
	add_child(_clock_player)


func bind_session(session: RunSession, shop_screen: Control) -> void:
	_session = session
	_shop_screen = shop_screen
	_session.changed.connect(_refresh)
	_session.restored.connect(_refresh)
	_shop_screen.visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var should_play := false
	var clock_should_play := false
	if _session != null and is_instance_valid(_shop_screen):
		var state := _session.read_state()
		var clock_minute := _session.definition.opening_minute + int(state.game_minutes)
		var shop_open: bool = _shop_screen.is_visible_in_tree() and state.phase == "open"
		should_play = shop_open and clock_minute < STOP_MINUTE
		clock_should_play = shop_open and clock_minute >= STOP_MINUTE
	_refresh_clock(clock_should_play)
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
		elif volume_db < _normal_volume_db:
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


func _refresh_clock(should_play: bool) -> void:
	if should_play == _clock_should_play:
		return
	_clock_should_play = should_play
	if _clock_tween != null:
		_clock_tween.kill()
		_clock_tween = null
	if should_play:
		if not _clock_player.playing:
			_clock_player.volume_db = SILENT_VOLUME_DB
			_clock_player.play()
		_clock_tween = create_tween()
		_clock_tween.tween_property(_clock_player, "volume_db", CLOCK_VOLUME_DB, FADE_OUT_SECONDS)
	elif _clock_player.playing:
		_clock_tween = create_tween()
		_clock_tween.tween_property(_clock_player, "volume_db", SILENT_VOLUME_DB, FADE_OUT_SECONDS)
		_clock_tween.tween_callback(_finish_clock_fade)


func _finish_clock_fade() -> void:
	_clock_tween = null
	if not _clock_should_play:
		_clock_player.stop()
