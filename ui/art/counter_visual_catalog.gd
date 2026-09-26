class_name CounterVisualCatalog
extends RefCounted

const SUN_PORTRAIT := "res://assets/social_v27/sun_dayuan_visit_halfbody.png"
const ROOT := "res://assets/art02/"
const NEIGHBOR_PORTRAIT := "res://assets/art04/customers/neighbor_v2.png"
const ORDINARY_ROOT := "res://assets/art04/customers/ordinary/"
const WEALTHY_ROOT := "res://assets/art04/customers/wealthy/"
const WEALTHY_PAINTED_ROOT := WEALTHY_ROOT + "painted/"
const WEALTHY_CUSTOMERS := {
	"customer_wealthy_silk":"silk", "customer_wealthy_factory":"factory",
	"customer_wealthy_opera":"opera", "customer_wealthy_antique":"antique", "customer_wealthy_comprador":"comprador",
}
const MIRROR_HUSBAND_PORTRAIT := preload("res://assets/art04/customers/special/mirror_husband.png")
const SPECIAL_ROOT := "res://assets/art04/customers/special/"
const FAMILIAR_PORTRAITS := {
	"familiar/bookkeeper": "xu_wenheng", "familiar/seamstress": "jiang_suyun",
}
const SPECIAL_CUSTOMERS := {
	"mirror_husband": "mirror_husband", "mirror_medicine": "mirror_medicine",
	"ghost_closed_bundle": "ghost_closed_bundle", "ghost_swap_guest": "ghost_swap_guest",
}
# Full source height, counter occlusion in source UV, horizontal center.
# Align each source independently; the husband's canonical reference is square.
const SPECIAL_PLACEMENT := {
	"zhou_huaian_v47": Vector3(0.680, 0.780, 0.500),
	"wet_bundle_v45": Vector3(0.640, 0.800, 0.500),
	"xu_wenheng": Vector3(0.660, 0.760, 0.500),
	"jiang_suyun": Vector3(0.650, 0.720, 0.500),
	"mirror_husband": Vector3(0.510, 1.000, 0.493),
	"mirror_medicine": Vector3(0.680, 0.720, 0.500),
	"ghost_closed_bundle": Vector3(0.630, 0.730, 0.500),
	"ghost_swap_guest": Vector3(0.740, 0.680, 0.500),
}
# Identity, rather than the shared legacy asset ID, selects ordinary templates.
const ORDINARY_CUSTOMERS := {
	"customer_citizen": "citizen", "customer_hawker": "hawker",
	"customer_scholar": "scholar", "customer_house_agent": "agent",
	"customer_seamstress": "seamstress", "customer_watchmaker": "watchmaker",
	"customer_teahouse": "teahouse", "customer_bookkeeper": "bookkeeper",
}
# Square-image height in CounterView coordinates, source hem, horizontal center.
const ORDINARY_PLACEMENT := {
	"citizen": Vector3(0.500, 1.000, 0.500),
	"hawker": Vector3(0.510, 1.000, 0.493),
	"scholar": Vector3(0.495, 1.000, 0.500),
	"agent": Vector3(0.500, 1.000, 0.500),
	"seamstress": Vector3(0.485, 1.000, 0.500),
	"watchmaker": Vector3(0.515, 0.993, 0.500),
	"teahouse": Vector3(0.505, 0.982, 0.495),
	"bookkeeper": Vector3(0.500, 1.000, 0.500),
}
const LU_PORTRAIT := "res://assets/first_debt/lu_zhangyan_stocky.png"
const LU_ELDERLY_PORTRAIT := "res://assets/first_debt/lu_zhangyan_elderly_v43.png"
const CHEN_PORTRAIT := "res://assets/first_debt/chen_xiaoman_petite.png"
const ITEMS := {
	"asset.weeping_mirror_ordinary": "mirror_ordinary", "asset.weeping_mirror_resentful": "mirror_resentful",
	"asset.item_blue_bowl": "bowl", "asset.item_brass_holder": "holder", "asset.weeping_mirror": "mirror",
}
const PORTRAITS := {
	"asset.customer_seamstress": "seamstress", "asset.customer_watchmaker": "watchmaker",
	"asset.customer_teahouse": "teahouse", "asset.customer_bookkeeper": "bookkeeper",
	"asset.customer_citizen": "citizen", "asset.customer_hawker": "hawker",
	"placeholder.scholar": "scholar", "placeholder.house_agent": "agent",
}
const DETAILS := {
	"bowl": {"intact": ["bowl_intact", "侧光细节"], "repair": ["bowl_repair", "侧光细节"]},
	"holder": {"brass_core": ["holder_brass", "底部划痕"], "iron_core": ["holder_iron", "底部划痕"]},
	"mirror": {"blood": ["mirror_blood", "镜缘细看"], "inscription": ["mirror_inscription", "镜背刻痕"]},
}

static func portrait(asset: String, customer_id := "", person_id := "") -> Texture2D:
	if asset == "fd.lu_elderly": return load(LU_ELDERLY_PORTRAIT) as Texture2D
	if asset == "special.wet_bundle_v45": return load(SPECIAL_ROOT + "wet_bundle_v45.png") as Texture2D
	if WEALTHY_CUSTOMERS.has(customer_id):
		var painted_path: String = WEALTHY_PAINTED_ROOT + WEALTHY_CUSTOMERS[customer_id] + ".png"
		if ResourceLoader.exists(painted_path): return load(painted_path) as Texture2D
		return load(WEALTHY_ROOT + WEALTHY_CUSTOMERS[customer_id] + ".png") as Texture2D
	if customer_id == "sun_dayuan" or asset == "social.sun_dayuan_visit": return load(SUN_PORTRAIT) as Texture2D
	if customer_id == "fd_aqi": return AqiArt.counter_texture("aqi")
	if customer_id == "fd_chen": return load(CHEN_PORTRAIT) as Texture2D
	if customer_id == "fd_lu": return load(LU_PORTRAIT) as Texture2D
	if customer_id == "fd_seller": customer_id = "customer_house_agent"
	# The chapter's hawker and every later appointment are the same man.
	# Keep the approved cap, face and clothes used by the reunion expression set.
	if customer_id == "mirror_husband" or person_id == InvestigationService.PERSON:
		return MIRROR_HUSBAND_PORTRAIT
	if asset == "medicine.huaian": return load(SPECIAL_ROOT + "zhou_huaian_v47.png") as Texture2D
	if asset == "social.sun_dayuan_visit":
		return load(SUN_PORTRAIT) as Texture2D
	if customer_id == "intro_neighbor" and ResourceLoader.exists(NEIGHBOR_PORTRAIT):
		return load(NEIGHBOR_PORTRAIT) as Texture2D
	var identity: String = FAMILIAR_PORTRAITS.get(person_id, SPECIAL_CUSTOMERS.get(customer_id, ""))
	if not identity.is_empty():
		var special_path := SPECIAL_ROOT + identity + ".png"
		if ResourceLoader.exists(special_path): return load(special_path) as Texture2D
	if ORDINARY_CUSTOMERS.has(customer_id) and not person_id.begins_with("familiar/"):
		var ordinary_path: String = ORDINARY_ROOT + ORDINARY_CUSTOMERS[customer_id] + ".png"
		if ResourceLoader.exists(ordinary_path): return load(ordinary_path) as Texture2D
	if asset == "asset.customer_citizen" and ResourceLoader.exists("res://assets/art04/customers/citizen.png"):
		return load("res://assets/art04/customers/citizen.png") as Texture2D
	if not PORTRAITS.has(asset): return null
	return load(ROOT + "customers/" + PORTRAITS[asset] + ".svg") as Texture2D

static func portrait_material(texture: Texture2D) -> ShaderMaterial:
	if texture == null or (not texture.resource_path.begins_with("res://assets/art04/") and texture.resource_path != CHEN_PORTRAIT): return null
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/art/counter_cutout.gdshader")
	material.set_shader_parameter("source_bottom", 1.0)
	material.set_shader_parameter("chroma_key", is_wealthy_portrait(texture) or is_special_portrait(texture) or is_ordinary_portrait(texture) or texture.resource_path.get_file() in ["citizen.png", "neighbor.png", "neighbor_v2.png"])
	material.set_shader_parameter("clean_chroma_edges", is_wealthy_portrait(texture) or is_special_portrait(texture) or is_ordinary_portrait(texture) or texture.resource_path == NEIGHBOR_PORTRAIT)
	# Repainted wealthy sprites have native alpha; chroma cleanup would alter cloth colors.
	if texture.resource_path.begins_with(WEALTHY_PAINTED_ROOT) or texture.resource_path in [SPECIAL_ROOT + "wet_bundle_v45.png", SPECIAL_ROOT + "zhou_huaian_v47.png"]:
		material.set_shader_parameter("chroma_key", false)
		material.set_shader_parameter("clean_chroma_edges", false)
	return material

static func is_ordinary_portrait(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with(ORDINARY_ROOT)

static func is_wealthy_portrait(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with(WEALTHY_ROOT)

static func wealthy_bounds() -> Vector4:
	var hem := 445.0 / 941.0 / 0.9
	return Vector4(0.3175,hem-0.50,0.6825,hem)

static func sun_bounds() -> Vector4:
	# The source already fills the square with a broad, head-to-waist figure.
	# Use Lu's display height; do not enlarge the head or bury the waist in the mat.
	var hem := 445.0 / 941.0 / 0.9
	return Vector4(0.3175, hem - 0.46, 0.6825, hem)

static func is_special_portrait(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with(SPECIAL_ROOT)

static func special_placement(texture: Texture2D) -> Vector3:
	return SPECIAL_PLACEMENT[texture.resource_path.get_file().get_basename()]

static func special_bounds(texture: Texture2D) -> Vector4:
	var placement := special_placement(texture)
	var top := 445.0 / 941.0 / 0.9 - placement.x * placement.y
	return Vector4(placement.z - 0.1825, top, placement.z + 0.1825, top + placement.x)

static func ordinary_bounds(texture: Texture2D) -> Vector4:
	var placement: Vector3 = ORDINARY_PLACEMENT[texture.resource_path.get_file().get_basename()]
	# The painting's back counter edge is at y=445 in its 941px-high full frame.
	# CounterView occupies 90% of that frame; keep the source hem at this edge.
	var top := 445.0 / 941.0 / 0.9 - placement.x * placement.y
	return Vector4(placement.z - 0.1825, top, placement.z + 0.1825, top + placement.x)

static func _painted_front(asset: String) -> String:
	if asset.begins_with("fd."): return "res://assets/first_debt/" + asset.trim_prefix("fd.") + ".png"
	if asset == "social.cotton_coat": return "res://assets/social_v27/cotton_coat_folded.png"
	var item_path := CounterItemArt.front_path(asset)
	if not item_path.is_empty(): return item_path
	if asset.begins_with("goods."):
		var goods_path := "res://assets/goods_v21/" + asset.trim_prefix("goods.") + "_front.svg"
		return goods_path if ResourceLoader.exists(goods_path) else ""
	var paths := {"asset.item_blue_bowl": "bowl_front", "placeholder.silver_hairpin": "hairpin_front"}
	if not paths.has(asset): return ""
	var path := "res://assets/art04/items/" + String(paths[asset]) + ".png"
	return path if ResourceLoader.exists(path) else ""

static func front(asset: String, source_images: Array = []) -> Texture2D:
	if asset == "luxury.gramophone": return GramophoneArt.hero()
	if asset == "luxury.camera": return load(CounterItemArt.front_path(asset)) as Texture2D
	if asset.begins_with("luxury."):
		var path := "res://assets/wealthy/" + asset.trim_prefix("luxury.") + ".svg"
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	for row in source_images:
		if row.id == "front" and not row.path.is_empty():
			return load(_front_path(asset, row.path)) as Texture2D
	var painted := _painted_front(asset)
	if not painted.is_empty(): return load(painted) as Texture2D
	if not ITEMS.has(asset): return null
	return load(ROOT + "items/" + ITEMS[asset] + "_front.svg") as Texture2D

static func _front_path(asset: String, configured: String) -> String:
	var upgraded := CounterItemArt.upgrade_path(configured)
	if upgraded != configured: return upgraded
	# Upgrade only the shipped opening placeholder. Artist-authored paths still win.
	var painted := _painted_front(asset)
	if configured == "res://assets/opening/hairpin.svg" and asset == "placeholder.silver_hairpin" and not painted.is_empty(): return painted
	if asset in ["asset.weeping_mirror_ordinary", "asset.weeping_mirror_resentful"] and configured == ROOT + "items/" + ITEMS[asset] + "_front.svg": return painted
	return configured

static func images(visual: Dictionary, source_images: Array = []) -> Array:
	if visual.get("item_asset", "") == "luxury.gramophone":
		return [{"id":"front", "label":"留声机", "path":CounterItemArt.front_path("luxury.gramophone")}]
	if visual.get("item_asset", "") == "luxury.camera":
		return [{"id":"front", "label":"相机", "path":CounterItemArt.front_path("luxury.camera")}]
	if CounterItemArt.has_asset(visual.get("item_asset", "")):
		return CounterItemArt.images(visual, source_images)
	var result: Array = []
	if source_images.is_empty() and visual.get("item_asset", "") in ["asset.weeping_mirror_ordinary", "asset.weeping_mirror_resentful"]:
		return [{"id": "front", "label": "正面", "path": _painted_front(visual.item_asset)}]
	if str(visual.get("item_asset", "")).begins_with("fd."):
		result.append({"id": "front", "label": "正面", "path": _painted_front(visual.item_asset)})
		if visual.get("clues", []).any(func(c: Dictionary) -> bool: return c.id in ["mark", "repair"]):
			result.append({"id": "mark_repair", "label": "工记与旧修补", "path": "res://assets/first_debt/mark_repair.png"})
		return result
	if visual.get("item_asset", "") == "social.cotton_coat": return [{"id":"front", "label":"棉袄", "path":"res://assets/social_v27/cotton_coat_folded.png"}]
	var family: String = ITEMS.get(visual.get("item_asset", ""), "")
	# Scenario rows are already knowledge-filtered by the counter service and
	# own the view IDs. Existing art can fill an empty path, never add a second
	# detail view beside the artist's configured replacement.
	if not source_images.is_empty():
		for source in source_images:
			var row: Dictionary = source.duplicate(true)
			if row.id == "front" and not row.path.is_empty(): row.path = _front_path(visual.get("item_asset", ""), row.path)
			if row.path.is_empty() and not family.is_empty():
				if row.id in ["front", "back"]:
					row.path = _painted_front(visual.get("item_asset", "")) if row.id == "front" else ""
					if row.path.is_empty(): row.path = ROOT + "items/" + family + "_" + row.id + ".svg"
				else:
					for clue in visual.get("clues", []):
						if DETAILS.get(family, {}).has(clue.id):
							row.path = ROOT + "items/" + DETAILS[family][clue.id][0] + ".svg"
			if row.path.is_empty() and row.id == "front": row.path = _painted_front(visual.get("item_asset", ""))
			row.path = CounterItemArt.study_path(visual.get("item_asset", ""), row.id, row.path)
			# Unknown custom empty pages are not image tabs.
			if visual.get("item_asset", "") == "placeholder.silver_hairpin" and row.path.is_empty(): continue
			result.append(row)
		return result
	if not family.is_empty():
		for side in ["front", "back"]:
			result.append({"id": side, "label": "正面" if side == "front" else "背面", "path": _painted_front(visual.get("item_asset", "")) if side == "front" and not _painted_front(visual.get("item_asset", "")).is_empty() else ROOT + "items/" + family + "_" + side + ".svg"})
		# Only already-revealed clues select detail assets. Front/back are identical
		# across hidden variants, so browsing free views cannot reveal a defect early.
		for clue in visual.get("clues", []):
			if DETAILS.get(family, {}).has(clue.id):
				var spec: Array = DETAILS[family][clue.id]
				result.append({"id": "detail_" + clue.id, "label": spec[1], "path": ROOT + "items/" + spec[0] + ".svg"})
	for row in result:
		row.path = CounterItemArt.study_path(visual.get("item_asset", ""), row.id, row.path)
	return result

static func study_material(texture: Texture2D) -> ShaderMaterial:
	return CounterItemArt.material(texture)
