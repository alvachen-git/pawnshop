class_name PearlArt
extends RefCounted

static func cell(quality: String, angle: int, hole := false) -> Texture2D:
	var path: String = {"fine":"a","lower":"b","imitation":"c-v2"}[quality]
	var source: Texture2D = load("res://assets/pearl_desk/pearl-"+path+".png")
	var atlas := AtlasTexture.new(); atlas.atlas = source
	var w := source.get_width()/3.0; var h := source.get_height()/2.0
	# The atlas has one centered subject per cell; use its original proportions.
	atlas.region = Rect2(w*posmod(angle,3),h if hole else 0,w,h)
	return atlas

static func hole_detail(quality: String) -> Texture2D:
	var atlas := cell(quality,0,true) as AtlasTexture
	var size := atlas.region.size
	atlas.region = Rect2(atlas.region.position+size*Vector2(.26,.26),size*.48)
	return atlas

static func material(light := "front", tint := 2) -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = load("res://ui/art/pearl_surface.gdshader")
	result.set_shader_parameter("light_x",-.6 if light == "left" else .6 if light == "right" else 0.0)
	result.set_shader_parameter("warmth",float(tint-2)*.012)
	return result
