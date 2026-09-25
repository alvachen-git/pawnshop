class_name CameraArt
extends RefCounted

const HINTS := {
	"identity":"先核字母次序，再看镜座和固定螺钉是否协调。单有店号刻字，不能认定原装。",
	"lens":"清透样本应能透见内部。左右移灯，留意遮住内部的雾层、随光显出的细划痕；亮斑本身只是反光。",
	"aperture":"改变开度，叶片应随之收放，边缘规整。留意油迹、迟滞或卡住；调节刻度不等于叶片已经到位。",
	"shutter":"先过片上弦，再按快门。较慢挡的帘幕停留更久。比较有无迟滞、卡住；这里观察开合，不保证曝光时间精确。"}

static func hero() -> Texture2D:
	return load("res://assets/camera_desk/camera.png")

static func counter() -> Texture2D:
	return load("res://assets/camera_desk/camera_counter_painted.png")

static func cell(column: int, row: int, iris := false) -> Texture2D:
	var source := load("res://assets/camera_desk/iris.png" if iris else "res://assets/camera_desk/inspection.png") as Texture2D
	var result := AtlasTexture.new();result.atlas=source
	# Atlas gutters are measured from the generated source; cells are not assumed square.
	var xs: Array=[0,421,842,1254]
	var ys: Array=[0,398,787,1254] if iris else [0,399,806,1254]
	var ends: Array=[390,781,1254] if iris else [392,798,1254]
	result.region=Rect2(xs[column]+7,ys[row]+7,xs[column+1]-xs[column]-23,ends[row]-ys[row]-14);result.filter_clip=true
	return result

static func detail(facts: Dictionary, group: String, opening := "middle") -> Texture2D:
	if group=="identity":
		var engraving: String=facts.get("engraving","legacy")
		if facts.identity=="imitation" and engraving in ["letter_swap","extra_letter","city_swap"]:
			return load("res://assets/camera_desk/imitation_"+engraving+".png") as Texture2D
		return cell(["original","rebuilt","imitation"].find(facts.identity),0)
	if group=="lens":return cell(["clear","haze","scratched"].find(facts.lens),1)
	var operation: String=facts.mechanism if facts.fault_at in ["aperture","both"] else "smooth"
	if group=="aperture":return cell(["open","middle","narrow"].find(opening),["smooth","sticky","stuck"].find(operation),true)
	return hero()

static func reference_image(group: String, opening := "middle") -> Texture2D:
	return detail({"identity":"original","lens":"clear","mechanism":"smooth","fault_at":"both"},group,opening)

static func light_material(light: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code="shader_type canvas_item; uniform float side = 0.0; void fragment(){vec4 t=texture(TEXTURE,UV);float shade=1.0+side*(UV.x-0.5)*0.35;COLOR=vec4(t.rgb*shade,t.a);}"
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("side",-1.0 if light=="left" else 1.0 if light=="right" else 0.0)
	return material
