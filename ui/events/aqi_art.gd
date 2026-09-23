class_name AqiArt
extends RefCounted

const ATLAS = preload("res://assets/aqi/sketch-atlas.png")
const CELLS := {"aqi": Vector2i(0, 0), "bent": Vector2i(1, 0), "fixed": Vector2i(2, 0), "coat": Vector2i(0, 1), "paper": Vector2i(1, 1), "plan": Vector2i(2, 1)}

static func texture(id: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	var cell: Vector2i = CELLS.get(id, Vector2i.ZERO)
	var cell_size := Vector2(ATLAS.get_width() / 3.0, ATLAS.get_height() / 2.0)
	result.region = Rect2(Vector2(cell) * cell_size, cell_size)
	result.filter_clip = true
	return result

static func counter_texture(id: String) -> Texture2D:
	if id == "dragon_message": return load("res://assets/ui/mail/envelope.png") as Texture2D
	if id == "aqi": return load("res://assets/aqi/counter-aqi-resting.png") as Texture2D
	if id == "ledger": return load("res://assets/aqi/ledger.svg") as Texture2D
	var path := "res://assets/aqi/counter-" + id + ".png"
	if id in ["aqi", "bent", "fixed"] and ResourceLoader.exists(path): return load(path) as Texture2D
	return texture(id)

static func counter_material(id: String) -> ShaderMaterial:
	if id not in ["aqi", "bent", "fixed"]: return null
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/art/counter_cutout.gdshader")
	material.set_shader_parameter("chroma_key", true)
	return material
