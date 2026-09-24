class_name PorcelainArt
extends RefCounted

const ERAS := ["yuan","ming","qing","republic"]
const CRAFTS := ["rough","standard","fine"]
static var _regions: Dictionary = {}
const HINTS := {
	"yuan":{"body":"这组样本：腹部重心偏低，颈腹转折舒缓。再看绘纹与足底。","painting":"看云龙或大花的展开、边饰分层与笔线收放；深蓝并不能单独断代。","foot":"看较宽的露胎圈与浅足，合看修足、施釉边界；别只看旧色。"},
	"ming":{"body":"这组明初样本：长颈垂腹，口沿外撇；从颈到腹的曲线连贯。再核绘纹与底足。","painting":"看颈部、肩部、近足处的分层边饰，腹部缠枝或竹石如何展开；笔线与留白一并看。","foot":"看凹入底心、足圈修整与露胎边界，再与绘纹相互核对。"},
	"qing":{"body":"看颈肩衔接、圆腹与足圈的比例。只凭颈长短难以断代，须合看绘纹与底足。","painting":"看竹叶、洞石或卷枝的笔法及疏密；这些题材前朝也有，不能只凭题材断代。","foot":"看圈足收边、底心与款框的位置关系。旧式款不保证旧年代。"},
	"republic":{"body":"普通例颈部素净，腹部留白较多；也有仿旧式的作品。先看颈肩与足部，再核绘纹。","painting":"折枝花鸟或山水较疏朗；仿古例沿用旧式边饰。题材不能独自断代，仍须核对底足。","foot":"看较宽平的足边、底心与一圈圈修足痕；旧款须与整器合看。"}}

static func cell(era: String, craft: String, sample: int, hidden: bool, group: String, angle := 0) -> AtlasTexture:
	var row: int = 5 if group == "foot" else 4 if group == "painting" else posmod(angle,4)
	var complete := craft_specimen(era,craft,sample,hidden,row)
	if complete != null: return complete
	var slot: int = [7,8,9][CRAFTS.find(craft)] if group == "foot" else [4,5,6][CRAFTS.find(craft)] if group == "painting" else posmod(angle,4)
	var refined := specimen(era,sample,hidden,slot)
	if refined != null: return refined
	return legacy_cell(era,craft,sample,hidden,group,angle)

static func craft_specimen(era: String, craft: String, sample: int, hidden: bool, row: int) -> AtlasTexture:
	var path := "res://assets/porcelain_desk/craft/%s_%s_%s" % [era,"a" if sample==0 else "b","hidden" if hidden else "ordinary"]
	if not FileAccess.file_exists(path+".regions.json"): return null
	if not _regions.has(path):
		_regions[path]=JSON.parse_string(FileAccess.get_file_as_string(path+".regions.json"))
	var rect: Array = _regions[path].rects[row*3+CRAFTS.find(craft)]
	var result := AtlasTexture.new(); result.atlas=load(path+".png")
	result.region=Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])); result.filter_clip=true
	return result

static func specimen(era: String, sample: int, hidden: bool, slot: int) -> AtlasTexture:
	var path := "res://assets/porcelain_desk/refined/%s_%s_%s" % [era,"a" if sample==0 else "b","hidden" if hidden else "ordinary"]
	if not FileAccess.file_exists(path+".regions.json"): return null
	if not _regions.has(path):
		_regions[path]=JSON.parse_string(FileAccess.get_file_as_string(path+".regions.json"))
	var rect: Array=_regions[path].rects[slot]
	var result := AtlasTexture.new(); result.atlas=load(path+".png")
	result.region=Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])); result.filter_clip=true
	return result

static func counter(facts: Dictionary) -> AtlasTexture:
	var complete := craft_specimen(facts.era,facts.craft,int(facts.sample),facts.hidden,6)
	if complete != null: return complete
	var result := specimen(facts.era,int(facts.sample),facts.hidden,10)
	return result if result != null else from_facts(facts,"body",0)

static func legacy_cell(era: String, craft: String, sample: int, hidden: bool, group: String, angle: int) -> AtlasTexture:
	var index := ERAS.find(era)*2+clampi(sample,0,1)+1
	var source := load("res://assets/porcelain_desk/s%02d.png" % index) as Texture2D
	var col := 5 if group == "foot" else 4 if group == "painting" else posmod(angle,4)
	var row := CRAFTS.find(craft)+(3 if hidden else 0)
	var size := source.get_size()/6.0
	var texture := AtlasTexture.new(); texture.atlas=source
	var inset := Vector2(6,16) if group == "body" else Vector2(6,6)
	texture.region=Rect2(Vector2(col,row)*size+Vector2(3,3),size-inset); texture.filter_clip=true
	# This sheet has tighter row spacing; keep the full mouth and exclude its neighbour.
	if index == 5:
		var tops := [6,208,411,619,824,1026]
		var heights := [192,194,195,196,192,200]
		texture.region=Rect2(col*size.x+3,tops[row],size.x-6,heights[row])
	return texture

static func from_facts(facts: Dictionary, group: String, angle: int) -> AtlasTexture:
	return cell(facts.era,facts.craft,int(facts.sample),facts.hidden,group,angle)

static func surface(light: String, damage := "intact", whole := false, texture: AtlasTexture = null, on_counter := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float side = 0.0;
uniform float damage = 0.0;
uniform bool whole = false;
uniform bool on_counter = false;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_size = vec2(0.1666667);
void fragment(){
 vec4 tex = texture(TEXTURE,UV);
 vec2 local = (UV-region_origin)/region_size;
 float illumination = 1.0 + side*(local.x-0.5)*0.24;
 tex.rgb *= illumination;
 if (on_counter) {
  tex.rgb *= vec3(0.96,0.94,0.90);
  // Strengthen the artist-painted shadow only, without inventing a new silhouette.
  if (local.y>0.6 && max(tex.r,max(tex.g,tex.b))<0.24) tex.a=min(1.0,tex.a*1.7);
 }
 // A fixed exterior notch is separate from painted craft and has no repair seam.
 if (whole && damage>0.0) {
  vec2 centre=vec2(0.59,0.055);
  vec2 radius=vec2(damage>1.5?0.085:0.031,damage>1.5?0.045:0.018);
  float notch=length((local-centre)/radius);
  if(notch<1.0) tex.a=0.0;
  else if(notch<1.20 && tex.a>0.1) tex.rgb=vec3(0.76,0.73,0.64);
 }
 COLOR=tex;
}"""
	var material := ShaderMaterial.new(); material.shader=shader
	material.set_shader_parameter("side",-1.0 if light=="left" else 1.0 if light=="right" else 0.0)
	material.set_shader_parameter("damage",float(["intact","minor","major"].find(damage))); material.set_shader_parameter("whole",whole)
	material.set_shader_parameter("on_counter",on_counter)
	if texture != null:
		material.set_shader_parameter("region_origin",texture.region.position/texture.atlas.get_size())
		material.set_shader_parameter("region_size",texture.region.size/texture.atlas.get_size())
	return material
