extends Control

const ROOT := "res://assets/opening_art/"
const SCENES := {
	"factory": ROOT + "factory-v2.png", "photo": ROOT + "photo.png",
	"wedding": ROOT + "photo.png", "key": ROOT + "letter.png",
	"letter": ROOT + "letter.png", "memory": ROOT + "memory.png",
	"stamp": ROOT + "stamp.png", "exterior": ROOT + "exterior.png",
	"inspection": ROOT + "inspection.png",
	"customer": "res://assets/art04/counter_room.png",
	"room": "res://assets/bedroom/room-normal.png", "sleep": "res://assets/bedroom/room-normal.png"
}
var _paint: TextureRect
var _customer: TextureRect
var _hairpin: TextureRect
var _cache: Dictionary = {}
var _scene := ""
var _room_material: ShaderMaterial
var _memory_material: ShaderMaterial
var _invitation: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var base := ColorRect.new()
	base.color = Color("191813")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint = _image()
	_memory_material = ShaderMaterial.new()
	_memory_material.shader = preload("res://ui/events/opening_memory.gdshader")
	_invitation = _image()
	var invitation := AtlasTexture.new()
	invitation.atlas = preload("res://assets/opening_art/invitation-source.png")
	invitation.region = Rect2(625, 525, 375, 320)
	_invitation.texture = invitation
	_invitation.stretch_mode = TextureRect.STRETCH_SCALE
	var invitation_material := ShaderMaterial.new()
	invitation_material.shader = preload("res://ui/events/opening_invitation.gdshader")
	_invitation.material = invitation_material
	_invitation.hide()
	_room_material = ShaderMaterial.new()
	_room_material.shader = preload("res://ui/events/opening_room.gdshader")
	_room_material.set_shader_parameter("rest_texture", preload("res://assets/bedroom/room-rest.png"))
	_customer = _image()
	_customer.texture = preload("res://assets/art04/customers/neighbor_v2.png")
	_customer.material = CounterVisualCatalog.portrait_material(_customer.texture)
	_customer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hairpin = _image()
	_hairpin.texture = preload("res://assets/art04/items/hairpin_front.png")
	_hairpin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resized.connect(_layout)
	_layout()

func _image() -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

func present(scene: String, flags: Array, recollection := false) -> void:
	_scene = scene
	var path: String = SCENES.get(scene, SCENES.inspection)
	if not _cache.has(path): _cache[path] = load(path)
	_paint.texture = _cache[path]
	var bedroom := scene in ["room", "sleep"]
	_paint.material = _room_material if bedroom else (_memory_material if recollection else null)
	_invitation.visible = scene == "wedding"
	_room_material.set_shader_parameter("photo_placed", "INTRO_MANQING_PHOTO_PLACED" in flags)
	_paint.modulate = Color(0.83, 0.83, 0.83) if scene == "sleep" else Color.WHITE
	_customer.visible = scene == "customer"
	_hairpin.visible = scene == "customer"
	_layout()

func _layout() -> void:
	if _paint == null: return
	_paint.position = Vector2(0, -size.y * 0.085 if _scene == "factory" else 0.0)
	_paint.size = size
	_invitation.position = size * Vector2(700.0 / 1672.0, 449.0 / 941.0)
	_invitation.size = size * Vector2(280.0 / 1672.0, 239.0 / 941.0)
	_customer.position = size * Vector2(0.35, 0.02)
	_customer.size = size * Vector2(0.30, 0.52)
	_hairpin.position = size * Vector2(0.46, 0.57)
	_hairpin.size = size * Vector2(0.14, 0.09)
