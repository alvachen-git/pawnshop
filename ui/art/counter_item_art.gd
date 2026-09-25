class_name CounterItemArt
extends RefCounted

# Presentation only: stable item IDs and already-filtered evidence drive all art.
const FAMILIES := {
	"placeholder.inkstone": "inkstone", "placeholder.clay_teapot": "clay_teapot",
	"placeholder.silk_panel": "silk_panel", "placeholder.fountain_pen": "fountain_pen",
	"placeholder.pocket_watch": "pocket_watch", "asset.item_brass_holder": "holder",
	"asset.weeping_mirror": "mirror",
}
# Existing bowl/hairpin inspection pages keep their original knowledge rules.
# They share only presentation sizing and the tabletop material here.
const PLACEMENT_FAMILIES := {
	"luxury.gramophone": "gramophone",
	"luxury.camera": "camera",
	"fd.dragon": "dragon_bangle", "fd.phoenix": "phoenix_bangle",
	"asset.item_blue_bowl": "bowl", "placeholder.silver_hairpin": "hairpin",
	"goods.silver_ring": "silver_ring", "goods.silver_lock": "silver_lock", "goods.folding_fan": "folding_fan",
	"asset.weeping_mirror_ordinary": "mirror_ordinary", "asset.weeping_mirror_resentful": "mirror_resentful",
}
const FRONTS := {
	"gramophone": "res://assets/gramophone_desk/counter_painted.png",
	"camera": "res://assets/camera_desk/camera_counter_painted.png",
	"dragon_bangle": "res://assets/first_debt/dragon.png",
	"phoenix_bangle": "res://assets/first_debt/phoenix.png",
	"inkstone": "res://assets/item_art_v30/inkstone_front.png",
	"clay_teapot": "res://assets/item_art_v30/clay_teapot_front.png",
	"silk_panel": "res://assets/item_art_v30/silk_panel_front.png",
	"holder": "res://assets/item_art_v30/holder_front_v2.png",
	"mirror": "res://assets/art06/items/mirror_front.png",
	"fountain_pen": "res://assets/art09/items/fountain_pen_front.png",
	"pocket_watch": "res://assets/item_art_v30/pocket_watch_front_v2.png",
	"bowl": "res://assets/art04/items/bowl_front.png",
	"hairpin": "res://assets/art04/items/hairpin_front.png",
	"silver_ring": "res://assets/item_art_v30/silver_ring_front.png",
	"silver_lock": "res://assets/item_art_v30/silver_lock_front.png",
	"folding_fan": "res://assets/appraisal/fan-sound.png",
	"mirror_ordinary": "res://assets/item_studies/mirror_ordinary_front.png",
	"mirror_resentful": "res://assets/item_studies/mirror_resentful_front.png",
}
const SECOND_ROOT := "res://assets/item_studies_second/"
const STUDY_ROOT := "res://assets/item_studies/"

# Only replace shipped paths in their intended view. A custom front pointing
# at another illustration (even an old back SVG) still belongs to the author.
static func study_path(asset: String, view: String, path: String) -> String:
	if view == "front": return path
	var family: String = PLACEMENT_FAMILIES.get(asset, "")
	if family == "bowl":
		var old := {
			"res://assets/art02/items/bowl_back.svg": "bowl_back",
			"res://assets/art02/items/bowl_intact.svg": "bowl_intact",
			"res://assets/art02/items/bowl_repair.svg": "bowl_repair",
			"res://assets/sample/bowl_seam.svg": "bowl_seam",
			"res://assets/sample/bowl_foot.svg": "bowl_foot",
		}
		if old.has(path): return STUDY_ROOT + old[path] + ".png"
	if family == "folding_fan":
		if path == "res://assets/goods_v21/folding_fan_back.svg": return SECOND_ROOT + "folding_fan_back.png"
		if path == "res://assets/goods_v21/folding_fan_sound.svg": return FRONTS.folding_fan
	if family == "hairpin":
		if view == "back" and path in ["", "res://assets/opening/hairpin.svg"]: return STUDY_ROOT + "hairpin_back.png"
		if path == "res://assets/sample/hairpin_seam.svg": return STUDY_ROOT + "hairpin_seam.png"
	if family in ["silver_ring", "silver_lock"]:
		for suffix in ["back", "sound", "flaw", "condition_mended"]:
			if path == "res://assets/goods_v21/" + family + "_" + suffix + ".svg":
				return STUDY_ROOT + family + "_" + suffix + ".png"
	return path
const BACKS := {
	"inkstone": "res://assets/item_studies_second/inkstone_back.png",
	"clay_teapot": "res://assets/item_studies_second/clay_teapot_back.png",
	"silk_panel": "res://assets/item_studies_second/silk_panel_back.png",
	"holder": "res://assets/art07/items/holder_back.png",
	"mirror": "res://assets/art07/items/mirror_back.png",
	"fountain_pen": "res://assets/art09/items/fountain_pen_back.png",
	"pocket_watch": "res://assets/item_art_v30/pocket_watch_back_v2.png",
}
const DETAILS := {
	"holder": {"brass_core": ["holder_brass", "底部划痕"], "iron_core": ["holder_iron", "底部划痕"]},
	"mirror": {"blood": ["mirror_blood", "镜缘细看"], "inscription": ["mirror_inscription", "镜背刻痕"]},
}
# Full source rectangle, in the existing 1280x648 counter coordinates. Flat
# mirror/pen sources are projected onto the same tabletop. The redesigned
# watch already has painted perspective and must retain its original aspect.
const BOUNDS := {
	"camera": Rect2(.432, .643, .170, .200),
	# 64px source square at 1280x720; visible diameter ~56px, near a human wrist.
	"dragon_bangle": Rect2(.485, .649, .050, .0988),
	"phoenix_bangle": Rect2(.485, .649, .050, .0988),
	"inkstone": Rect2(.455, .666, .110, .145),
	"clay_teapot": Rect2(.452, .638, .115, .152),
	"silk_panel": Rect2(.395, .634, .235, .195),
	"holder": Rect2(.440, .616, .140, .1844),
	"mirror": Rect2(.390, .644, .240, .168),
	"mirror_ordinary": Rect2(.390, .644, .240, .168),
	"mirror_resentful": Rect2(.390, .644, .240, .168),
	"fountain_pen": Rect2(.474, .701, .072, .064),
	"pocket_watch": Rect2(.469, .697, .082, .108),
	"bowl": Rect2(.456, .663, .108, .1422),
	"hairpin": Rect2(.463, .693, .094, .1238),
	"silver_ring": Rect2(.493, .743, .034, .0448),
	"silver_lock": Rect2(.480, .716, .060, .079),
	"folding_fan": Rect2(.410, .650, .200, .160),
}

static func has_asset(asset: String) -> bool:
	return FAMILIES.has(asset)

static func front_path(asset: String) -> String:
	return FRONTS.get(FAMILIES.get(asset, PLACEMENT_FAMILIES.get(asset, "")), "")

static func upgrade_path(path: String) -> String:
	# Upgrade only known shipped skeletons, never artist-authored replacements.
	for family in ["silver_ring", "silver_lock", "folding_fan"]:
		if path == "res://assets/goods_v21/" + family + "_front.svg": return FRONTS[family]
	if not path.begins_with("res://assets/art02/items/"): return path
	var name := path.get_file().get_basename()
	if name in ["holder_front", "mirror_front"]:
		return FRONTS.holder if name == "holder_front" else FRONTS.mirror
	if name in ["holder_back", "mirror_back", "holder_brass", "holder_iron", "mirror_blood", "mirror_inscription"]:
		return "res://assets/art07/items/" + name + ".png"
	return path

static func images(visual: Dictionary, sources: Array) -> Array:
	var family: String = FAMILIES.get(visual.get("item_asset", ""), "")
	var details: Dictionary = DETAILS.get(family, {})
	var result: Array = []
	if not sources.is_empty():
		for source in sources:
			var row: Dictionary = source.duplicate(true)
			row.path = upgrade_path(row.path)
			if row.path.is_empty():
				if row.id == "front": row.path = FRONTS[family]
				elif row.id == "back": row.path = BACKS.get(family, "")
				elif family == "pocket_watch" and row.id in ["sound", "flawed"]:
					var clue_id := "sound" if row.id == "sound" else "flaw"
					if visual.get("clues", []).any(func(clue: Dictionary) -> bool: return clue.id == clue_id):
						row.path = SECOND_ROOT + "pocket_watch_" + row.id + "_macro.png"
				else:
					for clue in visual.get("clues", []):
						# Sources are already knowledge-filtered. Match the specific
						# page, not the first known clue (mirror can know both).
						var page: String = {"brass_core": "brass", "iron_core": "plated"}.get(clue.id, clue.id)
						if details.has(clue.id) and (row.id in [page, "detail_" + clue.id] or clue.id in row.get("requires_clues", [])):
							row.path = "res://assets/art07/items/" + details[clue.id][0] + ".png"
							break
			# No invented back view or blank image tab for assets with front only.
			if not row.path.is_empty(): result.append(row)
		return result
	result.append({"id": "front", "label": "正面", "path": FRONTS[family]})
	if BACKS.has(family): result.append({"id": "back", "label": "背面", "path": BACKS[family]})
	for clue in visual.get("clues", []):
		if details.has(clue.id):
			result.append({"id": "detail_" + clue.id, "label": details[clue.id][1], "path": "res://assets/art07/items/" + details[clue.id][0] + ".png"})
	return result

static func _family(texture: Texture2D) -> String:
	if texture == null: return ""
	for family in FRONTS:
		if texture.resource_path == FRONTS[family]: return family
	return ""

static func counter_bounds(texture: Texture2D) -> Rect2:
	return BOUNDS.get(_family(texture), Rect2())

static func projects_on_table(texture: Texture2D) -> bool:
	return _family(texture) in ["mirror", "mirror_ordinary", "mirror_resentful", "fountain_pen", "folding_fan"]

static func material(texture: Texture2D, on_counter := false) -> ShaderMaterial:
	if texture == null: return null
	var path := texture.resource_path
	if not (path in [FRONTS.bowl, FRONTS.hairpin, FRONTS.folding_fan, FRONTS.dragon_bangle, FRONTS.phoenix_bangle] or path.begins_with(STUDY_ROOT) or path.begins_with(SECOND_ROOT) or path.begins_with("res://assets/item_art_v30/") or path.begins_with("res://assets/art06/items/") or path.begins_with("res://assets/art07/items/") or path.begins_with("res://assets/art09/items/")): return null
	var result := ShaderMaterial.new()
	result.shader = preload("res://ui/art/counter_item.gdshader")
	result.set_shader_parameter("chroma_key", path.begins_with("res://assets/art09/") or path.get_file() in ["holder_back.png", "mirror_back.png", "bowl_back.png"])
	var watch := path.get_file().begins_with("pocket_watch")
	var new_watch := path in [FRONTS.pocket_watch, BACKS.pocket_watch]
	var old_holder := path.begins_with("res://assets/art07/items/holder_")
	result.set_shader_parameter("highlight_reduction", 0.06 if new_watch else (0.24 if watch or old_holder else 0.0))
	result.set_shader_parameter("saturation", 0.90 if new_watch else (0.68 if watch else (0.8 if old_holder else 1.0)))
	var bangle := path in [FRONTS.dragon_bangle, FRONTS.phoenix_bangle]
	if bangle:
		result.set_shader_parameter("saturation", 0.88)
		result.set_shader_parameter("highlight_reduction", 0.12)
	if on_counter:
		var family := _family(texture)
		result.set_shader_parameter("exposure", 0.92 if new_watch or family == "holder" else (0.76 if watch else 0.86))
		result.set_shader_parameter("contact_mode", 2 if family in ["holder", "clay_teapot", "bowl"] else 1)
		if family == "holder":
			result.set_shader_parameter("footprint", Vector4(.50, .952, .184, .040))
		elif family == "clay_teapot":
			result.set_shader_parameter("footprint", Vector4(.515, .889, .265, .053))
		elif family == "bowl":
			result.set_shader_parameter("footprint", Vector4(.50, .945, .18, .034))
	return result
