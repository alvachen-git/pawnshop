class_name BangleBalance
extends Control
var grams:=0
var weight:=30
var placed:=false
var weights:Dictionary={}
var tilt:=0.0
var beam:Polygon2D
var pans:Array[Polygon2D]=[]
var ring:TextureRect
var counters:Node2D
var previous_weights:Dictionary={}

func _ready() -> void:
	var stand:=BangleArt.prop("stand");stand.position=Vector2(206,260);stand.scale=Vector2.ONE*.50;add_child(stand)
	beam=BangleArt.prop("beam");beam.position=Vector2(206,84);beam.scale=Vector2.ONE*.67;add_child(beam)
	for i in 2:
		var pan:=BangleArt.prop("pan");pan.scale=Vector2.ONE*.30;add_child(pan);pans.append(pan)
	ring=TextureRect.new();ring.texture=BangleArt.exterior();ring.material=BangleArt.cutout();ring.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ring.size=Vector2(80,65);ring.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ring)
	ring.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	counters=Node2D.new();add_child(counters)

func _process(delta:float) -> void:
	var target:=clampf(float(grams-(weight if placed else 0))*.014,-.12,.12)
	tilt=lerpf(tilt,target,minf(1.0,delta*8.0));beam.rotation=tilt
	var center:=Vector2(206,84)
	var left:=center+Vector2(-155,14).rotated(tilt);var right:=center+Vector2(155,14).rotated(tilt)
	pans[0].position=left+Vector2(0,112);pans[1].position=right+Vector2(0,112)
	ring.position=pans[0].position-Vector2(40,52);ring.visible=placed
	counters.position=pans[1].position
	if previous_weights!=weights:
		previous_weights=weights.duplicate()
		for child in counters.get_children():counters.remove_child(child);child.queue_free()
		var index:=0
		for denomination in weights:
			for count in mini(int(weights[denomination]),8):
				if index>=8:break
				var sprite:=BangleArt.prop("weight");sprite.scale=Vector2.ONE*(.09 if int(denomination)<10 else .12)
				sprite.position=Vector2(-30+(index%5)*13,-(index/5)*12);counters.add_child(sprite);index+=1
	queue_redraw()

func _draw() -> void:
	var center:=Vector2(206,84)
	for i in 2:
		var top:=center+Vector2(-155 if i==0 else 155,14).rotated(tilt)
		for side in [-1,1]:
			draw_line(top,top+Vector2(side*43,112),Color("705126"),2.5,true)
			draw_line(top+Vector2(1,0),top+Vector2(side*43+1,112),Color("d1ae65"),1,true)
