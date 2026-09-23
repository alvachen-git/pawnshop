class_name WatchArt
extends RefCounted

static func cell(index: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = load("res://assets/watch_desk/watch-atlas.png")
	result.region = Rect2((index%3)*512,(index/3)*512,512,512)
	return result

static func movement(item: ItemInstance) -> Texture2D:
	match WatchMovementPatterns.kind(item):
		"lettering": return load("res://assets/watch_desk/movement-01.png")
		"gears": return load("res://assets/watch_desk/movement-02.png")
	return cell({"sound":1,"mended":2,"flawed":5}[item.selected_variant_id])

static func material(engraving := false) -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = load("res://ui/art/watch_cutout.gdshader")
	result.set_shader_parameter("engraving",engraving)
	return result

static func reference_cell(index: int) -> AtlasTexture:
	var result := AtlasTexture.new(); result.atlas = load("res://assets/watch_desk/reference-atlas.png")
	var side := result.atlas.get_width()/2.0
	result.region = Rect2(side*index,0,side,result.atlas.get_height()); return result

static func reference_material() -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = load("res://ui/art/watch_reference.gdshader"); return result

static func plaque(primary: bool) -> AtlasTexture:
	var result := AtlasTexture.new(); result.atlas = load("res://assets/watch_desk/buttons.png")
	var half := result.atlas.get_width()/2.0
	result.region = Rect2(half if primary else 0,0,half,result.atlas.get_height()); return result
