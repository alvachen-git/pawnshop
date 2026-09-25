class_name CameraShutter
extends Control

var elapsed := -1.0
var operation := "smooth"
var speed := "slow"
var wound := false
var sounded := false
var moved := false
var audio_player: AudioStreamPlayer
var played_events: Array[String] = []

const SOUNDS := {
	"fast": preload("res://assets/camera_desk/audio/recorded_fast.wav"),
	"slow": preload("res://assets/camera_desk/audio/recorded_slow.wav"),
	"sticky_fast": preload("res://assets/camera_desk/audio/recorded_sticky_fast.wav"),
	"sticky_slow": preload("res://assets/camera_desk/audio/recorded_sticky_slow.wav"),
	"jam": preload("res://assets/camera_desk/audio/recorded_jam.wav"),
}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	audio_player=AudioStreamPlayer.new();audio_player.max_polyphony=4;add_child(audio_player)

func play_test(condition: String, setting: String, armed: bool) -> void:
	audio_player.stop()
	operation=condition;speed=setting;wound=armed;elapsed=0;sounded=false;moved=false;played_events.clear()
	if armed:
		played_events.append("release")
		var clip: String="jam" if operation=="stuck" else "sticky_"+speed if operation=="sticky" else speed
		audio_player.stream=SOUNDS[clip];audio_player.play()
	queue_redraw()

func opening_time() -> float:
	return .82 if operation=="sticky" else .02

func closing_time() -> float:
	return (.385 if speed=="slow" else .175)+(.8 if operation=="sticky" else 0.0)

func _process(delta: float) -> void:
	if elapsed<0:return
	elapsed+=delta
	if wound and elapsed>=opening_time() and not moved:
		moved=true;played_events.append("jam" if operation=="stuck" else "travel")
	if wound and operation!="stuck" and elapsed>=closing_time() and not sounded:
		sounded=true;played_events.append("catch")
	if elapsed>2.8:elapsed=-1
	queue_redraw()

func _draw() -> void:
	var rect:=Rect2(Vector2.ZERO,size)
	draw_style_box(CounterTheme.painted_paper(),rect)
	var frame:=Rect2(30,30,size.x-60,size.y-60)
	draw_rect(frame,Color("151515"))
	var aperture:=0.0
	if wound and elapsed>=0:
		var start:=opening_time()
		var end:=closing_time()
		if operation=="stuck":aperture=.14 if elapsed>start else 0.0
		elif elapsed>=start and elapsed<end:aperture=1.0
	if aperture>0:draw_rect(Rect2(frame.position+Vector2(frame.size.x*(1.0-aperture)/2,0),Vector2(frame.size.x*aperture,frame.size.y)),Color("d8c594"))
	for i in 16:
		var y:=frame.position.y+i*frame.size.y/16
		draw_line(Vector2(frame.position.x,y),Vector2(frame.end.x,y),Color(0,0,0,.2),1)
