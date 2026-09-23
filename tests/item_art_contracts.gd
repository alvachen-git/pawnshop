extends SceneTree
var count := 0
var failures := 0
func _initialize() -> void:
	for asset in CounterItemArt.FAMILIES:
		var texture := CounterVisualCatalog.front(asset)
		check(texture != null, "front exists " + asset)
		var visual := {"item_asset": asset, "clues": []}
		var free := CounterVisualCatalog.images(visual)
		var originals := free.duplicate(true)
		check(free[0].path == texture.resource_path, "front shared across consumers")
		for clue in ["form", "sound", "flaw", "condition_chipped", "condition_replaced_lid", "condition_faded"]:
			visual.clues = [{"id": clue}]
			check(CounterVisualCatalog.images(visual) == originals, "no unrevealed/invented detail " + clue)
		var custom := [{"id": "front", "label": "正面", "path": "res://assets/art02/items/bowl_front.svg"}]
		check(CounterVisualCatalog.front(asset, custom).resource_path == custom[0].path, "explicit custom front wins")
		check(CounterVisualCatalog.images(visual, custom) == custom, "explicit custom pages win")
		check(CounterItemArt.counter_bounds(load(custom[0].path)) == Rect2(), "custom art does not inherit projected bounds")
		for row in free:
			check(ResourceLoader.exists(row.path), "all pages exist")
			check(CounterVisualCatalog.study_material(load(row.path)) != null, "material for all PNG views")
	var mirror := {"item_asset": "asset.weeping_mirror", "clues": [{"id":"blood"}, {"id":"inscription"}]}
	var m := CounterVisualCatalog.images(mirror)
	check(m.size() == 4 and m[2].path.ends_with("mirror_blood.png") and m[3].path.ends_with("mirror_inscription.png"), "two mirror clues select different details")
	var holder := {"item_asset": "asset.item_brass_holder", "clues": [{"id":"iron_core"}]}
	var source := [{"id":"plated", "label":"检查细节", "path":""}]
	check(CounterVisualCatalog.images(holder,source)[0].path.ends_with("holder_iron.png"), "already-filtered scenario detail keeps identity")
	holder.clues = []
	check(CounterVisualCatalog.images(holder,source).is_empty(), "no iron detail before actual clue")
	check(CounterVisualCatalog.study_material(null) == null, "clears material when empty")
	check(CounterVisualCatalog.study_material(load("res://assets/art02/items/bowl_front.svg")) == null, "unrelated alpha art unaffected")
	var hairpin := {"item_asset": "placeholder.silver_hairpin", "clues": []}
	var pages := [{"id": "front", "label": "正面", "path": ""}, {"id": "back", "label": "背面", "path": ""}]
	check(CounterVisualCatalog.images(hairpin, pages).size() == 1, "hairpin does not offer an empty back view")
	pages[1].path = "res://assets/art02/items/bowl_back.svg"
	check(CounterVisualCatalog.images(hairpin, pages).size() == 2, "explicit custom back remains available")
	# Texture rectangles include different transparent margins; visual scale is
	# reviewed in real-window screenshots, not inferred from rectangle widths.
	for ending in ["ordinary", "resentful"]:
		check(CounterVisualCatalog.front("asset.weeping_mirror_" + ending).resource_path.ends_with("mirror_" + ending + "_front.svg"), "mirror ending retains its distinct art " + ending)
	for jewelry in ["silver_ring", "silver_lock"]:
		var asset: String = "goods." + jewelry
		var root_path: String = "res://assets/goods_v21/" + jewelry
		var old_pages := [{"id": "front", "label": "正面", "path": root_path + "_front.svg"}, {"id": "back", "label": "背面", "path": root_path + "_back.svg"}]
		var visual := {"item_asset": asset, "clues": []}
		var mapped := CounterVisualCatalog.images(visual, old_pages)
		check(mapped[0].path == CounterItemArt.front_path(asset), "jewelry shipped front upgrades without save migration")
		check(mapped[1] == old_pages[1], "jewelry existing back preserved")
		check(CounterVisualCatalog.front(asset, old_pages).resource_path == mapped[0].path, "jewelry front shared by all consumers")
		var detail := {"id": "flaw", "label": "细节", "path": root_path + "_flaw.svg", "requires_clues": ["flaw"]}
		check(not mapped.any(func(row: Dictionary) -> bool: return row.id == "flaw"), "jewelry does not invent an unearned detail")
		old_pages.append(detail)
		check(CounterVisualCatalog.images(visual, old_pages)[2] == detail, "already-filtered jewelry evidence preserved")
		old_pages[0].path = root_path + "_back.svg"
		check(CounterVisualCatalog.front(asset, old_pages).resource_path == old_pages[0].path, "jewelry explicit custom front wins")
	print("ITEM ART CONTRACTS: %d assertions, %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error(label)
