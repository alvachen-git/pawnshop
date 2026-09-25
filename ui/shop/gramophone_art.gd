class_name GramophoneArt
extends RefCounted

const HINTS := {
	"identity":"核对 VICTOR 字母排列、铭牌螺钉和部件装配。原装样本接合匀整；单有牌子还不能定身份。",
	"soundbox":"看针杆固定、振膜边缘与密封圈。再用铺里的完好唱片试听；唱片的爆豆杂音不能直接算机器坏。",
	"playback":"先摇柄上弦，调至参考转速，再落针听。音高应平稳、乐句清楚；换对照唱片，看杂音是否还在。"}

static func hero() -> Texture2D:
	return load("res://assets/gramophone_desk/counter_painted.png")

static func cell(column: int, row: int) -> Texture2D:
	var source:=load("res://assets/gramophone_desk/details.png") as Texture2D
	var result:=AtlasTexture.new();result.atlas=source
	var unit:=Vector2(source.get_width()/3.0,source.get_height()/2.0)
	result.region=Rect2(Vector2(column,row)*unit+Vector2(8,8),unit-Vector2(16,16));result.filter_clip=true
	return result

static func detail(facts: Dictionary, group: String) -> Texture2D:
	if group=="identity":return cell(["original","rebuilt","imitation"].find(facts.identity),0)
	if group=="soundbox":return cell(["clear","rasping","muffled"].find(facts.sound),1)
	return hero()

static func reference_image(group: String) -> Texture2D:
	return detail({"identity":"original","sound":"clear"},group)

static func counter_material() -> ShaderMaterial:
	# Reuse the tabletop lighting model; contact is at the motor-box feet only.
	var mat:=ShaderMaterial.new();mat.shader=preload("res://ui/art/counter_item.gdshader")
	mat.set_shader_parameter("exposure",.96)
	mat.set_shader_parameter("saturation",.82)
	mat.set_shader_parameter("highlight_reduction",.11)
	mat.set_shader_parameter("contact_mode",2)
	mat.set_shader_parameter("footprint",Vector4(.59,.92,.35,.074))
	return mat
