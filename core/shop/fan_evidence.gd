class_name FanEvidence
extends RefCounted

# Coordinates belong to this authored illustration set, independent of window
# size, zoom or desk placement. Journal entries store thousandths as integers.
const NOTES := {"same": "相合", "different": "有异", "unsure": "看不准"}
const EXPLANATIONS := {"same": "符合图录特征", "different": "发现具体差异", "unsure": "现有观察不足"}
const TITLES := {"brush": "笔锋", "inscription": "题款与旧折"}
const REFERENCE := {"brush": Rect2(0.54, 0.17, 0.38, 0.32), "inscription": Rect2(0.54, 0.51, 0.38, 0.33)}
const OBJECT := {"brush": Rect2(0.17, 0.16, 0.39, 0.32), "inscription": Rect2(0.66, 0.20, 0.28, 0.43)}

static func region(side: String, point: Vector2) -> String:
	var regions: Dictionary = REFERENCE if side == "reference" else OBJECT
	for key in regions:
		if regions[key].has_point(point): return key
	return ""

static func pack(point: Vector2) -> Array:
	return [roundi(point.x * 1000), roundi(point.y * 1000)]

static func unpack(point: Array) -> Vector2:
	return Vector2(point[0], point[1]) / 1000.0

static func payload(kind: String, reference: Vector2, object: Vector2, note: String) -> String:
	return JSON.stringify({"kind": kind, "reference": pack(reference), "object": pack(object), "note": note})

static func parse(detail: String) -> Dictionary:
	if detail.length() > 300: return {}
	var json := JSON.new()
	if json.parse(detail) != OK: return {}
	var raw: Variant = json.data
	if not raw is Dictionary or raw.size() != 4: return {}
	if not raw.get("kind") is String or not TITLES.has(raw.kind): return {}
	if not raw.get("note") is String or not NOTES.has(raw.note): return {}
	for side in ["reference", "object"]:
		var point: Variant = raw.get(side)
		if not point is Array or point.size() != 2: return {}
		for coordinate in point:
			if not (coordinate is int or coordinate is float): return {}
			if not is_finite(float(coordinate)) or coordinate < 0 or coordinate > 1000 or coordinate != int(coordinate): return {}
		if region(side, unpack(point)) != raw.kind: return {}
		raw[side] = [int(point[0]), int(point[1])]
	return raw
