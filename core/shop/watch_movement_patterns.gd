class_name WatchMovementPatterns
extends RefCounted

const KINDS := ["standard","lettering","gears"]

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("watch_movement_patterns",0) == 1

static func attach(state: RunState, item: ItemInstance) -> void:
	var run := state.ghost_catalog.get_definition("runs",state.run_definition_id) as RunDefinition
	if not enabled(run) or item.selected_variant_id != "flawed": return
	item.goods.watch_value["pattern"] = KINDS[VarietyService.rng(state.run_seed,item.instance_id+"/watch36/movement").randi_range(0,2)]

static func kind(item: ItemInstance) -> String:
	if item.selected_variant_id != "flawed": return "standard"
	return item.goods.get("watch_value",{}).get("pattern","standard")

static func points(item: ItemInstance) -> Array:
	match kind(item):
		"lettering": return [Vector2(.60,.43),Vector2(.705,.59)]
		"gears": return [Vector2(.48,.33),Vector2(.595,.33)]
	return []

static func lines(item: ItemInstance) -> Array:
	match kind(item):
		"lettering": return ["夹板刻着 PATEK PHILIPPEE，下行是 GENEVE。","机芯外缘贴着座圈，固定处未见另加转接件。"]
		"gears": return ["上方大齿轮占去夹板较大一片，轮缘离邻近部件很近。","旁边小齿轮明显偏小，与大齿轮的直径比例和图录不同。"]
	return []
