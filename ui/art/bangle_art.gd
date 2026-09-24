class_name BangleArt
extends RefCounted

static func cell(index: int, variant := "base") -> AtlasTexture:
	var source: Texture2D=load("res://assets/bangle_desk/"+variant+".png")
	var result:=AtlasTexture.new(); result.atlas=source
	var width:=float(source.get_width())/3.0; var height:=float(source.get_height())
	result.region=Rect2((index%3)*width+3,3 if index<3 else height*.486+3,width-6,height*(.486 if index<3 else .514)-6)
	return result

static func detail(item: ItemInstance, d: Dictionary, after: bool) -> Texture2D:
	if d.part=="inner": return inner_band(item,d,after)
	var index: int={"stamp":1,"body":2,"joint":3}[d.part]
	var visible:=BangleAppraisal.visible_detail(item,d)
	if d.part=="joint" and visible and item.goods.bangle_value.repair=="altered": index=4
	var variant: String=item.goods.bangle_value.material if visible else "fine"
	if variant=="lower" and not after: variant="lower_clean"
	return cell(index,"base" if variant=="fine" else variant)

static func inner_band(item: ItemInstance, d: Dictionary, after: bool) -> AtlasTexture:
	var source: Texture2D=load("res://assets/bangle_desk/inner-band.png")
	var variant: String=item.goods.bangle_value.material if BangleAppraisal.visible_detail(item,d) else "fine"
	var index:=0 if variant=="fine" else 3 if variant=="plated" else 2 if after else 1
	var size:=Vector2(source.get_width(),source.get_height())/2.0
	var result:=AtlasTexture.new(); result.atlas=source
	result.region=Rect2(Vector2(index%2,index/2)*size+Vector2(3,3),size-Vector2(6,6))
	return result

static func surface(soot: float, heat: float, angle: int) -> ShaderMaterial:
	var m:=ShaderMaterial.new(); m.shader=load("res://ui/art/bangle_surface.gdshader")
	m.set_shader_parameter("soot",soot); m.set_shader_parameter("heat",heat); m.set_shader_parameter("side",float(angle-1)*.11)
	return m

static func exterior(damage := 0) -> AtlasTexture:
	var source:Texture2D=load("res://assets/bangle_desk/exterior-refined.png")
	var result:=AtlasTexture.new();result.atlas=source
	var width:=float(source.get_width())/3.0
	result.region=Rect2(damage*width+2,2,width-4,source.get_height()-4)
	return result

static func cutout() -> ShaderMaterial:
	# Native alpha preserves subtle metal shading without removing dark gold pixels.
	return null

# Runtime sprite meshes keep the generated sheet unchanged and isolate moving brass parts.
static func prop(kind: String) -> Polygon2D:
	var outlines := {
		"stand":[[235,18],[253,18],[271,58],[265,108],[268,150],[273,211],[282,250],[290,296],[314,322],[289,359],[304,405],[344,435],[382,451],[381,485],[338,501],[146,501],[114,480],[118,450],[161,432],[196,408],[205,355],[178,326],[196,297],[213,248],[221,170],[220,110],[222,65]],
		"beam":[[524,253],[541,245],[552,265],[711,235],[752,231],[770,178],[787,228],[821,235],[985,270],[994,250],[1013,249],[1018,270],[1000,315],[988,310],[991,287],[815,279],[792,292],[779,332],[765,342],[750,295],[716,277],[550,288],[550,311],[534,317],[525,291]],
		"pan":[[1148,401],[1170,390],[1408,390],[1448,408],[1431,457],[1380,485],[1300,498],[1215,482],[1170,458]],
		"weight":[[236,681],[260,681],[281,702],[270,747],[316,770],[316,916],[289,931],[199,931],[176,917],[174,770],[215,746],[211,705]],
		"lamp":[[1299,544],[1323,608],[1327,650],[1321,678],[1353,685],[1350,725],[1405,724],[1408,757],[1360,764],[1395,811],[1422,855],[1414,924],[1395,958],[1394,976],[1352,988],[1240,988],[1197,975],[1196,954],[1178,916],[1170,855],[1188,817],[1222,787],[1240,762],[1238,684],[1276,691],[1273,646]]}
	var pivots:={"stand":Vector2(245,500),"beam":Vector2(770,264),"pan":Vector2(1298,400),"weight":Vector2(245,931),"lamp":Vector2(1299,980)}
	var node:=Polygon2D.new();node.texture=load("res://assets/bangle_desk/tools.png")
	var uv:=PackedVector2Array();var points:=PackedVector2Array()
	for pair in outlines[kind]:
		var point:=Vector2(pair[0],pair[1]);uv.append(point);points.append(point-pivots[kind])
	node.polygon=points;node.uv=uv;return node
