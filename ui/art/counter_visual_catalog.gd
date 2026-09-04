class_name CounterVisualCatalog
extends RefCounted

const ROOT := "res://assets/art02/"
const ITEMS := {
	"asset.item_blue_bowl": "bowl", "asset.item_brass_holder": "holder", "asset.weeping_mirror": "mirror",
}
const PORTRAITS := {
	"asset.customer_citizen": "citizen", "asset.customer_hawker": "hawker",
	"placeholder.scholar": "scholar", "placeholder.house_agent": "agent",
}
const DETAILS := {
	"bowl": {"intact": ["bowl_intact", "侧光细节"], "repair": ["bowl_repair", "侧光细节"]},
	"holder": {"brass_core": ["holder_brass", "底部划痕"], "iron_core": ["holder_iron", "底部划痕"]},
	"mirror": {"blood": ["mirror_blood", "镜缘细看"], "inscription": ["mirror_inscription", "镜背刻痕"]},
}

static func portrait(asset: String) -> Texture2D:
	if not PORTRAITS.has(asset): return null
	return load(ROOT + "customers/" + PORTRAITS[asset] + ".svg") as Texture2D

static func front(asset: String, source_images: Array = []) -> Texture2D:
	for row in source_images:
		if row.id == "front" and not row.path.is_empty(): return load(row.path) as Texture2D
	if not ITEMS.has(asset): return null
	return load(ROOT + "items/" + ITEMS[asset] + "_front.svg") as Texture2D

static func images(visual: Dictionary, source_images: Array = []) -> Array:
	var result: Array = []
	var family: String = ITEMS.get(visual.get("item_asset", ""), "")
	# Scenario rows are already knowledge-filtered by the counter service and
	# own the view IDs. Existing art can fill an empty path, never add a second
	# detail view beside the artist's configured replacement.
	if not source_images.is_empty():
		for source in source_images:
			var row: Dictionary = source.duplicate(true)
			if row.path.is_empty() and not family.is_empty():
				if row.id in ["front", "back"]:
					row.path = ROOT + "items/" + family + "_" + row.id + ".svg"
				else:
					for clue in visual.get("clues", []):
						if DETAILS[family].has(clue.id):
							row.path = ROOT + "items/" + DETAILS[family][clue.id][0] + ".svg"
			result.append(row)
		return result
	if not family.is_empty():
		for side in ["front", "back"]:
			result.append({"id": side, "label": "正面" if side == "front" else "背面", "path": ROOT + "items/" + family + "_" + side + ".svg"})
		# Only already-revealed clues select detail assets. Front/back are identical
		# across hidden variants, so browsing free views cannot reveal a defect early.
		for clue in visual.get("clues", []):
			if DETAILS[family].has(clue.id):
				var spec: Array = DETAILS[family][clue.id]
				result.append({"id": "detail_" + clue.id, "label": spec[1], "path": ROOT + "items/" + spec[0] + ".svg"})
	return result
