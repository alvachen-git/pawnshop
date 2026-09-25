class_name GramophonePlayer
extends Control

signal playback_changed

var deck: TextureRect
var arm: ToneArm
var player: AudioStreamPlayer
var playing := false
var elapsed := 0.0
var angle := 0.0
var motor := "steady"
var wound := true
var speed := "nominal"
var crank_time := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	deck=TextureRect.new();deck.texture=load("res://assets/gramophone_desk/deck.png");deck.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;deck.stretch_mode=TextureRect.STRETCH_SCALE;add_child(deck);deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform float angle=0.0; void fragment(){vec2 c=vec2(0.432,0.445); vec2 ratio=vec2(1.66667,1.0); vec2 d=(UV-c)*ratio;vec2 uv=UV;if(length(d)<0.391){float a=-angle;uv=c+vec2(cos(a)*d.x-sin(a)*d.y,sin(a)*d.x+cos(a)*d.y)/ratio;}COLOR=texture(TEXTURE,uv);}"
	var material:=ShaderMaterial.new();material.shader=shader;deck.material=material
	arm=ToneArm.new();arm.host=self;add_child(arm);arm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player=AudioStreamPlayer.new();player.volume_db=-7;add_child(player)
	player.finished.connect(func() -> void:
		if playing:player.play()
		else:stop())

static func rate_at(t: float, wound_up: bool, condition: String, setting: String) -> float:
	var nominal: float={"slow":.82,"nominal":1.0,"fast":1.18}[setting]
	if not wound_up:return nominal*maxf(0.0,.65-t*.22)
	if condition=="stopping":return nominal*clampf((5.0-t)/1.3,0.0,1.0)
	if condition=="wavering":return nominal*(1.0+.13*sin(t*5.7)+.055*sin(t*2.2))
	return nominal

func listen(facts: Dictionary, settings: Dictionary) -> void:
	stop();motor=facts.motor;wound=settings.wound;speed=settings.speed
	var worn: bool=settings.record=="customer" and facts.record_worn
	var recording:=load("res://assets/gramophone_desk/audio/"+String(facts.sound)+("_worn" if worn else "")+".wav") as AudioStreamWAV
	player.stream=recording.duplicate()
	(player.stream as AudioStreamWAV).loop_mode=AudioStreamWAV.LOOP_FORWARD
	(player.stream as AudioStreamWAV).loop_end=int(recording.get_length()*recording.mix_rate)
	elapsed=0;playing=true;player.pitch_scale=maxf(.1,rate_at(0,wound,motor,speed));player.play();redraw();playback_changed.emit()

func stop() -> void:
	var was_playing:=playing
	playing=false
	if player!=null:player.stop()
	redraw()
	if was_playing:playback_changed.emit()

func wind_handle() -> void:
	stop();crank_time=1.0

func _process(delta: float) -> void:
	if crank_time>0:crank_time=maxf(0,crank_time-delta);redraw()
	if not playing:return
	elapsed+=delta
	var rate:=rate_at(elapsed,wound,motor,speed)
	angle+=delta*TAU*1.3*rate
	if rate<.04:stop();return
	player.pitch_scale=maxf(.1,rate)
	redraw()

func redraw() -> void:
	if deck!=null:(deck.material as ShaderMaterial).set_shader_parameter("angle",angle)
	if arm!=null:arm.update_pose();arm.queue_redraw()

class ToneArm extends Control:
	var host: GramophonePlayer
	var painted: Sprite2D
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		painted=Sprite2D.new();painted.texture=load("res://assets/gramophone_desk/tonearm.png");painted.centered=false;add_child(painted)
		painted.modulate=Color(.83,.82,.76)
		update_pose()
	func update_pose() -> void:
		if painted==null:return
		var center:=size*Vector2(.432,.445);var radius:=size.y*.39
		var pivot:=size*Vector2(.895,.165)
		var arm_vector:=center+Vector2(radius*.75,radius*.35)-pivot
		var tip:=pivot+(arm_vector if host.playing else arm_vector.rotated(-.45))
		var tex_size:=painted.texture.get_size()
		var base_vector:=tex_size*Vector2(-.72,-.09)
		painted.offset=-tex_size*Vector2(.89,.50)
		painted.position=pivot;painted.rotation=(tip-pivot).angle()-base_vector.angle()
		painted.scale=Vector2.ONE*(tip-pivot).length()/base_vector.length()
	func _draw() -> void:
		var center:=size*Vector2(.432,.445);var radius:=size.y*.39
		# A paper marker makes speed changes visible without revealing a verdict.
		var marker:=center+Vector2(cos(host.angle),sin(host.angle))*radius*.80
		draw_line(marker-Vector2(2,2),marker+Vector2(2,2),Color("d8cbaa"),4,true)
		if host.crank_time>0:
			var pos:=size*Vector2(.91,.84);var end:=pos+Vector2(cos(host.crank_time*TAU*3),sin(host.crank_time*TAU*3))*18
			draw_line(pos,end,Color("b4a187"),4,true);draw_circle(end,5,Color("725b3e"))
